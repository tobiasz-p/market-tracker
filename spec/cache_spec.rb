# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cache do
  let(:cache) { described_class.new(default_ttl: ttl, clock:) }
  let(:ttl) { 60 }
  let(:time_ref) { { now: 100.0 } }
  let(:clock) { -> { time_ref[:now] } }

  describe "#get" do
    subject(:cached_value) { cache.get(cache_key, force_refresh:, &fetch_block) }

    let(:cache_key) { "/quote" }
    let(:force_refresh) { false }
    let(:fetch_block) { -> { "initial_value" } }

    context "when key has not been cached" do
      it "computes and returns yielded block value" do
        expect(cached_value).to eq("initial_value")
      end
    end

    context "when key is cached and within TTL" do
      before do
        cache.get(cache_key) { "cached_value" }
      end

      let(:fetch_block) { -> { "new_value" } }

      it "returns stored value without re-evaluating block" do
        expect(cached_value).to eq("cached_value")
      end
    end

    context "when TTL has elapsed" do
      before do
        cache.get(cache_key) { "initial_value" }
        time_ref[:now] = 161.0
      end

      let(:fetch_block) { -> { "refreshed_value" } }

      it "re-evaluates block and updates stored value" do
        expect(cached_value).to eq("refreshed_value")
      end
    end

    context "when force_refresh is requested" do
      before do
        cache.get(cache_key) { "initial_value" }
      end

      let(:force_refresh) { true }
      let(:fetch_block) { -> { "forced_value" } }

      it "bypasses existing fresh entry and stores new value" do
        expect(cached_value).to eq("forced_value")
      end
    end

    context "when entries exceed max_entries limit" do
      let(:cache) { described_class.new(default_ttl: 60, max_entries: 2, clock:) }

      it "evicts oldest entries to enforce capacity limit" do
        cache.get("key_1") { "val_1" }
        cache.get("key_2") { "val_2" }
        cache.get("key_3") { "val_3" }

        expect(cache.get("key_1") { "val_1_recomputed" }).to eq("val_1_recomputed")
      end
    end
  end

  describe "#invalidate_all" do
    subject(:invalidate_all) { cache.invalidate_all }

    before do
      cache.get("key_a") { "value_a" }
    end

    it "expires all cached keys immediately" do
      expect { invalidate_all }.to change { cache.get("key_a") { "new_value_a" } }.from("value_a").to("new_value_a")
    end
  end

  describe "#clear" do
    subject(:clear_cache) { cache.clear }

    before do
      cache.get("key_a") { "value_a" }
    end

    it "purges underlying storage" do
      expect { clear_cache }.to change {
        cache.get("key_a") {
          "cleared_value_a"
        }
      }.from("value_a").to("cleared_value_a")
    end
  end
end
