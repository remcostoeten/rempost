import Config

config :rempost,
  ecto_repos: [Rempost.Repo],
  generators: [timestamp_type: :utc_datetime]

config :rempost, :workspace_id, 1
config :rempost, :inbound_token, "324b10a95e4a7ed7fcf82ca30b4986ee40200cb36b4dab70f0fb3fc9679bd1c2"

config :rempost, Rempost.Repo, migration_timestamps: [type: :utc_datetime]

config :rempost, Oban,
  repo: Rempost.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", Rempost.Workers.RawEmailRetentionWorker,
        args: %{"retention_days" => 30, "workspace_id" => 1}}
     ]}
  ],
  queues: [emails: 20, parsing: 20, default: 10]

config :rempost, RempostWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: RempostWeb.ErrorHTML, json: RempostWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Rempost.PubSub,
  live_view: [signing_salt: "rempostsalt"]

config :esbuild,
  version: "0.20.2",
  rempost: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__)
  ]

config :tailwind,
  version: "3.4.3",
  rempost: [
    args: ~w(--input=assets/css/app.css --output=priv/static/assets/app.css),
    cd: Path.expand("..", __DIR__)
  ]

config :swoosh, :api_client, false

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
