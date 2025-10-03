defmodule Deflector.ApplicationTest do
  use ExUnit.Case, async: true

  test "verifies root supervision tree components are active" do
    assert Process.whereis(Deflector.Registry) != nil
    assert Process.whereis(Deflector.DynamicSupervisor) != nil
  end
end