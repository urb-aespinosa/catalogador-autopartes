require "test_helper"

class Catalog::HostThrottleTest < ActiveSupport::TestCase
  test "waits min_interval between requests to the same host only" do
    sleeps = []
    throttle = Catalog::HostThrottle.new(min_interval: 1.0, clock: -> { 100.0 }, sleeper: ->(seconds) { sleeps << seconds })

    throttle.wait("a.com")
    throttle.wait("a.com")
    throttle.wait("b.com")

    assert_equal [ 1.0 ], sleeps
  end

  test "does not wait when enough time has passed" do
    now = 100.0
    sleeps = []
    throttle = Catalog::HostThrottle.new(min_interval: 1.0, clock: -> { now }, sleeper: ->(seconds) { sleeps << seconds })

    throttle.wait("a.com")
    now = 101.5
    throttle.wait("a.com")

    assert_empty sleeps
  end

  test "the app throttles to one request per second outside tests" do
    assert_equal 0, Rails.configuration.x.catalog.min_interval
    assert_equal 1.0, Catalog::HostThrottle::DEFAULT_INTERVAL
  end
end
