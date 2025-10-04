defmodule Deflector.CircuitBreaker.Window do
  @moduledoc """
  Circular sliding window buffer for tracking request execution results.
  """

  defstruct size: 60, buckets: [], current_bucket: 0

  @type t :: %__MODULE__{
          size: pos_integer(),
          buckets: list({pos_integer(), non_neg_integer(), non_neg_integer()}),
          current_bucket: pos_integer()
        }

  def new(size \\ 60) when is_integer(size) and size > 0 do
    %__MODULE__{size: size, buckets: [], current_bucket: current_second()}
  end

  def record(%__MODULE__{} = window, result) do
    now = current_second()
    window = prune(window, now)
    update_bucket(window, now, result)
  end

  def stats(%__MODULE__{} = window) do
    now = current_second()
    window = prune(window, now)
    
    Enum.reduce(window.buckets, {0, 0}, fn {_sec, s, f}, {acc_s, acc_f} ->
      {acc_s + s, acc_f + f}
    end)
  end

  defp prune(%__MODULE__{size: size, buckets: buckets} = window, now) do
    min_sec = now - size
    valid_buckets = Enum.filter(buckets, fn {sec, _, _} -> sec > min_sec end)
    %{window | buckets: valid_buckets, current_bucket: now}
  end

  defp update_bucket(%__MODULE__{buckets: buckets} = window, now, result) do
    case buckets do
      [{^now, s, f} | rest] ->
        updated = if result == :ok, do: {now, s + 1, f}, else: {now, s, f + 1}
        %{window | buckets: [updated | rest]}

      _ ->
        new_entry = if result == :ok, do: {now, 1, 0}, else: {now, 0, 1}
        %{window | buckets: [new_entry | buckets]}
    end
  end

  defp current_second do
    System.monotonic_time(:second)
  end
end