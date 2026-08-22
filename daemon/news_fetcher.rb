# frozen_string_literal: true

require "date"

require_relative "base_fetcher"
require_relative "constants"

# Fetches recent company news headlines from Finnhub.
class NewsFetcher < BaseFetcher
  TTL = 300
  MAX_ARTICLES = 10
  LOOKBACK_DAYS = 7
  DATE_FORMAT = "%Y-%m-%d"

  def fetch(symbol)
    today = Date.today
    from_date = (today - LOOKBACK_DAYS).strftime(DATE_FORMAT)
    to_date = today.strftime(DATE_FORMAT)
    path = "/company-news?symbol=#{encode(symbol)}&from=#{from_date}&to=#{to_date}"

    response = cached_get(path, ttl: TTL)
    if auth_restricted?(response)
      return { type: Constants::TYPE_NEWS, symbol:, headlines: [], fetchedAt: current_timestamp }
    end
    return error(symbol, client.error_message_for(response)) unless response&.code == HTTP_OK

    items = parse_json(response)
    {
      type: Constants::TYPE_NEWS,
      symbol:,
      headlines: extract_headlines(items),
      fetchedAt: current_timestamp
    }
  rescue *RESCUABLE_ERRORS => e
    error(symbol, e.message)
  end

  private

  def extract_headlines(items)
    Array(items).first(MAX_ARTICLES).map do |item|
      {
        headline: item["headline"],
        source: item["source"],
        url: item["url"],
        summary: item["summary"],
        image: item["image"],
        datetime: item["datetime"]
      }
    end
  end
end
