import Config

config :rempost,
  ecto_repos: [Rempost.Repo],
  generators: [timestamp_type: :utc_datetime]

config :rempost, Rempost.Repo,
  migration_timestamps: [type: :utc_datetime]

config :rempost, Oban,
  repo: Rempost.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [emails: 20, parsing: 20, default: 10]

config :rempost, RempostWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: RempostWeb.ErrorHTML, json: RempostWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Rempost.PubSub,
  live_view: [signing_salt: "rempostsalt"]

config :esbuild,
  version: "0.20.2",
  rempost: [args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets), cd: Path.expand("../assets", __DIR__)]

config :tailwind,
  version: "3.4.3",
  rempost: [args: ~w(--input=assets/css/app.css --output=priv/static/assets/app.css), cd: Path.expand("..", __DIR__)]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
