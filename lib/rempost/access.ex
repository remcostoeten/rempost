defmodule Rempost.Access do
  @moduledoc """
  Verification boundary for revealing sensitive self-service order data.
  """

  @portal_session_key "portal_verified_until"
  @default_portal_ttl_seconds 60 * 60

  def portal_session_key, do: @portal_session_key

  def portal_verified?(answer) when is_binary(answer) do
    case portal_answer() do
      answer_config when is_binary(answer_config) ->
        secure_compare(normalize(answer), normalize(answer_config))

      _ ->
        false
    end
  end

  def portal_verified?(_answer), do: false

  def portal_session_verified?(session, now \\ DateTime.utc_now()) when is_map(session) do
    case Map.get(session, @portal_session_key) do
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

  def portal_verified_until(now \\ DateTime.utc_now()) do
    DateTime.add(now, portal_verification_ttl_seconds(), :second)
  end

  def portal_verification_ttl_seconds do
    Application.get_env(:rempost, :portal_verification_ttl_seconds) ||
      env_integer("REMPOST_PORTAL_VERIFICATION_TTL_SECONDS") ||
      @default_portal_ttl_seconds
  end

  defp portal_answer do
    Application.get_env(:rempost, :portal_access_answer) ||
      System.get_env("REMPOST_PORTAL_ACCESS_ANSWER")
  end

  defp env_integer(name) do
    case System.get_env(name) do
      nil -> nil
      value -> parse_positive_integer(value)
    end
  end

  defp parse_positive_integer(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _ -> nil
    end
  end

  defp normalize(value), do: value |> String.trim() |> String.downcase()

  defp secure_compare("", _expected), do: false
  defp secure_compare(_actual, ""), do: false

  defp secure_compare(actual, expected) do
    Plug.Crypto.secure_compare(actual, expected)
  rescue
    ArgumentError -> false
  end
end
