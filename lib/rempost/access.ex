defmodule Rempost.Access do
  @moduledoc """
  Verification boundary for revealing sensitive self-service order data.
  """

  @default_portal_answer "rempost"

  def portal_verified?(answer) when is_binary(answer) do
    secure_compare(normalize(answer), normalize(portal_answer()))
  end

  def portal_verified?(_answer), do: false

  defp portal_answer do
    Application.get_env(:rempost, :portal_access_answer) ||
      System.get_env("REMPOST_PORTAL_ACCESS_ANSWER") ||
      @default_portal_answer
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
