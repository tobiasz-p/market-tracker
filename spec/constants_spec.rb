# frozen_string_literal: true

require "spec_helper"

RSpec.describe Constants do
  it "defines quote message type" do
    expect(described_class::TYPE_QUOTE).to eq("quote")
  end

  it "defines error message type" do
    expect(described_class::TYPE_ERROR).to eq("error")
  end

  it "defines default currency" do
    expect(described_class::DEFAULT_CURRENCY).to eq("USD")
  end

  it "defines delta percent format" do
    expect(described_class::DELTA_PERCENT).to eq("percent")
  end
end
