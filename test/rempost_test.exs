defmodule RempostTest do
  use ExUnit.Case

  test "application module loads" do
    assert Code.ensure_loaded?(Rempost.Application)
  end
end
