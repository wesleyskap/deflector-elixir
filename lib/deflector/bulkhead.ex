defmodule Deflector.Bulkhead do
  @moduledoc """
  Concurrency isolation bulkhead with bounded caller queue.
  """
  use GenServer

  defstruct [
    :name,
    :max_concurrent,
    :max_queue,
    :running,
    :queue
  ]

  @default_max_concurrent 10
  @default_max_queue 50

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  def execute(name, fun, timeout \\ 5_000) when is_function(fun, 0) do
    GenServer.call(via_tuple(name), {:execute, fun, timeout}, timeout + 1_000)
  end

  def get_metrics(name) do
    GenServer.call(via_tuple(name), :get_metrics)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      max_concurrent: Keyword.get(opts, :max_concurrent, @default_max_concurrent),
      max_queue: Keyword.get(opts, :max_queue, @default_max_queue),
      running: MapSet.new(),
      queue: :queue.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      running_count: MapSet.size(state.running),
      queue_count: :queue.len(state.queue),
      max_concurrent: state.max_concurrent,
      max_queue: state.max_queue
    }
    {:reply, metrics, state}
  end

  @impl true
  def handle_call({:execute, fun, timeout}, from, state) do
    if MapSet.size(state.running) < state.max_concurrent do
      spawn_worker(fun, from, self())
      {:noreply, %{state | running: MapSet.put(state.running, from)}}
    else
      if :queue.len(state.queue) < state.max_queue do
        queued = {from, fun, System.monotonic_time(:millisecond), timeout}
        {:noreply, %{state | queue: :queue.in(queued, state.queue)}}
      else
        {:reply, {:error, :bulkhead_exhausted}, state}
      end
    end
  end

  @impl true
  def handle_info({:worker_done, from, result}, state) do
    GenServer.reply(from, result)
    new_running = MapSet.delete(state.running, from)
    state = %{state | running: new_running}
    {:noreply, dispatch_next(state)}
  end

  defp dispatch_next(state) do
    case :queue.out(state.queue) do
      {{:value, {from, fun, queued_at, timeout}}, remaining_queue} ->
        now = System.monotonic_time(:millisecond)
        if now - queued_at > timeout do
          GenServer.reply(from, {:error, :bulkhead_timeout})
          dispatch_next(%{state | queue: remaining_queue})
        else
          spawn_worker(fun, from, self())
          %{state | queue: remaining_queue, running: MapSet.put(state.running, from)}
        end

      {:empty, _} ->
        state
    end
  end

  defp spawn_worker(fun, from, server_pid) do
    spawn(fn ->
      result =
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

      send(server_pid, {:worker_done, from, result})
    end)
  end

  defp via_tuple(name) do
    {:via, Registry, {Deflector.Registry, {__MODULE__, name}}}
  end
end