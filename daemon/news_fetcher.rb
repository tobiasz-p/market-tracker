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
  MAX_HEADLINE_LENGTH = 200
  MAX_SOURCE_LENGTH = 50
  MAX_SUMMARY_LENGTH = 500
  MAX_URL_LENGTH = 500

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
    Array(items).first(MAX_ARTICLES).filter_map do |item|
      next unless item.is_a?(Hash)

      build_headline_entry(item)
    end
  end

  def build_headline_entry(item)
    {
      headline: clean_string(item["headline"], MAX_HEADLINE_LENGTH, ellipsis: true),
      source: clean_string(item["source"], MAX_SOURCE_LENGTH, ellipsis: true),
      url: clean_string(item["url"], MAX_URL_LENGTH, ellipsis: false),
      summary: clean_string(item["summary"], MAX_SUMMARY_LENGTH, ellipsis: true),
      image: clean_string(item["image"], MAX_URL_LENGTH, ellipsis: false),
      datetime: item["datetime"]&.to_i
    }
  end
end
