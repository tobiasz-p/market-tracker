# frozen_string_literal: true

# Thread-safe in-memory key-value cache with monotonic clock expiration tracking.
#
# Provides TTL-based memoization for external HTTP API responses, explicit key eviction,
# and bulk expiration invalidation upon user-triggered forced refreshes.
class Cache
  DEFAULT_TTL = 60

  Entry = Struct.new(:value, :expires_at)

  def initialize(default_ttl: DEFAULT_TTL, clock: nil)
    @default_ttl = default_ttl
    @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    @store = {}
  end

  def get(key, ttl: @default_ttl, force_refresh: false)
    now = now_monotonic
    entry = @store[key]

    return entry.value if entry && !force_refresh && entry.expires_at > now

    computed_value = yield
    @store[key] = Entry.new(computed_value, now + ttl)
    computed_value
  end

  def invalidate_all
    @store.each_value { |entry| entry.expires_at = 0.0 }
  end

  def clear
    @store.clear
  end

  private

  def now_monotonic
    @clock.call
  end
end
