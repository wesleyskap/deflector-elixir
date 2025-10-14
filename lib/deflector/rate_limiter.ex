defmodule Deflector.RateLimiter do
  @moduledoc """
  High-throughput Token Bucket rate limiter with microsecond monotonic clock precision.
  """
  use GenServer

  defstruct [
    :name,
    :rate,
    :capacity,
    :tokens_micro,
    :last_replenished_micro
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
      tokens_micro: capacity * 1_000_000,
      last_replenished_micro: System.monotonic_time(:microsecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_tokens, _from, state) do
    state = replenish_tokens(state)
    {:reply, div(state.tokens_micro, 1_000_000), state}
  end

  @impl true
  def handle_call({:acquire, count}, _from, state) do
    state = replenish_tokens(state)
    needed_micro = count * 1_000_000

    if state.tokens_micro >= needed_micro do
      new_tokens_micro = state.tokens_micro - needed_micro
      remaining = div(new_tokens_micro, 1_000_000)
      {:reply, {:ok, remaining}, %{state | tokens_micro: new_tokens_micro}}
    else
      {:reply, {:error, :rate_limited}, state}
    end
  end

  defp replenish_tokens(state) do
    now_micro = System.monotonic_time(:microsecond)
    elapsed_micro = now_micro - state.last_replenished_micro

    if elapsed_micro > 0 do
      added_micro = elapsed_micro * state.rate
      max_capacity_micro = state.capacity * 1_000_000
      new_tokens_micro = min(max_capacity_micro, state.tokens_micro + added_micro)
      %{state | tokens_micro: new_tokens_micro, last_replenished_micro: now_micro}
    else
      state
    end
  end

  defp via_tuple(name) do
    {:via, Registry, {Deflector.Registry, {__MODULE__, name}}}
  end
end