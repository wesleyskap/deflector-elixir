defmodule Deflector.RateLimiter.PrecisionTest do
  use ExUnit.Case, async: false
  alias Deflector.RateLimiter

  test "maintains fractional replenishment over microsecond intervals" do
    name = :precision_limiter
    {:ok, _} = RateLimiter.start_link(name: name, rate: 100, capacity: 10)

    assert {:ok, 0} = RateLimiter.acquire(name, 10)
    # Sleep 35ms -> ~3.5 tokens added
    Process.sleep(35)
    assert {:ok, _} = RateLimiter.acquire(name, 3)
  end
end