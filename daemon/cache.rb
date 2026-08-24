# frozen_string_literal: true

# Thread-safe in-memory key-value cache with monotonic clock expiration tracking.
#
# Provides TTL-based memoization for external HTTP API responses, explicit key eviction,
# and bulk expiration invalidation upon user-triggered forced refreshes.
class Cache
  DEFAULT_TTL = 60
  MAX_ENTRIES = 128

  Entry = Struct.new(:value, :expires_at)

  def initialize(default_ttl: DEFAULT_TTL, max_entries: MAX_ENTRIES, clock: nil)
    @default_ttl = default_ttl
    @max_entries = max_entries
    @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    @store = {}
    @mutex = Mutex.new
  end

  def get(key, ttl: @default_ttl, force_refresh: false)
    now = now_monotonic

    @mutex.synchronize do
      entry = @store[key]
      return entry.value if entry && !force_refresh && entry.expires_at > now
    end

    computed_value = yield

    @mutex.synchronize do
      prune_if_needed(now)
      @store[key] = Entry.new(computed_value, now + ttl)
    end

    computed_value
  end

  def invalidate_all
    @mutex.synchronize do
      @store.each_value { |entry| entry.expires_at = 0.0 }
    end
  end

  def clear
    @mutex.synchronize do
      @store.clear
    end
  end

  private

  def prune_if_needed(now)
    return if @store.size < @max_entries

    @store.delete_if { |_k, entry| entry.expires_at <= now }
    return if @store.size < @max_entries

    @store.shift while @store.size >= @max_entries
  end

  def now_monotonic
    @clock.call
  end
end
