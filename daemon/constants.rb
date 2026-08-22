# frozen_string_literal: true

# Shared domain constants, protocol message types, and delta formatting options.
module Constants
  # Protocol Message Types (shared across Daemon, Fetchers, and Formatter)
  TYPE_QUOTE = "quote"
  TYPE_PROFILE = "profile"
  TYPE_NEWS = "news"
  TYPE_RECOMMENDATIONS = "recommendations"
  TYPE_READY = "ready"
  TYPE_ERROR = "error"

  # Delta Format Options (shared across Config, Formatter, and Daemon)
  DELTA_PERCENT = "percent"
  DELTA_AMOUNT = "amount"
  DELTA_BOTH = "both"

  # Default fallback currency
  DEFAULT_CURRENCY = "USD"
end
