defmodule Deflector.Telemetry do
  @moduledoc """
  Telemetry dispatcher and event publisher for Deflector resilience events.
  """

  @doc """
  Dispatches an execution measurement event.
  """
  def execute(primitive, name, duration_micro, result) do
    measurements = %{duration_micro: duration_micro}
    metadata = %{primitive: primitive, name: name, result: result}
    :telemetry.execute([:deflector, primitive, :execution], measurements, metadata)
  rescue
    UndefinedFunctionError ->
      # Graceful fallback when :telemetry application is not loaded
      :ok
  end

  @doc """
  Dispatches a circuit breaker state transition event.
  """
  def transition(name, from_state, to_state) do
    measurements = %{timestamp: System.system_time(:millisecond)}
    metadata = %{name: name, from: from_state, to: to_state}
    :telemetry.execute([:deflector, :circuit_breaker, :transition], measurements, metadata)
  rescue
    UndefinedFunctionError ->
      :ok
  end
end