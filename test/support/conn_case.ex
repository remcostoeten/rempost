defmodule RempostWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint RempostWeb.Endpoint

      use RempostWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import RempostWeb.ConnCase
    end
  end

  setup tags do
    Rempost.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def basic_auth(conn, username, password) do
    encoded = Base.encode64("#{username}:#{password}")
    Plug.Conn.put_req_header(conn, "authorization", "Basic #{encoded}")
  end
end
