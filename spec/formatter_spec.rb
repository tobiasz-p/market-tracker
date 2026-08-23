# frozen_string_literal: true

require "spec_helper"

RSpec.describe Formatter do
  describe ".format_price" do
    subject(:formatted_price) { described_class.format_price(price, currency:, stealth:) }

    let(:currency) { "USD" }
    let(:stealth) { false }

    context "with standard USD amount" do
      let(:price) { 543.21 }

      it "formats price with dollar symbol and two decimals" do
        expect(formatted_price).to eq("$543.21")
      end
    end

    context "with sub-dollar penny precision" do
      let(:price) { 1.2345 }

      it "preserves fractional precision" do
        expect(formatted_price).to eq("$1.2345")
      end
    end

    context "with alternative currency symbol" do
      let(:price) { 50.0 }
      let(:currency) { "EUR" }

      it "applies corresponding euro symbol" do
        expect(formatted_price).to eq("€50.00")
      end
    end

    context "when stealth mode is enabled" do
      let(:price) { 543.21 }
      let(:stealth) { true }

      it "masks numbers with asterisks" do
        expect(formatted_price).to eq("$••••")
      end
    end

    context "when price is nil" do
      let(:price) { nil }

      it "returns a placeholder dash" do
        expect(formatted_price).to eq("—")
      end
    end
  end

  describe ".format_delta" do
    subject(:formatted_delta) do
      described_class.format_delta(change, change_pct, currency:, delta_format:, stealth:)
    end

    let(:change) { 1.25 }
    let(:change_pct) { 1.25 }
    let(:currency) { "USD" }
    let(:delta_format) { "percent" }
    let(:stealth) { false }

    context "when delta_format is percent" do
      it "formats positive signed percentage" do
        expect(formatted_delta).to eq("+1.25%")
      end
    end

    context "when delta_format is amount" do
      let(:delta_format) { "amount" }

      it "formats positive signed currency amount" do
        expect(formatted_delta).to eq("+$1.25")
      end
    end

    context "when delta_format is both" do
      let(:delta_format) { "both" }

      it "concatenates amount and percentage" do
        expect(formatted_delta).to eq("+$1.25 +1.25%")
      end
    end

    context "when stealth mode is active with percent" do
      let(:stealth) { true }

      it "preserves percentage performance" do
        expect(formatted_delta).to eq("+1.25%")
      end
    end

    context "when stealth mode is active with amount" do
      let(:delta_format) { "amount" }
      let(:stealth) { true }

      it "masks currency delta" do
        expect(formatted_delta).to eq("$••••")
      end
    end

    context "when stealth mode is active with both" do
      let(:delta_format) { "both" }
      let(:stealth) { true }

      it "masks currency delta while preserving percentage" do
        expect(formatted_delta).to eq("$•••• +1.25%")
      end
    end
  end

  describe ".bar_label" do
    subject(:bar_label) do
      described_class.bar_label(quote, show_price:, delta_format:, stealth:)
    end

    let(:quote) do
      { symbol: "VOO", price: 543.21, change: 1.5, changePct: 0.28, currency: "USD" }
    end
    let(:show_price) { true }
    let(:delta_format) { "percent" }
    let(:stealth) { false }

    context "with default parameters" do
      it "constructs standard ticker line" do
        expect(bar_label).to eq("VOO $543.21 +0.28%")
      end
    end

    context "with stealth mode active" do
      let(:stealth) { true }

      it "masks sensitive price while displaying percentage" do
        expect(bar_label).to eq("VOO $•••• +0.28%")
      end
    end
  end

  describe ".consensus_bar_data" do
    subject(:bar_data) { described_class.consensus_bar_data(recommendations) }

    let(:recommendations) do
      {
        "strongBuy" => 10,
        "buy" => 5,
        "hold" => 3,
        "sell" => 1,
        "strongSell" => 1
      }
    end

    it "computes aggregate analyst count" do
      expect(bar_data[:total]).to eq(20)
    end

    it "calculates percentage for strong buy" do
      expect(bar_data[:pct_strongBuy]).to eq(50.0)
    end

    it "calculates percentage for buy" do
      expect(bar_data[:pct_buy]).to eq(25.0)
    end
  end
end
