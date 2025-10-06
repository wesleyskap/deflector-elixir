defmodule Deflector.CircuitBreakerTest do
  use ExUnit.Case, async: false
  alias Deflector.CircuitBreaker

  setup do
    name = :test_breaker_1
    opts = [name: name, threshold: 0.5, reset_timeout: 50]
    {:ok, pid} = CircuitBreaker.start_link(opts)
    %{breaker: name, pid: pid}
  end

  test "executes function cleanly when closed", %{breaker: breaker} do
    assert {:ok, 42} = CircuitBreaker.call(breaker, fn -> 42 end)
    assert :closed == CircuitBreaker.get_state(breaker)
  end

  test "trips open when failure threshold is exceeded", %{breaker: breaker} do
    for _ <- 1..6 do
      CircuitBreaker.call(breaker, fn -> {:error, :timeout} end)
    end

    assert :open == CircuitBreaker.get_state(breaker)
    assert {:error, :circuit_open} = CircuitBreaker.call(breaker, fn -> :ok end)
  end

  test "transitions to half_open and closes on canary success", %{breaker: breaker} do
    for _ <- 1..6 do
      CircuitBreaker.call(breaker, fn -> {:error, :network_error} end)
    end

    assert :open == CircuitBreaker.get_state(breaker)
    Process.sleep(70)

    assert :half_open == CircuitBreaker.get_state(breaker)
    assert {:ok, :recovered} = CircuitBreaker.call(breaker, fn -> :recovered end)
    assert :closed == CircuitBreaker.get_state(breaker)
  end
end