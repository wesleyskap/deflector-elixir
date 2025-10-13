defmodule Deflector.RateLimiterTest do
  use ExUnit.Case, async: false
  alias Deflector.RateLimiter

  setup do
    name = :test_limiter_1
    {:ok, pid} = RateLimiter.start_link(name: name, rate: 10, capacity: 5)
    %{limiter: name, pid: pid}
  end

  test "acquires tokens within initial capacity", %{limiter: limiter} do
    assert {:ok, 4} = RateLimiter.acquire(limiter, 1)
    assert {:ok, 2} = RateLimiter.acquire(limiter, 2)
  end

  test "exhausts tokens and rejects subsequent requests", %{limiter: limiter} do
    assert {:ok, 0} = RateLimiter.acquire(limiter, 5)
    assert {:error, :rate_limited} = RateLimiter.acquire(limiter, 1)
  end

  test "replenishes tokens over elapsed time", %{limiter: limiter} do
    assert {:ok, 0} = RateLimiter.acquire(limiter, 5)
    Process.sleep(250)
    assert {:ok, _} = RateLimiter.acquire(limiter, 1)
  end
end