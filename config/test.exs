import Config

config :rempost,
  inbound_token: "test-inbound-token"

config :rempost, Rempost.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rempost_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :rempost, RempostWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "testsecret_testsecret_testsecret_testsecret_testsecret_testsecret_test",
  server: false

config :logger, level: :warning
config :rempost, Oban, testing: :inline, queues: false, plugins: false
