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

    context "when profile data contains oversized string fields" do
      let(:profile_payload) do
        {
          name: "A" * 200,
          finnhubIndustry: "B" * 100,
          exchange: "NASDAQ"
        }
      end

      before do
        allow(client).to receive(:get).with("/stock/profile2?symbol=NVDA")
                                      .and_return(mock_response(code: 200, body: profile_payload))
        allow(client).to receive(:get).with("/stock/metric?symbol=NVDA&metric=all")
                                      .and_return(mock_response(code: 200, body: {}))
      end

      it "truncates company name to maximum length" do
        expect(profile[:name].length).to eq(100)
      end

      it "appends ellipsis to truncated company name" do
        expect(profile[:name]).to end_with("...")
      end

      it "truncates industry to maximum short string length" do
        expect(profile[:industry].length).to eq(50)
      end

      it "appends ellipsis to truncated industry" do
        expect(profile[:industry]).to end_with("...")
      end
    end

    context "when API strings have leading and trailing whitespace" do
      let(:profile_payload) do
        {
          name: "   Apple Inc.   ",
          finnhubIndustry: "   Technology   ",
          exchange: "   NASDAQ   ",
          weburl: "   https://apple.com   "
        }
      end

      before do
        allow(client).to receive(:get).with("/stock/profile2?symbol=NVDA")
                                      .and_return(mock_response(code: 200, body: profile_payload))
        allow(client).to receive(:get).with("/stock/metric?symbol=NVDA&metric=all")
                                      .and_return(mock_response(code: 200, body: {}))
      end

      it "strips whitespace from company name" do
        expect(profile[:name]).to eq("Apple Inc.")
      end

      it "strips whitespace from industry" do
        expect(profile[:industry]).to eq("Technology")
      end

      it "strips whitespace from exchange" do
        expect(profile[:exchange]).to eq("NASDAQ")
      end

      it "strips whitespace from weburl" do
        expect(profile[:weburl]).to eq("https://apple.com")
      end
    end
  end
end
