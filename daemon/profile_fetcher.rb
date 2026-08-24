# frozen_string_literal: true

require_relative "base_fetcher"
require_relative "constants"

# Fetches company/ETF profile data and financial metrics from Finnhub.
#
# Retrieves company metadata (name, logo, industry, market cap) from /stock/profile2
# and key financial performance indicators (52-week high/low, P/E ratio, trading volume)
# from /stock/metric.
class ProfileFetcher < BaseFetcher
  PROFILE_TTL = 3600
  METRIC_TTL = 1800
  DEFAULT_INDUSTRY = "ETF / Fund"
  METRIC_PARAM = "all"
  MAX_STRING_LENGTH = 100
  MAX_SHORT_STRING_LENGTH = 50

  def fetch(symbol)
    profile_data = fetch_profile_data(symbol)
    metric_data = fetch_metric_data(symbol)

    build_payload(symbol, profile_data, metric_data)
  rescue *RESCUABLE_ERRORS => e
    error(symbol, e.message)
  end

  private

  def fetch_profile_data(symbol)
    response = cached_get("/stock/profile2?symbol=#{encode(symbol)}", ttl: PROFILE_TTL)
    parse_json(response) || {}
  end

  def fetch_metric_data(symbol)
    response = cached_get("/stock/metric?symbol=#{encode(symbol)}&metric=#{METRIC_PARAM}", ttl: METRIC_TTL)
    (parse_json(response) || {}).fetch("metric", {})
  end

  def resolve_company_name(symbol, profile_data)
    name = profile_data["name"]
    name = fetch_name(symbol) if name.nil? || name.empty?
    name || symbol
  end

  def build_payload(symbol, profile_data, metric_data)
    profile_fields = extract_profile_fields(symbol, profile_data)
    metric_fields = extract_metric_fields(metric_data)

    profile_fields.merge(metric_fields).merge(fetchedAt: current_timestamp)
  end

  def extract_profile_fields(symbol, data)
    {
      type: Constants::TYPE_PROFILE,
      symbol:,
      name: clean_string(resolve_company_name(symbol, data), MAX_STRING_LENGTH, ellipsis: true),
      industry: clean_string(data["finnhubIndustry"] || DEFAULT_INDUSTRY, MAX_SHORT_STRING_LENGTH, ellipsis: true),
      marketCap: round_field(data["marketCapitalization"]),
      currency: clean_string(data["currency"] || Constants::DEFAULT_CURRENCY, 10, ellipsis: false),
      exchange: clean_string(data["exchange"], 20, ellipsis: false),
      weburl: clean_string(data["weburl"], 200, ellipsis: false)
    }
  end

  def extract_metric_fields(data)
    {
      high52: round_field(data["52WeekHigh"]),
      low52: round_field(data["52WeekLow"]),
      return52: round_field(data["52WeekPriceReturnDaily"]),
      avgVol: round_field(data["10DayAverageTradingVolume"]),
      beta: round_field(data["beta"]),
      peTTM: round_field(data["peTTM"])
    }
  end

  def round_field(value)
    return nil if value.nil?

    val = value.to_f
    val.finite? ? val.round(2) : nil
  end
end
