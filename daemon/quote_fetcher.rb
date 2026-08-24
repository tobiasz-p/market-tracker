# frozen_string_literal: true

require_relative "base_fetcher"
require_relative "constants"

# Fetches real-time quotes and builds real-time rolling sparklines for symbols.
class QuoteFetcher < BaseFetcher
  SPARKLINE_POINTS = 60
  BUFFER_LIMIT = 240
  MAX_PRICE_BUFFERS = 50

  ERROR_NO_DATA = "No data for this symbol (check the ticker)"
  ERROR_INVALID_QUOTE = "Invalid quote data"

  def fetch(symbol, force_refresh: false)
    response = cached_get("/quote?symbol=#{encode(symbol)}", force_refresh:)
    return response if response.is_a?(Hash) && response[:type] == Constants::TYPE_ERROR

    quote_data = parse_json(response)
    return validate_quote(symbol, quote_data) unless valid_quote?(quote_data)

    build_payload(symbol, quote_data)
  rescue *RESCUABLE_ERRORS => e
    error(symbol, e.message)
  end

  private

  def valid_quote?(data)
    data.is_a?(Hash) && !(data["c"]&.to_f&.zero? && data["pc"].nil?)
  end

  def validate_quote(symbol, data)
    message = data&.fetch("error", ERROR_NO_DATA) || ERROR_INVALID_QUOTE
    error(symbol, message)
  end

  def build_payload(symbol, data)
    now = current_timestamp
    price = data["c"].to_f.round(4)

    {
      type: Constants::TYPE_QUOTE,
      symbol:,
      name: fetch_name(symbol),
      exchange: "",
      price:,
      sparkline: sparkline_for(symbol, data),
      fetchedAt: now,
      **extract_price_metrics(data)
    }
  end

  def extract_price_metrics(data)
    {
      prevClose: round_metric(data["pc"]),
      change: round_metric(data["d"]),
      changePct: round_metric(data["dp"], 3),
      dayHigh: round_metric(data["h"]),
      dayLow: round_metric(data["l"]),
      volume: nil,
      currency: Constants::DEFAULT_CURRENCY
    }
  end

  def round_metric(value, digits = 4)
    value&.to_f&.round(digits)
  end

  def sparkline_for(symbol, data)
    price_buffers.shift while price_buffers.size >= MAX_PRICE_BUFFERS && !price_buffers.key?(symbol)
    buffer = price_buffers[symbol]
    update_buffer(buffer, data)
    sample(buffer)
  end

  def update_buffer(buffer, data)
    if buffer.empty?
      buffer.concat(seed_checkpoints(data))
    else
      buffer << data["c"].to_f.round(4)
      buffer.shift while buffer.length > BUFFER_LIMIT
    end
  end

  def price_buffers
    @price_buffers ||= Hash.new { |h, k| h[k] = [] }
  end

  def seed_checkpoints(data)
    prev_close = round_metric(data["pc"])
    current = round_metric(data["c"])
    return [current].compact if prev_close.nil? || prev_close.zero? || current.nil? || current.zero?

    build_checkpoints(data, prev_close, current)
  end

  def build_checkpoints(data, prev_close, current)
    open_price = round_metric(data["o"])
    high_price = round_metric(data["h"])
    low_price = round_metric(data["l"])

    checkpoints = [prev_close]
    checkpoints << open_price if open_price&.positive?
    append_high_low_checkpoints(checkpoints, high_price, low_price, open_price || prev_close, current)
    checkpoints << current
    checkpoints.uniq
  end

  def append_high_low_checkpoints(checkpoints, high, low, baseline, current)
    return unless high&.positive? && low&.positive? && high > low

    if current >= baseline
      checkpoints << low << high
    else
      checkpoints << high << low
    end
  end

  def sample(values)
    return [] if values.length < 2

    return values.map { |value| value.round(4) } if values.length <= SPARKLINE_POINTS

    step = (values.length / SPARKLINE_POINTS.to_f).ceil
    values.each_slice(step).map { |slice| slice.last.round(4) }.last(SPARKLINE_POINTS)
  end
end
