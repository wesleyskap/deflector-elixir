defmodule Deflector.CircuitBreaker do
  @moduledoc """
  GenServer implementation of the Circuit Breaker pattern.
  """
  use GenServer
  alias Deflector.CircuitBreaker.Window

  defstruct [
    :name,
    :state,
    :window,
    :threshold_pct,
    :min_volume,
    :reset_timeout,
    :last_state_change,
    :half_open_probes
  ]

  @default_threshold_pct 50
  @default_min_volume 5
  @default_reset_timeout 5_000

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  def call(name, fun) when is_function(fun, 0) do
    GenServer.call(via_tuple(name), {:execute, fun})
  end

  def get_state(name) do
    GenServer.call(via_tuple(name), :get_state)
  end

  def reset(name) do
    GenServer.call(via_tuple(name), :reset)
  end

  @impl true
  def init(opts) do
    threshold_input = Keyword.get(opts, :threshold, 0.5)
    threshold_pct = trunc(threshold_input * 100)

    state = %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      state: :closed,
      window: Window.new(Keyword.get(opts, :window_size, 60)),
      threshold_pct: threshold_pct,
      min_volume: Keyword.get(opts, :min_volume, @default_min_volume),
      reset_timeout: Keyword.get(opts, :reset_timeout, @default_reset_timeout),
      last_state_change: System.monotonic_time(:millisecond),
      half_open_probes: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    state = maybe_transition_half_open(state)
    {:reply, state.state, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_state = %{
      state
      | state: :closed,
        window: Window.new(state.window.size),
        last_state_change: System.monotonic_time(:millisecond),
        half_open_probes: 0
    }
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:execute, fun}, _from, state) do
    state = maybe_transition_half_open(state)

    case state.state do
      :open ->
        {:reply, {:error, :circuit_open}, state}

      :half_open ->
        handle_half_open_exec(fun, state)

      :closed ->
        handle_closed_exec(fun, state)
    end
  end

  defp handle_closed_exec(fun, state) do
    case execute_safely(fun) do
      {:ok, result} ->
        new_window = Window.record(state.window, :ok)
        {:reply, {:ok, result}, %{state | window: new_window}}

      {:error, reason} ->
        new_window = Window.record(state.window, :error)
        new_state = %{state | window: new_window}
        new_state = maybe_trip_circuit(new_state)
        {:reply, {:error, reason}, new_state}
    end
  end

  defp handle_half_open_exec(fun, state) do
    case execute_safely(fun) do
      {:ok, result} ->
        new_state = %{
          state
          | state: :closed,
            window: Window.new(state.window.size),
            last_state_change: System.monotonic_time(:millisecond),
            half_open_probes: 0
        }
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        new_state = %{
          state
          | state: :open,
            last_state_change: System.monotonic_time(:millisecond),
            half_open_probes: 0
        }
        {:reply, {:error, reason}, new_state}
    end
  end

  defp maybe_transition_half_open(%{state: :open} = state) do
    now = System.monotonic_time(:millisecond)
    if now - state.last_state_change >= state.reset_timeout do
      %{state | state: :half_open, last_state_change: now}
    else
      state
    end
  end

  defp maybe_transition_half_open(state), do: state

  defp maybe_trip_circuit(state) do
    {successes, failures} = Window.stats(state.window)
    total = successes + failures

    if total >= state.min_volume and (failures * 100) >= (total * state.threshold_pct) do
      %{state | state: :open, last_state_change: System.monotonic_time(:millisecond)}
    else
      state
    end
  end

  defp execute_safely(fun) do
    try do
      case fun.() do
        {:error, reason} -> {:error, reason}
        other -> {:ok, other}
      end
    rescue
      e -> {:error, e}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  defp via_tuple(name) do
    {:via, Registry, {Deflector.Registry, {__MODULE__, name}}}
  end
end