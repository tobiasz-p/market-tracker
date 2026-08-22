#!/usr/bin/env ruby
# frozen_string_literal: true

# Market Tracker — Finnhub daemon entry point
#
# Reads configuration from environment variables (set by QML) and optional
# .env file for the API key. Starts the daemon fetch loop.

require_relative "daemon"
require_relative "app_logger"

def load_dotenv(path = File.join(__dir__, "..", ".env"))
  return unless File.readable?(path)

  File.foreach(path) do |line|
    line.strip!
    next if line.empty? || line.start_with?("#")

    k, v = line.split("=", 2)
    next unless k && v

    key = k.strip
    val = v.strip.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'")
    ENV[key] = val if ENV[key].to_s.empty?
  end
end

load_dotenv

config = Config.new
logger = AppLogger.new

logger.warn("No FINNHUB_API_KEY set") if config.api_key.empty?

Daemon.new(config:).run
