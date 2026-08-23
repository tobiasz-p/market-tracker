# frozen_string_literal: true

require "stringio"
require "json"

require_relative "../daemon/config"
require_relative "../daemon/cache"
require_relative "../daemon/constants"
require_relative "../daemon/formatter"
require_relative "../daemon/finnhub_client"
require_relative "../daemon/base_fetcher"
require_relative "../daemon/quote_fetcher"
require_relative "../daemon/profile_fetcher"
require_relative "../daemon/news_fetcher"
require_relative "../daemon/recommendation_fetcher"
require_relative "../daemon/daemon"

RSpec.shared_context "with finnhub client" do
  let(:client) { instance_double(FinnhubClient) }
  let(:cache) { Cache.new(default_ttl: 60) }

  before do
    allow(client).to receive(:error_message_for) { |r| "HTTP #{r.code}" }
  end

  def mock_response(code:, body:)
    instance_double(Net::HTTPResponse, code: code.to_s, body: body.is_a?(String) ? body : body.to_json)
  end
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
