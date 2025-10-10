defmodule Deflector.Bulkhead do
  @moduledoc """
  Concurrency isolation bulkhead with bounded caller queue and caller monitoring.
  """
  use GenServer

  defstruct [
    :name,
    :max_concurrent,
    :max_queue,
    :running,
    :monitors,
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
      monitors: %{},
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
  def handle_call({:execute, fun, timeout}, {caller_pid, _} = from, state) do
    ref = Process.monitor(caller_pid)

    if MapSet.size(state.running) < state.max_concurrent do
      spawn_worker(fun, from, self())
      new_monitors = Map.put(state.monitors, from, ref)
      {:noreply, %{state | running: MapSet.put(state.running, from), monitors: new_monitors}}
    else
      if :queue.len(state.queue) < state.max_queue do
        queued = {from, fun, System.monotonic_time(:millisecond), timeout, ref}
        {:noreply, %{state | queue: :queue.in(queued, state.queue)}}
      else
        Process.demonitor(ref, [:flush])
        {:reply, {:error, :bulkhead_exhausted}, state}
      end
    end
  end

  @impl true
  def handle_info({:worker_done, from, result}, state) do
    demonitor_caller(from, state.monitors)
    GenServer.reply(from, result)
    new_running = MapSet.delete(state.running, from)
    new_monitors = Map.delete(state.monitors, from)
    state = %{state | running: new_running, monitors: new_monitors}
    {:noreply, dispatch_next(state)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, caller_pid, _reason}, state) do
    handle_caller_down(ref, caller_pid, state)
  end

  defp handle_caller_down(ref, _caller_pid, state) do
    case Enum.find(state.monitors, fn {_from, m_ref} -> m_ref == ref end) do
      {from, ^ref} ->
        new_running = MapSet.delete(state.running, from)
        new_monitors = Map.delete(state.monitors, from)
        state = %{state | running: new_running, monitors: new_monitors}
        {:noreply, dispatch_next(state)}

      nil ->
        filtered_queue =
          :queue.filter(
            fn {_from, _fun, _q_at, _to, m_ref} ->
              if m_ref == ref do
                Process.demonitor(ref, [:flush])
                false
              else
                true
              end
            end,
            state.queue
          )

        {:noreply, %{state | queue: filtered_queue}}
    end
  end

  defp dispatch_next(state) do
    case :queue.out(state.queue) do
      {{:value, {from, fun, queued_at, timeout, ref}}, remaining_queue} ->
        now = System.monotonic_time(:millisecond)
        if now - queued_at > timeout do
          Process.demonitor(ref, [:flush])
          GenServer.reply(from, {:error, :bulkhead_timeout})
          dispatch_next(%{state | queue: remaining_queue})
        else
          spawn_worker(fun, from, self())
          new_monitors = Map.put(state.monitors, from, ref)
          %{state | queue: remaining_queue, running: MapSet.put(state.running, from), monitors: new_monitors}
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

  defp demonitor_caller(from, monitors) do
    case Map.get(monitors, from) do
      nil -> :ok
      ref -> Process.demonitor(ref, [:flush])
    end
  end

  defp via_tuple(name) do
    {:via, Registry, {Deflector.Registry, {__MODULE__, name}}}
  end
end