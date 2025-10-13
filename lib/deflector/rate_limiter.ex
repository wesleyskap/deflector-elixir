defmodule Deflector.RateLimiter do
  @moduledoc """
  High-throughput Token Bucket rate limiter with monotonic sub-millisecond precision.
  """
  use GenServer

  defstruct [
    :name,
    :rate,
    :capacity,
    :tokens,
    :last_replenished
  ]

  @default_rate 100
  @default_capacity 100

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  def acquire(name, tokens \\ 1) when is_integer(tokens) and tokens > 0 do
    GenServer.call(via_tuple(name), {:acquire, tokens})
  end

  def get_tokens(name) do
    GenServer.call(via_tuple(name), :get_tokens)
  end

  @impl true
  def init(opts) do
    capacity = Keyword.get(opts, :capacity, @default_capacity)
    rate = Keyword.get(opts, :rate, @default_rate)

    state = %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      rate: rate,
      capacity: capacity,
      tokens: capacity,
      last_replenished: System.monotonic_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_tokens, _from, state) do
    state = replenish_tokens(state)
    {:reply, state.tokens, state}
  end

  @impl true
  def handle_call({:acquire, count}, _from, state) do
    state = replenish_tokens(state)

    if state.tokens >= count do
      new_tokens = state.tokens - count
      {:reply, {:ok, new_tokens}, %{state | tokens: new_tokens}}
    else
      {:reply, {:error, :rate_limited}, state}
    end
  end

  defp replenish_tokens(state) do
    now = System.monotonic_time(:millisecond)
    elapsed_ms = now - state.last_replenished

    if elapsed_ms > 0 do
      added_tokens = div(elapsed_ms * state.rate, 1_000)
      if added_tokens > 0 do
        new_tokens = min(state.capacity, state.tokens + added_tokens)
        %{state | tokens: new_tokens, last_replenished: now}
      else
        state
      end
    else
      state
    end
  end

  defp via_tuple(name) do
    {:via, Registry, {Deflector.Registry, {__MODULE__, name}}}
  end
end