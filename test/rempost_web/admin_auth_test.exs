defmodule RempostWeb.AdminAuthTest do
  use RempostWeb.ConnCase

  setup do
    previous_user = Application.get_env(:rempost, :admin_username)
    previous_password = Application.get_env(:rempost, :admin_password)
    previous_portal_answer = Application.get_env(:rempost, :portal_access_answer)
    previous_portal_ttl = Application.get_env(:rempost, :portal_verification_ttl_seconds)

    Application.put_env(:rempost, :admin_username, "admin")
    Application.put_env(:rempost, :admin_password, "secret")

    on_exit(fn ->
      restore_env(:admin_username, previous_user)
      restore_env(:admin_password, previous_password)
      restore_env(:portal_access_answer, previous_portal_answer)
      restore_env(:portal_verification_ttl_seconds, previous_portal_ttl)
    end)

    :ok
  end

  test "protects dashboard route", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")

    assert conn.status == 401
  end

  test "protects email debug route", %{conn: conn} do
    conn = get(conn, ~p"/emails/1")

    assert conn.status == 401
  end

  test "protects oban dashboard route", %{conn: conn} do
    conn = get(conn, "/oban")

    assert conn.status == 401
  end

  test "keeps portal route public", %{conn: conn} do
    conn = get(conn, ~p"/portal")

    assert html_response(conn, 200) =~ "Dus, weer op zoek naar je pakketje?"
  end

  test "stores verified portal state in session", %{conn: conn} do
    Application.put_env(:rempost, :portal_access_answer, "secret")
    Application.put_env(:rempost, :portal_verification_ttl_seconds, 60)

    conn =
      conn
      |> init_test_session(%{})
      |> post(~p"/portal/verify", %{"answer" => "secret", "return_to" => "/portal"})

    assert redirected_to(conn) == "/portal"
    assert is_integer(get_session(conn, Rempost.Access.portal_session_key()))
  end

  test "protects inbound email search api", %{conn: conn} do
    conn = get(conn, ~p"/api/inbound/emails")

    assert conn.status == 401
  end

  test "allows inbound email search api with admin credentials", %{conn: conn} do
    conn =
      conn
      |> basic_auth("admin", "secret")
      |> get(~p"/api/inbound/emails")

    assert %{"emails" => [], "count" => 0} = json_response(conn, 200)
  end

  test "admin auth fails closed when credentials are missing", %{conn: conn} do
    Application.delete_env(:rempost, :admin_username)
    Application.delete_env(:rempost, :admin_password)

    conn = get(conn, ~p"/dashboard")

    assert conn.status == 503
  end

  defp restore_env(key, nil), do: Application.delete_env(:rempost, key)
  defp restore_env(key, value), do: Application.put_env(:rempost, key, value)
end
