defmodule RempostWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :rempost

  @session_options [store: :cookie, key: "_rempost_key", signing_salt: "session" ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static, at: "/", from: :rempost, gzip: false, only: RempostWeb.static_paths()
  if code_reloading?, do: plug Phoenix.LiveReloader

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Phoenix.json_library()
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug RempostWeb.Router
end
