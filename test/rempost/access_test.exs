defmodule Rempost.AccessTest do
  use ExUnit.Case

  alias Rempost.Access

  setup do
    previous_master = Application.get_env(:rempost, :portal_master_password)

    on_exit(fn ->
      restore_env(:portal_master_password, previous_master)
    end)

    :ok
  end

  test "verifies configured portal master password case-insensitively" do
    Application.put_env(:rempost, :portal_master_password, "Master Key")

    assert Access.portal_master_verified?(" master key ")
  end

  test "fails closed when master password is not configured" do
    Application.delete_env(:rempost, :portal_master_password)

    refute Access.portal_master_verified?("rempost")
    refute Access.portal_master_verified?("")
  end

  test "portal master session verification accepts the master session key" do
    now = ~U[2026-05-14 10:00:00Z]

    assert Access.portal_master_session_verified?(
             %{
               Access.portal_master_session_key() =>
                 DateTime.to_unix(DateTime.add(now, 60, :second))
             },
             now
           )
  end

  test "portal master session verification rejects expired timestamp" do
    now = ~U[2026-05-14 10:00:00Z]

    refute Access.portal_master_session_verified?(
             %{
               Access.portal_master_session_key() =>
                 DateTime.to_unix(DateTime.add(now, -1, :second))
             },
             now
           )
  end

  defp restore_env(key, nil), do: Application.delete_env(:rempost, key)
  defp restore_env(key, value), do: Application.put_env(:rempost, key, value)
end
