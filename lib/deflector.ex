defmodule Deflector do
  @moduledoc """
  Unified facade providing simple, composable resilience guards for Elixir.
  """
  alias Deflector.{CircuitBreaker, Bulkhead, RateLimiter, Telemetry}

  @doc """
  Executes a function protected by circuit breaker, bulkhead and rate limiter policies.
  """
  def protect(opts, fun) when is_list(opts) and is_function(fun, 0) do
    start_time = System.monotonic_time(:microsecond)
    result = run_pipeline(opts, fun)
    duration = System.monotonic_time(:microsecond) - start_time
    Telemetry.execute(:unified, Keyword.get(opts, :name, :default), duration, result_status(result))
    result
  end

  defp run_pipeline(opts, fun) do
    with :ok <- check_rate_limiter(opts),
         {:ok, res} <- run_with_bulkhead(opts, fun) do
      {:ok, res}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_rate_limiter(opts) do
    case Keyword.get(opts, :rate_limiter) do
      nil -> :ok
      limiter_name ->
        case RateLimiter.acquire(limiter_name, 1) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp run_with_bulkhead(opts, fun) do
    case Keyword.get(opts, :bulkhead) do
      nil -> run_with_circuit_breaker(opts, fun)
      bulkhead_name ->
        Bulkhead.execute(bulkhead_name, fn ->
          run_with_circuit_breaker(opts, fun)
        end)
    end
  end

  defp run_with_circuit_breaker(opts, fun) do
    case Keyword.get(opts, :circuit_breaker) do
      nil ->
        try do
          case fun.() do
            {:error, reason} -> {:error, reason}
            other -> {:ok, other}
          end
        rescue
          e -> {:error, e}
        catch
          :exit, r -> {:error, {:exit, r}}
        end

      cb_name ->
        CircuitBreaker.call(cb_name, fun)
    end
  end

  defp result_status({:ok, _}), do: :success
  defp result_status({:error, reason}), do: {:error, reason}
end