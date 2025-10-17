defmodule DeflectorTest do
  use ExUnit.Case, async: false
  alias Deflector.{CircuitBreaker, Bulkhead, RateLimiter}

  setup do
    cb = :def_cb
    bh = :def_bh
    rl = :def_rl

    {:ok, _} = CircuitBreaker.start_link(name: cb, threshold: 0.5)
    {:ok, _} = Bulkhead.start_link(name: bh, max_concurrent: 5)
    {:ok, _} = RateLimiter.start_link(name: rl, capacity: 5)

    %{cb: cb, bh: bh, rl: rl}
  end

  test "protects execution across full resilience chain", %{cb: cb, bh: bh, rl: rl} do
    opts = [circuit_breaker: cb, bulkhead: bh, rate_limiter: rl]
    assert {:ok, 123} = Deflector.protect(opts, fn -> 123 end)
  end

  test "fails fast when rate limiter exhausts quota", %{cb: cb, bh: bh, rl: rl} do
    opts = [circuit_breaker: cb, bulkhead: bh, rate_limiter: rl]
    for _ <- 1..5 do
      assert {:ok, :ok} = Deflector.protect(opts, fn -> :ok end)
    end

    assert {:error, :rate_limited} = Deflector.protect(opts, fn -> :ok end)
  end
end