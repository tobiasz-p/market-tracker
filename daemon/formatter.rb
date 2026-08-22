# frozen_string_literal: true

require_relative "constants"

# All presentation and string formatting logic for the market tracker widget.
#
# Pre-computes prices, percentage and currency deltas, sparkline labels,
# and multi-line tooltips so QML can render strings directly without UI logic.
module Formatter
  CURRENCY_SYMBOLS = {
    "USD" => "$", "EUR" => "€", "GBP" => "£",
    "PLN" => "zł", "JPY" => "¥", "CHF" => "Fr"
  }.freeze

  PRICE_DECIMALS_THRESHOLD = 10.0
  MASKED_PRICE = "••••"
  MASKED_DELTA = "••••"
  FALLBACK_DASH = "—"
  NO_DATA_TOOLTIP = "Market Tracker — No data"

  module_function

  def currency_symbol(currency)
    return "" if currency.nil? || currency.empty?

    CURRENCY_SYMBOLS.fetch(currency.upcase, "#{currency} ")
  end

  def format_price(price, currency: Constants::DEFAULT_CURRENCY, stealth: false)
    return FALLBACK_DASH if price.nil?

    symbol = currency_symbol(currency)
    return "#{symbol}#{MASKED_PRICE}" if stealth

    numeric_price = price.to_f
    decimals = numeric_price >= PRICE_DECIMALS_THRESHOLD ? "%.2f" : "%.4f"
    "#{symbol}#{format(decimals, numeric_price)}"
  end

  def format_change_pct(change_pct)
    return "" if change_pct.nil?

    percent_value = change_pct.to_f
    sign = percent_value >= 0 ? "+" : ""
    "#{sign}#{format("%.2f", percent_value)}%"
  end

  def format_change_amount(change, currency: Constants::DEFAULT_CURRENCY, stealth: false)
    return "" if change.nil?

    symbol = currency_symbol(currency)
    return "#{symbol}#{MASKED_DELTA}" if stealth

    numeric_change = change.to_f
    sign = numeric_change >= 0 ? "+" : "-"
    "#{sign}#{symbol}#{format("%.2f", numeric_change.abs)}"
  end

  # delta_format: "percent" | "amount" | "both"
  def format_delta(change, change_pct, currency: Constants::DEFAULT_CURRENCY,
                   delta_format: Constants::DELTA_PERCENT, stealth: false)
    case delta_format
    when Constants::DELTA_AMOUNT then format_change_amount(change, currency:, stealth:)
    when Constants::DELTA_BOTH
      amount = format_change_amount(change, currency:, stealth:)
      "#{amount} #{format_change_pct(change_pct)}"
    else
      format_change_pct(change_pct)
    end
  end

  # Pre-formatted bar label: "VOO $543.21 +0.26%"
  def bar_label(quote, show_price: true,
                delta_format: Constants::DELTA_PERCENT, stealth: false)
    return "" if quote.nil?

    parts = []
    parts << (quote[:symbol] || "")

    parts << format_price(quote[:price], currency: quote[:currency], stealth:) if show_price

    delta = format_delta(quote[:change], quote[:changePct],
                         currency: quote[:currency], delta_format:, stealth:)
    parts << delta unless delta.empty?

    parts.join(" ")
  end

  def format_volume(volume)
    return FALLBACK_DASH if volume.nil?

    numeric_volume = volume.to_i
    return "#{format("%.2f", numeric_volume / 1e9)}B" if numeric_volume >= 1e9
    return "#{format("%.2f", numeric_volume / 1e6)}M" if numeric_volume >= 1e6
    return "#{format("%.1f", numeric_volume / 1e3)}K" if numeric_volume >= 1e3

    numeric_volume.to_s
  end

  def format_market_cap(market_cap)
    return FALLBACK_DASH if market_cap.nil?

    numeric_cap = market_cap.to_f
    return "$#{format("%.2f", numeric_cap / 1e12)}T" if numeric_cap >= 1e12
    return "$#{format("%.2f", numeric_cap / 1e9)}B" if numeric_cap >= 1e9
    return "$#{format("%.2f", numeric_cap / 1e6)}M" if numeric_cap >= 1e6

    "$#{format("%.0f", numeric_cap)}"
  end

  # Tooltip — multi-line, pre-joined
  def tooltip(quote, stealth: false)
    return NO_DATA_TOOLTIP if quote.nil?

    lines = [
      quote[:name] || quote[:symbol] || "",
      build_tooltip_price_line(quote, stealth),
      (build_tooltip_range_line(quote, stealth) if quote[:dayHigh] && quote[:dayLow]),
      *build_tooltip_meta_lines(quote)
    ]

    lines.compact.reject(&:empty?).join("\n")
  end

  def build_tooltip_meta_lines(quote)
    lines = []
    lines << "Vol: #{format_volume(quote[:volume])}" if quote[:volume]
    lines << "Updated: #{Time.at(quote[:fetchedAt]).strftime("%-I:%M %p")}" if quote[:fetchedAt]
    lines
  end

  def build_tooltip_price_line(quote, stealth)
    price = format_price(quote[:price], currency: quote[:currency], stealth:)
    change_label = format_delta(quote[:change], quote[:changePct],
                                currency: quote[:currency], delta_format: Constants::DELTA_BOTH, stealth:)
    "#{price}#{"  #{change_label}" unless change_label.empty?}"
  end

  def build_tooltip_range_line(quote, stealth)
    high_price = format_price(quote[:dayHigh], currency: quote[:currency], stealth:)
    low_price = format_price(quote[:dayLow], currency: quote[:currency], stealth:)
    "H: #{high_price}  L: #{low_price}"
  end

  def consensus_bar_data(recommendation)
    return nil unless recommendation

    counts = extract_rec_counts(recommendation)
    total = counts.values.sum
    return nil if total.zero?

    counts.merge(total:, **calculate_rec_percentages(counts, total))
  end

  def calculate_rec_percentages(counts, total)
    %i[strongBuy buy hold sell strongSell].to_h do |key|
      [:"pct_#{key}", (counts[key].to_f / total * 100).round(1)]
    end
  end

  def extract_rec_counts(recommendation)
    {
      strongBuy: (recommendation[:strongBuy] || recommendation["strongBuy"]).to_i,
      buy: (recommendation[:buy] || recommendation["buy"]).to_i,
      hold: (recommendation[:hold] || recommendation["hold"]).to_i,
      sell: (recommendation[:sell] || recommendation["sell"]).to_i,
      strongSell: (recommendation[:strongSell] || recommendation["strongSell"]).to_i
    }
  end
end
