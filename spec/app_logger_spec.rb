# frozen_string_literal: true

require "spec_helper"

RSpec.describe AppLogger do
  subject(:logger) { described_class.new(device) }

  let(:device) { StringIO.new }

  it "subclasses standard Logger instance" do
    expect(logger).to be_a(Logger)
  end

  it "sets progname to market-tracker" do
    expect(logger.progname).to eq("market-tracker")
  end

  it "formats logged warnings with progname prefix" do
    logger.warn("testing warning")
    expect(device.string).to eq("[market-tracker] testing warning\n")
  end
end
