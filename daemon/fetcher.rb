#!/usr/bin/env ruby
# frozen_string_literal: true

# Market Tracker — Finnhub daemon entry point
#
# Reads configuration from environment variables (set by QML) and optional
# .env file for the API key. Starts the daemon fetch loop.

require_relative "daemon"
require_relative "app_logger"

config = Config.new
logger = AppLogger.new

logger.warn("No FINNHUB_API_KEY set") if config.api_key.empty?

Daemon.new(config:).run
