defmodule Rempost.AccessTest do
  use ExUnit.Case

  alias Rempost.Access

  setup do
    previous_answer = Application.get_env(:rempost, :portal_access_answer)
    previous_ttl = Application.get_env(:rempost, :portal_verification_ttl_seconds)

    on_exit(fn ->
      restore_env(:portal_access_answer, previous_answer)
      restore_env(:portal_verification_ttl_seconds, previous_ttl)
    end)

    :ok
  end

  test "verifies configured portal answer case-insensitively" do
    Application.put_env(:rempost, :portal_access_answer, "Shipment Secret")

    assert Access.portal_verified?(" shipment secret ")
  end

  test "fails closed when portal answer is not configured" do
    Application.delete_env(:rempost, :portal_access_answer)

    refute Access.portal_verified?("rempost")
    refute Access.portal_verified?("")
  end

  test "portal session verification expires by TTL timestamp" do
    now = ~U[2026-05-14 10:00:00Z]

    assert Access.portal_session_verified?(
             %{
               Access.portal_session_key() => DateTime.to_unix(DateTime.add(now, 60, :second))
             },
             now
           )

    refute Access.portal_session_verified?(
             %{
               Access.portal_session_key() => DateTime.to_unix(DateTime.add(now, -1, :second))
             },
             now
           )
  end

  test "portal verified until uses configured TTL" do
    Application.put_env(:rempost, :portal_verification_ttl_seconds, 120)
    now = ~U[2026-05-14 10:00:00Z]

    assert Access.portal_verified_until(now) == ~U[2026-05-14 10:02:00Z]
  end

  defp restore_env(key, nil), do: Application.delete_env(:rempost, key)
  defp restore_env(key, value), do: Application.put_env(:rempost, key, value)
end
