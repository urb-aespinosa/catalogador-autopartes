module Catalog
  # Network courtesy: at most one request per `min_interval` seconds per host.
  # Shared by all threads of the single job process (D12).
  class HostThrottle
    DEFAULT_INTERVAL = 1.0

    def self.instance
      @instance ||= new(min_interval: Rails.configuration.x.catalog.min_interval)
    end

    def initialize(min_interval:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, sleeper: ->(seconds) { sleep(seconds) })
      @min_interval = min_interval
      @clock = clock
      @sleeper = sleeper
      @last_request_at = {}
      @mutex = Mutex.new
    end

    # Holding the lock while sleeping serializes same-host requests across threads.
    def wait(host)
      @mutex.synchronize do
        last = @last_request_at[host]
        if last
          remaining = @min_interval - (@clock.call - last)
          @sleeper.call(remaining) if remaining.positive?
        end
        @last_request_at[host] = @clock.call
      end
    end
  end
end
