# frozen_string_literal: true

require "json"

require_relative "config"
require_relative "cache"
require_relative "constants"
require_relative "formatter"
require_relative "finnhub_client"
require_relative "app_logger"
require_relative "quote_fetcher"
require_relative "profile_fetcher"
require_relative "news_fetcher"
require_relative "recommendation_fetcher"

# Orchestrates cyclic market polling, standard input command processing, and stdout event dispatching.
#
# Listens for interactive JSON commands on standard input ("refresh", "fetch_detail"),
# triggers background async requests, and emits pre-formatted JSON event lines on standard output for
# direct consumption by the QML user interface.
class Daemon
  TICKER_CYCLE_DELAY = 0.2
  DEFAULT_CACHE_TTL = 60
  NO_KEY_MESSAGE = "No API key set -- export FINNHUB_API_KEY or set apiKey setting"
  NO_SYMBOLS_MESSAGE = "No symbols configured"
  ALL_SYMBOLS_WILDCARD = "*"

  ACTION_REFRESH = "refresh"
  ACTION_FETCH_DETAIL = "fetch_detail"
  MAX_QUEUED_DETAILS = 4

  def initialize(config:)
    @config = config
    @force_refresh = false
    @cache = Cache.new(default_ttl: DEFAULT_CACHE_TTL)
    @logger = AppLogger.new
    @detail_queue = SizedQueue.new(MAX_QUEUED_DETAILS)

    init_synchronization
  end

  def run
    start_detail_worker
    start_stdin_thread
    emit(type: Constants::TYPE_READY, config: config.snapshot)
    run_fast_cycle

    loop do
      wait_for_next_cycle
      run_fast_cycle
    end
  end

  def run_fast_cycle
    return logger.warn(NO_SYMBOLS_MESSAGE) if config.tickers.empty?

    if config.api_key.empty?
      return emit(type: Constants::TYPE_ERROR, symbol: ALL_SYMBOLS_WILDCARD, message: NO_KEY_MESSAGE)
    end

    fetch_quotes_cycle
    @force_refresh = false
  end

  def fetch_detail(symbol)
    clean_symbol = symbol.to_s.upcase.strip
    return unless clean_symbol.match?(Config::TICKER_PATTERN)

    @detail_queue.push(clean_symbol, true)
  rescue ThreadError
    # Queue is full, discard excessive rapid requests
  end

  def handle_command(command)
    case command["action"]
    when ACTION_REFRESH then trigger_refresh
    when ACTION_FETCH_DETAIL then fetch_detail(command["symbol"])
    end
  end

  def perform_detail_fetch(symbol)
    emit_profile(symbol)
    emit_news(symbol)
    emit_recommendations(symbol)
  rescue StandardError => e
    logger.error("Detail fetch error for #{symbol}: #{e.message}")
  end

  private

  attr_reader :config, :cache, :logger

  def finnhub_client
    @finnhub_client ||= FinnhubClient.new(api_key: config.api_key)
  end

  def quote_fetcher
    @quote_fetcher ||= QuoteFetcher.new(client: finnhub_client, cache:)
  end

  def profile_fetcher
    @profile_fetcher ||= ProfileFetcher.new(client: finnhub_client, cache:)
  end

  def news_fetcher
    @news_fetcher ||= NewsFetcher.new(client: finnhub_client, cache:)
  end

  def recommendation_fetcher
    @recommendation_fetcher ||= RecommendationFetcher.new(client: finnhub_client, cache:)
  end

  def fetch_quotes_cycle
    config.tickers.each do |ticker|
      result = quote_fetcher.fetch(ticker, force_refresh: @force_refresh)
      emit(result[:type] == Constants::TYPE_ERROR ? result : enrich_quote(result))
      sleep(TICKER_CYCLE_DELAY) if config.tickers.length > 1
    end
  end

  def trigger_refresh
    @cycle_mutex.synchronize do
      @force_refresh = true
      cache.invalidate_all
      @cycle_cv.signal
    end
  end

  def emit_profile(symbol)
    result = profile_fetcher.fetch(symbol)
    return unless result

    if result[:type] == Constants::TYPE_ERROR
      emit(result)
    else
      emit(result.merge(marketCapFmt: Formatter.format_market_cap(result[:marketCap])))
    end
  end

  def emit_news(symbol)
    result = news_fetcher.fetch(symbol)
    emit(result) if result
  end

  def emit_recommendations(symbol)
    result = recommendation_fetcher.fetch(symbol)
    return unless result

    if result[:type] == Constants::TYPE_ERROR
      emit(result)
    else
      bar = Formatter.consensus_bar_data(result[:recommendations]&.first)
      label = result.dig(:consensus, :label)
      emit(result.merge(bar:, consensusLabel: label))
    end
  end

  def init_synchronization
    @emit_mutex = Mutex.new
    @cycle_mutex = Mutex.new
    @cycle_cv = ConditionVariable.new

    $stderr.sync = true
    $stdout.sync = true
  end

  def enrich_quote(raw)
    enriched_quote = raw.dup
    format_quote_labels(enriched_quote)
    format_quote_values(enriched_quote)
    enriched_quote[:positive] = enriched_quote[:change].to_f >= 0
    enriched_quote[:shares] = config.shares_for(enriched_quote[:symbol])
    calculate_portfolio_values(enriched_quote)
    enriched_quote
  end

  def format_quote_labels(quote)
    quote[:barLabel] = Formatter.bar_label(quote, show_price: config.show_price, delta_format: config.delta_format,
                                                  stealth: config.stealth_mode)
    quote[:tooltip] = Formatter.tooltip(quote, stealth: config.stealth_mode)
  end

  def format_quote_values(quote)
    quote[:priceFmt] = Formatter.format_price(quote[:price], currency: quote[:currency], stealth: config.stealth_mode)
    quote[:changeFmt] = Formatter.format_delta(quote[:change], quote[:changePct], currency: quote[:currency],
                                                                                  delta_format: config.delta_format,
                                                                                  stealth: config.stealth_mode)
    quote[:volumeFmt] = Formatter.format_volume(quote[:volume])
  end

  def calculate_portfolio_values(quote)
    shares = quote[:shares]
    quote[:portfolioValue] = shares ? (quote[:price].to_f * shares.to_f).round(4) : nil
    quote[:portfolioChange] = shares ? (quote[:change].to_f * shares.to_f).round(4) : nil
  end

  def wait_for_next_cycle
    @cycle_mutex.synchronize do
      return if @force_refresh

      @cycle_cv.wait(@cycle_mutex, config.refresh_seconds)
      @force_refresh = false
    end
  end

  def start_detail_worker
    thread = Thread.new do
      loop do
        symbol = @detail_queue.pop
        break if symbol == :stop

        perform_detail_fetch(symbol)
      end
    end
    thread.abort_on_exception = false
  end

  def start_stdin_thread
    thread = Thread.new do
      $stdin.each_line do |raw|
        line = raw.strip
        next if line.empty?

        process_stdin_line(line)
      end
    end
    thread.abort_on_exception = false
  end

  def process_stdin_line(line)
    handle_command(JSON.parse(line))
  rescue JSON::ParserError
    # Ignore non-JSON lines
  rescue StandardError => e
    logger.error("stdin error: #{e.message}")
  end

  def emit(payload)
    @emit_mutex.synchronize do
      $stdout.puts(payload.to_json)
      $stdout.flush
    end
  end
end
