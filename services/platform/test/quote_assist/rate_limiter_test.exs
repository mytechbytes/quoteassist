defmodule QuoteAssist.RateLimiterTest do
  # async: false — the limiter is a single named ETS table shared process-wide.
  use ExUnit.Case, async: false

  alias QuoteAssist.RateLimiter

  setup do
    RateLimiter.reset()
    :ok
  end

  test "allows up to the limit, then rate-limits within the same window" do
    key = {:test, System.unique_integer()}

    assert RateLimiter.hit(key, 3, 60_000) == :ok
    assert RateLimiter.hit(key, 3, 60_000) == :ok
    assert RateLimiter.hit(key, 3, 60_000) == :ok
    assert RateLimiter.hit(key, 3, 60_000) == {:error, :rate_limited}
    assert RateLimiter.hit(key, 3, 60_000) == {:error, :rate_limited}
  end

  test "counts distinct keys independently" do
    a = {:test, System.unique_integer()}
    b = {:test, System.unique_integer()}

    assert RateLimiter.hit(a, 1, 60_000) == :ok
    assert RateLimiter.hit(a, 1, 60_000) == {:error, :rate_limited}

    # b is unaffected by a reaching its limit.
    assert RateLimiter.hit(b, 1, 60_000) == :ok
  end

  test "a new window resets the count" do
    key = {:test, System.unique_integer()}

    # window_ms: 1 makes every millisecond its own bucket.
    assert RateLimiter.hit(key, 1, 1) == :ok
    Process.sleep(3)
    assert RateLimiter.hit(key, 1, 1) == :ok
  end

  test "reset/0 clears recorded hits" do
    key = {:test, System.unique_integer()}

    assert RateLimiter.hit(key, 1, 60_000) == :ok
    assert RateLimiter.hit(key, 1, 60_000) == {:error, :rate_limited}

    RateLimiter.reset()

    assert RateLimiter.hit(key, 1, 60_000) == :ok
  end
end
