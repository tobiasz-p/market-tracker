# frozen_string_literal: true

require "spec_helper"

RSpec.describe Config do
  let(:config) { described_class.new(env) }

  describe "#api_key" do
    subject(:api_key) { config.api_key }

    context "when FINNHUB_API_KEY is provided in environment" do
      let(:env) { { "FINNHUB_API_KEY" => "  secret_key_123  " } }

      it "strips and returns the api key" do
        expect(api_key).to eq("secret_key_123")
      end
    end

    context "when FINNHUB_API_KEY is not set" do
      let(:env) { {} }

      it "returns empty string" do
        expect(api_key).to eq("")
      end
    end
  end

  describe "#symbols" do
    subject(:symbols) { config.symbols }

    context "when parsing multiple ticker entries" do
      let(:env) { { "SYMBOLS" => "VOO:10, AAPL" } }

      it "extracts tickers in order" do
        expect(symbols.map(&:ticker)).to eq(%w[VOO AAPL])
      end

      it "parses fractional share counts" do
        expect(symbols.first.shares).to eq(10.0)
      end

      it "handles tickers without share counts" do
        expect(symbols.last.shares).to be_nil
      end
    end

    context "when parsing namespaced crypto symbols with shares" do
      let(:env) { { "SYMBOLS" => "BINANCE:BTCUSDT:0.5, COINBASE:ETH-USD" } }

      it "preserves colon in ticker name" do
        expect(symbols.map(&:ticker)).to eq(%w[BINANCE:BTCUSDT COINBASE:ETH-USD])
      end

      it "parses fractional shares for crypto" do
        expect(symbols.first.shares).to eq(0.5)
      end

      it "handles crypto without shares" do
        expect(symbols.last.shares).to be_nil
      end
    end
  end

  describe "#tickers" do
    subject(:tickers) { config.tickers }

    context "when symbols contain mixed tickers and share quantities" do
      let(:env) { { "SYMBOLS" => "VOO:10, NVDA:25.5, AAPL" } }

      it "extracts normalized uppercase ticker list" do
        expect(tickers).to eq(%w[VOO NVDA AAPL])
      end
    end

    context "when symbols string has excess whitespace" do
      let(:env) { { "SYMBOLS" => "  voo ,  msft  " } }

      it "strips and upper-cases entries" do
        expect(tickers).to eq(%w[VOO MSFT])
      end
    end
  end

  describe "#shares_for" do
    subject(:shares) { config.shares_for(target_symbol) }

    context "when symbol has configured share quantity" do
      let(:env) { { "SYMBOLS" => "VOO:10.5, NVDA:25" } }
      let(:target_symbol) { "VOO" }

      it "returns allocated float shares" do
        expect(shares).to eq(10.5)
      end
    end

    context "when symbol has no configured share count" do
      let(:env) { { "SYMBOLS" => "VOO:10, NVDA" } }
      let(:target_symbol) { "NVDA" }

      it "returns nil" do
        expect(shares).to be_nil
      end
    end
  end

  describe "#portfolio?" do
    subject(:portfolio) { config.portfolio? }

    context "when at least one ticker specifies positive shares" do
      let(:env) { { "SYMBOLS" => "VOO:10, AAPL" } }

      it "returns true" do
        expect(portfolio).to be true
      end
    end

    context "when no tickers specify shares" do
      let(:env) { { "SYMBOLS" => "VOO, AAPL" } }

      it "returns false" do
        expect(portfolio).to be false
      end
    end
  end

  describe "#refresh_seconds" do
    subject(:refresh_seconds) { config.refresh_seconds }

    context "when interval is below minimum threshold" do
      let(:env) { { "REFRESH_SECONDS" => "5" } }

      it "clamps to minimum allowed bound" do
        expect(refresh_seconds).to eq(Config::REFRESH_MIN)
      end
    end

    context "when interval is above maximum threshold" do
      let(:env) { { "REFRESH_SECONDS" => "500" } }

      it "clamps to maximum allowed bound" do
        expect(refresh_seconds).to eq(Config::REFRESH_MAX)
      end
    end

    context "when interval is valid" do
      let(:env) { { "REFRESH_SECONDS" => "45" } }

      it "preserves configured value" do
        expect(refresh_seconds).to eq(45)
      end
    end
  end

  describe "#rotate_seconds" do
    subject(:rotate_seconds) { config.rotate_seconds }

    context "when rotation is negative" do
      let(:env) { { "ROTATE_SECONDS" => "-1" } }

      it "clamps to zero" do
        expect(rotate_seconds).to eq(0)
      end
    end

    context "when rotation is positive" do
      let(:env) { { "ROTATE_SECONDS" => "10" } }

      it "preserves configured value" do
        expect(rotate_seconds).to eq(10)
      end
    end
  end

  describe "#delta_format" do
    subject(:delta_format) { config.delta_format }

    context "with explicit amount setting" do
      let(:env) { { "DELTA_FORMAT" => "amount" } }

      it "returns amount" do
        expect(delta_format).to eq("amount")
      end
    end

    context "with explicit both setting" do
      let(:env) { { "DELTA_FORMAT" => "both" } }

      it "returns both" do
        expect(delta_format).to eq("both")
      end
    end

    context "with invalid or empty setting" do
      let(:env) { { "DELTA_FORMAT" => "unknown" } }

      it "defaults to percent" do
        expect(delta_format).to eq("percent")
      end
    end
  end

  describe "display settings" do
    context "with default environment" do
      let(:env) { {} }

      it "enables price by default" do
        expect(config.show_price).to be true
      end

      it "disables stealth mode by default" do
        expect(config.stealth_mode).to be false
      end
    end

    context "with custom disabled display flags" do
      let(:env) do
        {
          "SHOW_PRICE" => "false",
          "STEALTH_MODE" => "true"
        }
      end

      it "disables price" do
        expect(config.show_price).to be false
      end

      it "enables stealth mode" do
        expect(config.stealth_mode).to be true
      end
    end
  end

  describe "feature flags" do
    context "with default environment" do
      let(:env) { {} }

      it "enables company profile by default" do
        expect(config.show_company_profile).to be true
      end

      it "enables recommendations by default" do
        expect(config.show_recommendations).to be true
      end

      it "enables news by default" do
        expect(config.show_news).to be true
      end
    end

    context "with custom disabled feature flags" do
      let(:env) do
        {
          "SHOW_COMPANY_PROFILE" => "false",
          "SHOW_RECOMMENDATIONS" => "0",
          "SHOW_NEWS" => "off"
        }
      end

      it "disables company profile" do
        expect(config.show_company_profile).to be false
      end

      it "disables recommendations" do
        expect(config.show_recommendations).to be false
      end

      it "disables news" do
        expect(config.show_news).to be false
      end
    end
  end

  describe "#snapshot" do
    subject(:snapshot) { config.snapshot }

    let(:env) do
      {
        "SYMBOLS" => "VOO:10, AAPL",
        "SHOW_PRICE" => "true",
        "STEALTH_MODE" => "false",
        "ROTATE_SECONDS" => "8"
      }
    end

    it "serializes complete configuration payload" do
      expect(snapshot).to include(
        showPrice: true,
        stealthMode: false,
        rotateSeconds: 8,
        portfolio: true,
        symbols: [{ ticker: "VOO", shares: 10.0 }, { ticker: "AAPL" }]
      )
    end
  end
end
