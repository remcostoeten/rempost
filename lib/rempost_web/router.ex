defmodule RempostWeb.Router do
  use RempostWeb, :router
  import Oban.Web.Router
  import Plug.BasicAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RempostWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :oban_admin do
    plug :basic_auth,
      username: System.get_env("OBAN_DASHBOARD_USER") || "admin",
      password: System.get_env("OBAN_DASHBOARD_PASS") || "admin"
  end

  scope "/", RempostWeb do
    pipe_through :browser
    live "/", ShipmentLive.Index, :index
    live "/dashboard", DashboardLive.Index, :index
    live "/portal", ShipmentLive.Index, :index
    live "/shipments", ShipmentLive.Index, :index
    live "/shipments/:id", ShipmentLive.Show, :show
    live "/emails/:id", EmailDebugLive.Show, :show
  end

  scope "/api", RempostWeb do
    pipe_through :api
    post "/inbound/email", InboundEmailController, :create
    get "/inbound/emails", InboundEmailController, :index
  end

  scope "/oban" do
    pipe_through [:browser, :oban_admin]
    oban_dashboard("/")
  end
end
