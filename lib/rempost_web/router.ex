defmodule RempostWeb.Router do
  use RempostWeb, :router
  # import Oban.Web.Router

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

  scope "/", RempostWeb do
    pipe_through :browser
    live "/", DashboardLive.Index, :index
    live "/shipments", ShipmentLive.Index, :index
    live "/shipments/:id", ShipmentLive.Show, :show
    live "/emails/:id", EmailDebugLive.Show, :show
  end

  scope "/api", RempostWeb do
    pipe_through :api
    post "/inbound/email", InboundEmailController, :create
  end

  # scope "/oban" do
  #   pipe_through :browser
  #   oban_dashboard("/")
  # end
end
