# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daemon do
  let(:daemon) { described_class.new(config:) }
  let(:logger) { instance_double(AppLogger, warn: nil, error: nil) }
  let(:config) do
    Config.new({ "SYMBOLS" => "NVDA", "FINNHUB_API_KEY" => "test_key" })
  end
  let(:quote_fetcher) { instance_double(QuoteFetcher) }
  let(:stdout_buffer) { StringIO.new }

  before do
    allow(AppLogger).to receive(:new).and_return(logger)
    allow(QuoteFetcher).to receive(:new).and_return(quote_fetcher)
    allow($stdout).to receive(:puts) { |msg| stdout_buffer.puts(msg) }
    allow($stdout).to receive(:flush)
  end

  describe "#run_fast_cycle" do
    subject(:run_fast_cycle) { daemon.run_fast_cycle }

    context "when tickers list is empty" do
      let(:config) { Config.new({ "SYMBOLS" => "" }) }

      before do
        run_fast_cycle
      end

      it "logs warning via logger" do
        expect(logger).to have_received(:warn).with("No symbols configured")
      end
    end

    context "when quote fetcher returns valid quote data" do
      let(:quote_data) do
        {
          type: "quote",
          symbol: "NVDA",
          name: "NVIDIA",
          price: 125.5,
          change: 2.5,
          changePct: 2.03,
          currency: "USD"
        }
      end
      let(:emitted_payload) do
        run_fast_cycle
        line = stdout_buffer.string.lines.map(&:strip).reject(&:empty?).first
        JSON.parse(line)
      end

      before do
        allow(quote_fetcher).to receive(:fetch).with("NVDA", force_refresh: false).and_return(quote_data)
      end

      it "emits single quote message" do
        run_fast_cycle
        expect(stdout_buffer.string.lines.length).to eq(1)
      end

      it "emits quote type" do
        expect(emitted_payload["type"]).to eq("quote")
      end

      it "emits matched ticker symbol" do
        expect(emitted_payload["symbol"]).to eq("NVDA")
      end

      it "emits parsed trade price" do
        expect(emitted_payload["price"]).to eq(125.5)
      end

      it "computes formatted bar label" do
        expect(emitted_payload["barLabel"]).to include("NVDA")
      end
    end
  end

  describe "#handle_command" do
    subject(:handle_command) { daemon.handle_command(command) }

    context "when command is fetch_detail" do
      let(:command) { { "action" => "fetch_detail", "symbol" => "NVDA" } }

      before do
        allow(daemon).to receive(:fetch_detail)
        handle_command
      end

      it "dispatches fetch_detail with target symbol" do
        expect(daemon).to have_received(:fetch_detail).with("NVDA")
      end
    end
  end

  describe "#perform_detail_fetch" do
    subject(:perform_detail_fetch) { daemon.perform_detail_fetch("NVDA") }

    let(:profile_fetcher) { instance_double(ProfileFetcher, fetch: { type: "profile", symbol: "NVDA" }) }
    let(:news_fetcher) { instance_double(NewsFetcher, fetch: { type: "news", symbol: "NVDA" }) }
    let(:recommendation_fetcher) do
      instance_double(RecommendationFetcher, fetch: { type: "recommendations", symbol: "NVDA" })
    end

    before do
      allow(ProfileFetcher).to receive(:new).and_return(profile_fetcher)
      allow(NewsFetcher).to receive(:new).and_return(news_fetcher)
      allow(RecommendationFetcher).to receive(:new).and_return(recommendation_fetcher)
      perform_detail_fetch
    end

    it "emits profile, news, and recommendations payloads" do
      lines = stdout_buffer.string.lines.map(&:strip).reject(&:empty?)
      expect(lines.length).to eq(3)
    end
  end
end
