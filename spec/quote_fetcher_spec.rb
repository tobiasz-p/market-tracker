# frozen_string_literal: true

require "spec_helper"

RSpec.describe QuoteFetcher do
  include_context "with finnhub client"

  let(:fetcher) { described_class.new(client:, cache:) }

  describe "#fetch" do
    subject(:quote) { fetcher.fetch(symbol, force_refresh:) }

    let(:symbol) { "NVDA" }
    let(:force_refresh) { false }

    context "when quote API responds successfully" do
      let(:quote_payload) do
        { c: 125.5, d: 2.5, dp: 2.03, h: 126.0, l: 122.0, o: 123.0, pc: 123.0, t: 1_700_000_000 }
      end
      let(:search_payload) do
        { result: [{ symbol: "NVDA", description: "NVIDIA CORP" }] }
      end

      before do
        allow(client).to receive(:get).with("/quote?symbol=NVDA")
                                      .and_return(mock_response(code: 200, body: quote_payload))
        allow(client).to receive(:get).with("/search?q=NVDA")
                                      .and_return(mock_response(code: 200, body: search_payload))
      end

      it "sets payload type to quote" do
        expect(quote[:type]).to eq("quote")
      end

      it "formats ticker symbol" do
        expect(quote[:symbol]).to eq("NVDA")
      end

      it "resolves company description" do
        expect(quote[:name]).to eq("NVIDIA CORP")
      end

      it "parses current trade price" do
        expect(quote[:price]).to eq(125.5)
      end

      it "calculates daily dollar change" do
        expect(quote[:change]).to eq(2.5)
      end
    end

    context "when quote API returns error status" do
      before do
        allow(client).to receive(:get).with("/quote?symbol=NVDA")
                                      .and_return(mock_response(code: 429, body: "Rate Limit"))
        allow(client).to receive(:get).with("/search?q=NVDA")
                                      .and_return(mock_response(code: 429, body: "Rate Limit"))
      end

      it "returns error payload type" do
        expect(quote[:type]).to eq("error")
      end

      it "includes symbol in error" do
        expect(quote[:symbol]).to eq("NVDA")
      end
    end
  end
end
