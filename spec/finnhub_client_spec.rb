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
    let(:success_response) { instance_double(Net::HTTPOK, code: "200", body: '{"c":123.45}') }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http_double)
      allow(http_double).to receive(:use_ssl=)
      allow(http_double).to receive(:verify_mode=)
      allow(http_double).to receive(:open_timeout=)
      allow(http_double).to receive(:read_timeout=)
      allow(http_double).to receive(:request).and_yield(success_response)
      allow(success_response).to receive(:read_body).and_yield('{"c":123.45}')
    end

    it "attaches authorization token header" do
      get_request
      expect(http_double).to have_received(:request).with(
        an_object_having_attributes(to_hash: hash_including("x-finnhub-token" => ["secret_key"]))
      )
    end

    it "streams and populates the response body" do
      expect(get_request.body).to eq('{"c":123.45}')
    end

    context "when response body exceeds MAX_BODY_BYTES ceiling" do
      let(:oversized_chunk) { "A" * (1_048_576 + 10) }

      before do
        allow(success_response).to receive(:read_body).and_yield(oversized_chunk)
      end

      it "raises ResponseBodyTooLargeError" do
        expect { get_request }.to raise_error(described_class::ResponseBodyTooLargeError)
      end
    end

    context "when response redirects to an untrusted host" do
      let(:redirect_response) do
        instance_double(Net::HTTPMovedPermanently, code: "301", is_a?: true).tap do |res|
          allow(res).to receive(:[]).with("location").and_return("https://evil.com/quote")
        end
      end

      before do
        allow(http_double).to receive(:request).and_yield(redirect_response)
      end

      it "rejects cross-host redirection and returns empty body" do
        expect(get_request.body).to eq("")
      end
    end
  end
end
