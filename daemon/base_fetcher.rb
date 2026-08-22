# frozen_string_literal: true

require "json"
require "uri"

require_relative "constants"
require_relative "finnhub_client"

# Abstract base class providing shared caching, URI encoding, and error encapsulation for domain fetchers.
class BaseFetcher
  NAME_CACHE_TTL = 86_400
  DEFAULT_HTTP_TTL = 60
  HTTP_OK = FinnhubClient::HTTP_OK
  AUTH_RESTRICTED_CODES = [FinnhubClient::HTTP_UNAUTHORIZED, FinnhubClient::HTTP_FORBIDDEN].freeze
  RESCUABLE_ERRORS = [*FinnhubClient::NETWORK_ERRORS, FinnhubClient::Error, JSON::ParserError].freeze

  def initialize(client:, cache: nil)
    @client = client
    @cache = cache
  end

  protected

  attr_reader :client, :cache

  def cached_get(path, ttl: DEFAULT_HTTP_TTL, force_refresh: false)
    if cache
      cache.get(path, ttl:, force_refresh:) { client.get(path) }
    else
      client.get(path)
    end
  end

  def encode(str)
    URI.encode_uri_component(str.to_s)
  end

  def error(symbol, message)
    { type: Constants::TYPE_ERROR, symbol:, message: }
  end

  def auth_restricted?(response)
    AUTH_RESTRICTED_CODES.include?(response&.code)
  end

  def parse_json(raw)
    return nil if raw.nil?

    body = raw.respond_to?(:body) ? raw.body : raw.to_s
    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end

  def fetch_name(symbol)
    return symbol if symbol.to_s.empty?

    response = cached_get("/search?q=#{encode(symbol)}", ttl: NAME_CACHE_TTL)
    return nil unless response&.code == HTTP_OK

    extract_description_from_search(parse_json(response), symbol)
  rescue *RESCUABLE_ERRORS
    nil
  end

  def extract_description_from_search(data, symbol)
    results = data&.fetch("result", []) || []
    match = results.find { |result| result["symbol"] == symbol } || results.first
    match&.fetch("description", nil)
  end

  def current_timestamp
    Time.now.to_i
  end
end
