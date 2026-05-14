defmodule RempostWeb.Plugs.AdminAuth do
  @moduledoc """
  Basic admin authentication for operational surfaces.
  """

  import Plug.Conn
  import Plug.BasicAuth

  def init(opts), do: opts

  def call(conn, _opts) do
    with username when is_binary(username) and username != "" <- admin_username(),
         password when is_binary(password) and password != "" <- admin_password() do
      basic_auth(conn, username: username, password: password, realm: "Rempost Admin")
    else
      _ ->
        conn
        |> send_resp(:service_unavailable, "admin auth is not configured")
        |> halt()
    end
  end

  defp admin_username do
    Application.get_env(:rempost, :admin_username) ||
      System.get_env("REMPOST_ADMIN_USER") ||
      System.get_env("OBAN_DASHBOARD_USER")
  end

  defp admin_password do
    Application.get_env(:rempost, :admin_password) ||
      System.get_env("REMPOST_ADMIN_PASSWORD") ||
      System.get_env("OBAN_DASHBOARD_PASS")
  end
end
