defmodule Deflector.CircuitBreaker.ThresholdTest do
  use ExUnit.Case, async: false
  alias Deflector.CircuitBreaker

  test "respects configurable min_volume before tripping" do
    name = :volume_test_breaker
    {:ok, _} = CircuitBreaker.start_link(name: name, threshold: 0.5, min_volume: 10)

    # 4 failures should not trip because min_volume is 10
    for _ <- 1..4 do
      CircuitBreaker.call(name, fn -> {:error, :transient} end)
    end
    assert :closed == CircuitBreaker.get_state(name)

    # Reaching 10 total with 6 failures trips the breaker
    for _ <- 1..6 do
      CircuitBreaker.call(name, fn -> {:error, :transient} end)
    end
    assert :open == CircuitBreaker.get_state(name)
  end
end