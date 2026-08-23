# frozen_string_literal: true

require "spec_helper"

RSpec.describe FinnhubClient do
  subject(:client) { described_class.new(api_key:) }

  let(:api_key) { "secret_key" }

  describe "#error_message_for" do
    subject(:error_message) { client.error_message_for(response) }

    let(:response) { instance_double(Net::HTTPResponse, code: status_code) }

    context "with 401 unauthorized status" do
      let(:status_code) { "401" }

      it "includes invalid API key hint" do
        expect(error_message).to include("invalid or unauthorized API key")
      end
    end

    context "with 429 rate limited status" do
      let(:status_code) { "429" }

      it "includes rate limited hint" do
        expect(error_message).to include("rate limited")
      end
    end

    context "with 500 server error status" do
      let(:status_code) { "500" }

      it "returns raw HTTP status" do
        expect(error_message).to eq("HTTP 500")
      end
    end
  end

  describe "#get" do
    subject(:get_request) { client.get(path) }

    let(:path) { "/quote?symbol=VOO" }
    let(:http_double) { instance_double(Net::HTTP) }
    let(:success_response) { instance_double(Net::HTTPOK, code: "200") }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http_double)
      allow(http_double).to receive(:use_ssl=)
      allow(http_double).to receive(:verify_mode=)
      allow(http_double).to receive(:open_timeout=)
      allow(http_double).to receive(:read_timeout=)
      allow(http_double).to receive(:request).and_return(success_response)
    end

    it "attaches authorization token header" do
      get_request
      expect(http_double).to have_received(:request).with(
        an_object_having_attributes(to_hash: hash_including("x-finnhub-token" => ["secret_key"]))
      )
    end
  end
end
