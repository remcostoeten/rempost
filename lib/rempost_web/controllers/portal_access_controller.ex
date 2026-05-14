defmodule RempostWeb.PortalAccessController do
  use RempostWeb, :controller

  def create(conn, %{"answer" => answer} = params),
    do: verify(conn, params, answer, params["scope"])

  def create(conn, params) do
    conn
    |> put_flash(:error, "That answer didn't match. Try again.")
    |> redirect(to: safe_return_to(params["return_to"]))
  end

  defp verify(conn, params, answer, "master") do
    if Rempost.Access.portal_master_verified?(answer) do
      verified_until = Rempost.Access.portal_verified_until() |> DateTime.to_unix()

      conn
      |> put_session(Rempost.Access.portal_master_session_key(), verified_until)
      |> redirect(to: safe_return_to(params["return_to"]))
    else
      reject(conn, params)
    end
  end

  defp verify(conn, params, answer, _scope) do
    if Rempost.Access.portal_verified?(answer) do
      verified_until = Rempost.Access.portal_verified_until() |> DateTime.to_unix()

      conn
      |> put_session(Rempost.Access.portal_session_key(), verified_until)
      |> redirect(to: safe_return_to(params["return_to"]))
    else
      reject(conn, params)
    end
  end

  defp reject(conn, params) do
    conn
    |> put_flash(:error, "That answer didn't match. Try again.")
    |> redirect(to: safe_return_to(params["return_to"]))
  end

  defp safe_return_to(path) when is_binary(path) do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
      path
    else
      "/portal"
    end
  end

  defp safe_return_to(_path), do: "/portal"
end
