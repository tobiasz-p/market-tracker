# frozen_string_literal: true

require "spec_helper"

RSpec.describe NewsFetcher do
  include_context "with finnhub client"

  let(:fetcher) { described_class.new(client:, cache:) }

  describe "#fetch" do
    subject(:news) { fetcher.fetch(symbol) }

    let(:symbol) { "NVDA" }

    context "when company news API responds with articles" do
      let(:articles) do
        [
          { "headline" => "NVIDIA announces new GPU architecture", "source" => "Reuters", "url" => "https://news.com/1", "datetime" => 1_700_000_000 }
        ]
      end

      before do
        allow(client).to receive(:get).with(%r{/company-news\?symbol=NVDA})
                                      .and_return(mock_response(code: 200, body: articles))
      end

      it "sets payload type to news" do
        expect(news[:type]).to eq("news")
      end

      it "extracts article headline" do
        expect(news[:headlines].first[:headline]).to eq("NVIDIA announces new GPU architecture")
      end
    end
  end
end
