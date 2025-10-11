defmodule Deflector.Bulkhead.CallerMonitorTest do
  use ExUnit.Case, async: false
  alias Deflector.Bulkhead

  test "cleans up concurrency slot if caller process crashes" do
    name = :monitor_test_bulkhead
    {:ok, _} = Bulkhead.start_link(name: name, max_concurrent: 1, max_queue: 5)

    caller =
      spawn(fn ->
        Bulkhead.execute(name, fn ->
          Process.sleep(500)
          :done
        end)
      end)

    Process.sleep(20)
    Process.exit(caller, :kill)
    Process.sleep(50)

    # Next caller must be able to acquire slot immediately
    assert {:ok, :acquired} = Bulkhead.execute(name, fn -> :acquired end)
  end
end