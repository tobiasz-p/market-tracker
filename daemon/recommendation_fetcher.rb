# frozen_string_literal: true

require_relative "base_fetcher"
require_relative "constants"

# Fetches analyst recommendation trends and computes consensus ratings from Finnhub.
#
# Retrieves quarterly recommendation breakdowns (strong buy, buy, hold, sell, strong sell)
# from /stock/recommendation and computes a weighted consensus score and classification.
class RecommendationFetcher < BaseFetcher
  TTL = 3600
  MAX_TRENDS = 4

  REC_STRONG_BUY = "Strong Buy"
  REC_BUY = "Buy"
  REC_HOLD = "Hold"
  REC_SELL = "Sell"
  REC_STRONG_SELL = "Strong Sell"

  def fetch(symbol)
    response = cached_get("/stock/recommendation?symbol=#{encode(symbol)}", ttl: TTL)
    if auth_restricted?(response)
      return { type: Constants::TYPE_RECOMMENDATIONS, symbol:, recommendations: [], consensus: nil,
               fetchedAt: current_timestamp }
    end
    return error(symbol, client.error_message_for(response)) unless response&.code == HTTP_OK

    items = parse_json(response)
    recommendations = map_recommendations(items)
    latest = recommendations.first
    consensus = compute_consensus(latest) if latest

    {
      type: Constants::TYPE_RECOMMENDATIONS,
      symbol:,
      recommendations:,
      consensus:,
      fetchedAt: current_timestamp
    }
  rescue *RESCUABLE_ERRORS => e
    error(symbol, e.message)
  end

  private

  def map_recommendations(items)
    Array(items).first(MAX_TRENDS).map do |item|
      {
        period: item["period"],
        strongBuy: item["strongBuy"].to_i,
        buy: item["buy"].to_i,
        hold: item["hold"].to_i,
        sell: item["sell"].to_i,
        strongSell: item["strongSell"].to_i
      }
    end
  end

  def compute_consensus(data)
    total = total_recommendations(data)
    return nil if total.zero?

    score = weighted_score(data, total)
    label = consensus_label_for(score)
    { score: score.round(2), label:, total: }
  end

  def total_recommendations(data)
    data[:strongBuy] + data[:buy] + data[:hold] + data[:sell] + data[:strongSell]
  end

  def weighted_score(data, total)
    weighted_sum = ((data[:strongBuy] * 2) + (data[:buy] * 1) + (data[:hold] * 0) +
                    (data[:sell] * -1) + (data[:strongSell] * -2)).to_f
    weighted_sum / total
  end

  def consensus_label_for(score)
    if score > 0.5
      REC_STRONG_BUY
    elsif score > 0.1
      REC_BUY
    elsif score > -0.1
      REC_HOLD
    elsif score > -0.5
      REC_SELL
    else
      REC_STRONG_SELL
    end
  end
end
