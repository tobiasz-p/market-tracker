# frozen_string_literal: true

require "spec_helper"

RSpec.describe ProfileFetcher do
  include_context "with finnhub client"

  let(:fetcher) { described_class.new(client:, cache:) }

  describe "#fetch" do
    subject(:profile) { fetcher.fetch(symbol) }

    let(:symbol) { "NVDA" }

    context "when profile and metrics APIs respond successfully" do
      let(:profile_payload) do
        {
          name: "NVIDIA Corp",
          finnhubIndustry: "Semiconductors",
          marketCapitalization: 3_000_000.0,
          exchange: "NASDAQ"
        }
      end
      let(:metric_payload) do
        { metric: { "52WeekHigh": 140.0, "52WeekLow": 45.0, "52WeekPriceReturnDaily": 150.0, peTTM: 65.0 } }
      end

      before do
        allow(client).to receive(:get).with("/stock/profile2?symbol=NVDA")
                                      .and_return(mock_response(code: 200, body: profile_payload))
        allow(client).to receive(:get).with("/stock/metric?symbol=NVDA&metric=all")
                                      .and_return(mock_response(code: 200, body: metric_payload))
      end

      it "sets payload type to profile" do
        expect(profile[:type]).to eq("profile")
      end

      it "extracts company name" do
        expect(profile[:name]).to eq("NVIDIA Corp")
      end

      it "parses 52-week high" do
        expect(profile[:high52]).to eq(140.0)
      end

      it "parses 52-week low" do
        expect(profile[:low52]).to eq(45.0)
      end
    end
  end
end
