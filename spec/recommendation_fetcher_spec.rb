# frozen_string_literal: true

require "spec_helper"

RSpec.describe RecommendationFetcher do
  include_context "with finnhub client"

  let(:fetcher) { described_class.new(client:, cache:) }

  describe "#fetch" do
    subject(:recommendations) { fetcher.fetch(symbol) }

    let(:symbol) { "NVDA" }

    context "when recommendations API responds with consensus breakdown" do
      let(:recommendations_payload) do
        [
          { "period" => "2026-08-01", "strongBuy" => 30, "buy" => 15, "hold" => 5, "sell" => 1, "strongSell" => 0 }
        ]
      end

      before do
        allow(client).to receive(:get).with("/stock/recommendation?symbol=NVDA")
                                      .and_return(mock_response(code: 200, body: recommendations_payload))
      end

      it "sets payload type to recommendations" do
        expect(recommendations[:type]).to eq("recommendations")
      end

      it "maps consensus label" do
        expect(recommendations.dig(:consensus, :label)).to eq("Strong Buy")
      end
    end
  end
end
