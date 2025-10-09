defmodule Deflector.BulkheadTest do
  use ExUnit.Case, async: false
  alias Deflector.Bulkhead

  setup do
    name = :test_bulkhead_1
    {:ok, pid} = Bulkhead.start_link(name: name, max_concurrent: 2, max_queue: 2)
    %{bulkhead: name, pid: pid}
  end

  test "executes tasks concurrently within capacity", %{bulkhead: bulkhead} do
    res = Bulkhead.execute(bulkhead, fn -> 100 end)
    assert {:ok, 100} == res
  end

  test "rejects tasks when queue limit is fully saturated", %{bulkhead: bulkhead} do
    # Spawn 2 blocking tasks to fill concurrent slots
    task1 = Task.async(fn -> Bulkhead.execute(bulkhead, fn -> Process.sleep(100); :t1 end) end)
    task2 = Task.async(fn -> Bulkhead.execute(bulkhead, fn -> Process.sleep(100); :t2 end) end)
    Process.sleep(10)

    # Queue up 2 tasks
    task3 = Task.async(fn -> Bulkhead.execute(bulkhead, fn -> :t3 end) end)
    task4 = Task.async(fn -> Bulkhead.execute(bulkhead, fn -> :t4 end) end)
    Process.sleep(10)

    # 5th task must fail fast with bulkhead_exhausted
    assert {:error, :bulkhead_exhausted} == Bulkhead.execute(bulkhead, fn -> :rejected end)

    Task.await(task1)
    Task.await(task2)
    Task.await(task3)
    Task.await(task4)
  end
end