defmodule RempostTest do
  use ExUnit.Case
  doctest Rempost

  test "greets the world" do
    assert Rempost.hello() == :world
  end
end
