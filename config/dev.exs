import Config

config :rempost,
  inbound_token: System.get_env("REMPOST_INBOUND_TOKEN") || "dev-inbound-token",
  admin_username: System.get_env("REMPOST_ADMIN_USER") || "admin",
  admin_password: System.get_env("REMPOST_ADMIN_PASSWORD") || "admin",
  portal_access_answer: System.get_env("REMPOST_PORTAL_ACCESS_ANSWER") || "dev-answer",
  portal_master_password: System.get_env("REMPOST_PORTAL_MASTER_PASSWORD") || "dev-master"

config :rempost, Rempost.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rempost_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :rempost, RempostWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "rempost_dev_secret_key_base_for_local_live_view_sessions_64_bytes_minimum",
  watchers: []

config :rempost, RempostWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/rempost_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
