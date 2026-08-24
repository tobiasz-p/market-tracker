# frozen_string_literal: true

require_relative "constants"

# Feature configuration parsed on-demand and memoized from runtime environment variables.
#
# Settings arrive as environment variables from QML (read via Omarchy's
# setting() function). This class parses them upon request and memoizes the parsed
# values for subsequent accesses.
class Config
  # Ticker symbol and allocated portfolio share count entry.
  SymbolEntry = Struct.new(:ticker, :shares, keyword_init: true)

  ENV_API_KEY = "FINNHUB_API_KEY"
  ENV_SYMBOLS = "SYMBOLS"
  ENV_REFRESH_SECONDS = "REFRESH_SECONDS"
  ENV_ROTATE_SECONDS = "ROTATE_SECONDS"
  ENV_SHOW_PRICE = "SHOW_PRICE"
  ENV_DELTA_FORMAT = "DELTA_FORMAT"
  ENV_SHOW_COMPANY_PROFILE = "SHOW_COMPANY_PROFILE"
  ENV_SHOW_RECOMMENDATIONS = "SHOW_RECOMMENDATIONS"
  ENV_SHOW_NEWS = "SHOW_NEWS"
  ENV_STEALTH_MODE = "STEALTH_MODE"

  DEFAULT_REFRESH_SECONDS = "60"
  DEFAULT_ROTATE_SECONDS = "5"
  DEFAULT_FLAG_TRUE = "true"
  DEFAULT_FLAG_FALSE = "false"

  REFRESH_MIN = 15
  REFRESH_MAX = 300
  ROTATE_MIN = 2
  ROTATE_MAX = 300
  MAX_SYMBOLS = 30
  TICKER_PATTERN = /\A[A-Z0-9.\-_:^]{1,20}\z/
  MAX_SHARES = 1_000_000_000.0
  FALSY_VALUES = %w[false 0 no off].freeze

  def initialize(env = ENV)
    @env = env
  end

  def api_key
    @api_key ||= resolve_api_key(env)
  end

  def symbols
    @symbols ||= parse_symbols(env.fetch(ENV_SYMBOLS, ""))
  end

  def tickers
    @tickers ||= symbols.map(&:ticker).freeze
  end

  def refresh_seconds
    @refresh_seconds ||= clamp_integer(env.fetch(ENV_REFRESH_SECONDS, DEFAULT_REFRESH_SECONDS),
                                       REFRESH_MIN, REFRESH_MAX)
  end

  def rotate_seconds
    @rotate_seconds ||= clamp_integer(env.fetch(ENV_ROTATE_SECONDS, DEFAULT_ROTATE_SECONDS), 0, ROTATE_MAX)
  end

  def show_price
    return @show_price if defined?(@show_price)

    @show_price = truthy_flag?(env.fetch(ENV_SHOW_PRICE, DEFAULT_FLAG_TRUE))
  end

  def delta_format
    @delta_format ||= parse_delta_format(env.fetch(ENV_DELTA_FORMAT, Constants::DELTA_PERCENT))
  end

  def show_company_profile
    return @show_company_profile if defined?(@show_company_profile)

    @show_company_profile = truthy_flag?(env.fetch(ENV_SHOW_COMPANY_PROFILE, DEFAULT_FLAG_TRUE))
  end

  def show_recommendations
    return @show_recommendations if defined?(@show_recommendations)

    @show_recommendations = truthy_flag?(env.fetch(ENV_SHOW_RECOMMENDATIONS, DEFAULT_FLAG_TRUE))
  end

  def show_news
    return @show_news if defined?(@show_news)

    @show_news = truthy_flag?(env.fetch(ENV_SHOW_NEWS, DEFAULT_FLAG_TRUE))
  end

  def stealth_mode
    return @stealth_mode if defined?(@stealth_mode)

    @stealth_mode = truthy_flag?(env.fetch(ENV_STEALTH_MODE, DEFAULT_FLAG_FALSE))
  end

  def shares_for(ticker)
    @shares_by_ticker ||= symbols.to_h { |entry| [entry.ticker, entry.shares] }.freeze
    @shares_by_ticker[ticker]
  end

  def portfolio?
    return @portfolio if defined?(@portfolio)

    @portfolio = symbols.any? { |entry| entry.shares&.positive? }
  end

  def snapshot
    {
      symbols: serialize_symbols,
      rotateSeconds: rotate_seconds,
      portfolio: portfolio?,
      **display_snapshot,
      **features_snapshot
    }
  end

  private

  attr_reader :env

  def display_snapshot
    {
      showPrice: show_price,
      deltaFormat: delta_format,
      stealthMode: stealth_mode
    }
  end

  def features_snapshot
    {
      showCompanyProfile: show_company_profile,
      showRecommendations: show_recommendations,
      showNews: show_news
    }
  end

  def serialize_symbols
    symbols.map do |entry|
      entry.shares ? { ticker: entry.ticker, shares: entry.shares } : { ticker: entry.ticker }
    end
  end

  def resolve_api_key(environment)
    key = environment.fetch(ENV_API_KEY, "").strip
    return key unless key.empty?

    ""
  end

  def parse_symbols(raw)
    entries = []
    seen = {}
    raw.to_s.split(",").each do |item|
      entry = build_symbol_entry(item.strip)
      next unless entry && !seen[entry.ticker]

      seen[entry.ticker] = true
      entries << entry
      break if entries.length >= MAX_SYMBOLS
    end
    entries.freeze
  end

  def build_symbol_entry(item)
    return nil if item.empty?

    parts = item.split(":").map(&:strip)
    shares = nil
    if parts.length >= 2 && parts.last.match?(/\A-?\d+(\.\d+)?\z/)
      raw_shares = parts.pop.to_f
      shares = raw_shares if raw_shares.positive? && raw_shares <= MAX_SHARES
    end

    ticker = parts.join(":").upcase
    return nil unless ticker.match?(TICKER_PATTERN)

    SymbolEntry.new(ticker:, shares:)
  end

  def truthy_flag?(raw)
    !FALSY_VALUES.include?(raw.to_s.strip.downcase)
  end

  def parse_delta_format(raw)
    case raw.to_s.strip.downcase
    when Constants::DELTA_AMOUNT then Constants::DELTA_AMOUNT
    when Constants::DELTA_BOTH then Constants::DELTA_BOTH
    else Constants::DELTA_PERCENT
    end
  end

  def clamp_integer(raw, min, max)
    val = raw.to_i
    val = min if val < min
    val = max if val > max
    val
  end
end
