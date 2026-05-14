defmodule Rempost.Access do
  @moduledoc """
  Verification boundary for master access to the self-service portal.
  """

  @portal_master_session_key "portal_master_verified_until"

  def portal_master_session_key, do: @portal_master_session_key

  def portal_master_verified?(answer) when is_binary(answer) do
    case portal_master_password() do
      password when is_binary(password) ->
        secure_compare(normalize(answer), normalize(password))

      _ ->
        false
    end
  end

  def portal_master_verified?(_answer), do: false

  # Stub — remove in Task 7 once ShipmentLive.Index no longer calls this.
  def portal_session_verified?(_session, _now \\ DateTime.utc_now()), do: false

  def portal_master_session_verified?(session, now \\ DateTime.utc_now())
      when is_map(session) do
    session_verified?(session, @portal_master_session_key, now)
  end

  defp portal_master_password do
    if Mix.env() == :test do
      configured_master_password() || stored_master_password()
    else
      stored_master_password() || configured_master_password()
    end
  end

  def stored_master_password, do: Rempost.Settings.get("portal_master_password")

  def configured_master_password do
    Application.get_env(:rempost, :portal_master_password) ||
      System.get_env("REMPOST_PORTAL_MASTER_PASSWORD")
  end

  def normalize(value), do: value |> String.trim() |> String.downcase()

  defp session_verified?(session, key, now) do
    case Map.get(session, key) do
      verified_until when is_integer(verified_until) ->
        DateTime.to_unix(now) < verified_until

      verified_until when is_binary(verified_until) ->
        case Integer.parse(verified_until) do
          {timestamp, ""} -> DateTime.to_unix(now) < timestamp
          _ -> false
        end

      _ ->
        false
    end
  end

  def secure_compare("", _expected), do: false
  def secure_compare(_actual, ""), do: false

  def secure_compare(actual, expected) do
    Plug.Crypto.secure_compare(actual, expected)
  rescue
    ArgumentError -> false
  end
end
