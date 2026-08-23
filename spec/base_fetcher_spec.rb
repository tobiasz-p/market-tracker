# frozen_string_literal: true

require "spec_helper"

RSpec.describe BaseFetcher do
  include_context "with finnhub client"

  let(:fetcher) { described_class.new(client:, cache:) }

  describe "#fetch_name" do
    subject(:company_name) { fetcher.send(:fetch_name, symbol) }

    let(:symbol) { "VOO" }

    context "when search API returns matched company description" do
      let(:search_payload) do
        { result: [{ symbol: "VOO", description: "Vanguard S&P 500 ETF" }] }
      end

      before do
        allow(client).to receive(:get).with("/search?q=VOO")
                                      .and_return(mock_response(code: 200, body: search_payload))
      end

      it "extracts company description" do
        expect(company_name).to eq("Vanguard S&P 500 ETF")
      end
    end

    context "when search API fails" do
      before do
        allow(client).to receive(:get).with("/search?q=VOO")
                                      .and_return(mock_response(code: 500, body: "Server Error"))
      end

      it "returns nil" do
        expect(company_name).to be_nil
      end
    end
  end
end
