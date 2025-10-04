defmodule Deflector.CircuitBreaker.WindowTest do
  use ExUnit.Case, async: true
  alias Deflector.CircuitBreaker.Window

  test "records successes and failures correctly" do
    win = Window.new(10)
    win = Window.record(win, :ok)
    win = Window.record(win, :ok)
    win = Window.record(win, :error)

    {successes, failures} = Window.stats(win)
    assert successes == 2
    assert failures == 1
  end

  test "calculates aggregate ratios over active buckets" do
    win = Window.new(5)
    win = Enum.reduce(1..5, win, fn _, acc -> Window.record(acc, :ok) end)
    win = Enum.reduce(1..5, win, fn _, acc -> Window.record(acc, :error) end)

    {successes, failures} = Window.stats(win)
    assert successes == 5
    assert failures == 5
  end
end