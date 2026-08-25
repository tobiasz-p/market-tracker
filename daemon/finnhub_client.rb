# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

# Thin Finnhub REST client with HTTPS transport, redirect handling, and token authentication.
class FinnhubClient
  HOST = "finnhub.io"
  API_BASE = "/api/v1"
  USER_AGENT = "omarchy-market-tracker/1.0.2"
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 15
  MAX_REDIRECTS = 3
  MAX_BODY_BYTES = 1_048_576

  HTTP_OK = "200"
  HTTP_UNAUTHORIZED = "401"
  HTTP_FORBIDDEN = "403"
  HTTP_TOO_MANY_REQUESTS = "429"
  REDIRECT_CODE_PREFIX = /\A3/

  HINT_UNAUTHORIZED = " (invalid or unauthorized API key)"
  HINT_RATE_LIMITED = " (rate limited, will retry)"
  HINT_REDIRECT = " (unexpected redirect)"

  HEADER_USER_AGENT = "User-Agent"
  HEADER_ACCEPT = "Accept"
  HEADER_TOKEN = "X-Finnhub-Token"
  MIME_JSON = "application/json"
  HTTPS_SCHEME = "https"

  NETWORK_ERRORS = [
    SystemCallError, SocketError, OpenSSL::SSL::SSLError,
    Net::OpenTimeout, Net::ReadTimeout, Net::ProtocolError,
    Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
    Timeout::Error, IOError, EOFError
  ].freeze

  def initialize(api_key:)
    @api_key = api_key.to_s
  end

  def get(path)
    get_with_redirects(path)
  end

  def error_message_for(response)
    hint = case response.code
           when HTTP_UNAUTHORIZED, HTTP_FORBIDDEN then HINT_UNAUTHORIZED
           when HTTP_TOO_MANY_REQUESTS then HINT_RATE_LIMITED
           when REDIRECT_CODE_PREFIX then HINT_REDIRECT
           end
    "HTTP #{response.code}#{hint}"
  end

  Response = Data.define(:code, :body)

  # Generic transport error for API failures.
  class Error < StandardError; end

  # Raised when the client exceeds the maximum allowed redirects.
  class RedirectLoopError < Error; end

  # Raised when the response body exceeds the byte limit ceiling.
  class ResponseBodyTooLargeError < Error; end

  private

  attr_reader :api_key

  def get_with_redirects(path, redirects_left: MAX_REDIRECTS)
    full_path = path.start_with?(API_BASE) ? path : "#{API_BASE}#{path}"
    uri = URI("#{HTTPS_SCHEME}://#{HOST}#{full_path}")
    http = build_http_client(uri)
    request = build_http_request(uri)

    http.request(request) do |response|
      return handle_redirect(uri, response, redirects_left) if response.is_a?(Net::HTTPRedirection)

      stream_response_body(response)
    end
  end

  def stream_response_body(response)
    bytes_read = 0
    body = String.new(encoding: Encoding::UTF_8)
    if response.respond_to?(:read_body)
      response.read_body do |chunk|
        bytes_read += chunk.bytesize
        if bytes_read > MAX_BODY_BYTES
          raise ResponseBodyTooLargeError, "Response body exceeded limit of #{MAX_BODY_BYTES} bytes"
        end

        body << chunk
      end
    else
      body = response.body.to_s
    end

    Response.new(code: response.code.to_s, body:)
  end

  def build_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http
  end

  def build_http_request(uri)
    request = Net::HTTP::Get.new(uri)
    request[HEADER_USER_AGENT] = USER_AGENT
    request[HEADER_ACCEPT] = MIME_JSON
    request[HEADER_TOKEN] = api_key
    request
  end

  def handle_redirect(uri, response, redirects_left)
    target = response["location"] ? URI.join(uri, response["location"]) : nil
    unless target&.host == uri.host && target.scheme == HTTPS_SCHEME
      return Response.new(code: response.code.to_s, body: "")
    end
    raise RedirectLoopError if redirects_left.zero?

    query_string = target.query ? "?#{target.query}" : ""
    get_with_redirects("#{target.path}#{query_string}", redirects_left: redirects_left - 1)
  end
end
