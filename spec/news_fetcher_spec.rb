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

    context "when API returns oversized strings and more than MAX_ARTICLES" do
      let(:articles) do
        (1..15).map do |i|
          {
            "headline" => "Headline #{i} #{"x" * 300}",
            "source" => "Source #{"s" * 100}",
            "url" => "https://example.com/#{"u" * 600}",
            "summary" => "Summary #{"m" * 600}",
            "datetime" => 1_700_000_000
          }
        end + [nil, "invalid_item"]
      end

      before do
        allow(client).to receive(:get).with(%r{/company-news\?symbol=NVDA})
                                      .and_return(mock_response(code: 200, body: articles))
      end

      it "caps headlines collection at MAX_ARTICLES" do
        expect(news[:headlines].length).to eq(10)
      end

      it "truncates oversized headline string with ellipsis" do
        expect(news[:headlines].first[:headline]).to end_with("...")
      end

      it "caps oversized headline string at maximum length" do
        expect(news[:headlines].first[:headline].length).to eq(200)
      end

      it "truncates oversized source string with ellipsis" do
        expect(news[:headlines].first[:source]).to end_with("...")
      end

      it "caps oversized source string at maximum length" do
        expect(news[:headlines].first[:source].length).to eq(50)
      end

      it "truncates oversized summary string with ellipsis" do
        expect(news[:headlines].first[:summary]).to end_with("...")
      end

      it "caps oversized summary string at maximum length" do
        expect(news[:headlines].first[:summary].length).to eq(500)
      end

      it "caps oversized url string at maximum length without ellipsis" do
        expect(news[:headlines].first[:url].length).to eq(500)
      end
    end

    context "when news fields contain leading and trailing whitespace" do
      let(:articles) do
        [
          {
            "headline" => "   Breaking Market News   ",
            "source" => "   Reuters   ",
            "url" => "   https://news.com/1   ",
            "datetime" => 1_700_000_000
          }
        ]
      end

      before do
        allow(client).to receive(:get).with(%r{/company-news\?symbol=NVDA})
                                      .and_return(mock_response(code: 200, body: articles))
      end

      it "strips whitespace from headline" do
        expect(news[:headlines].first[:headline]).to eq("Breaking Market News")
      end

      it "strips whitespace from source" do
        expect(news[:headlines].first[:source]).to eq("Reuters")
      end

      it "strips whitespace from url" do
        expect(news[:headlines].first[:url]).to eq("https://news.com/1")
      end
    end
  end
end
