import Config

if config_env() == :prod do
  database_url = System.fetch_env!("DATABASE_URL")

  config :rempost,
    inbound_token: System.fetch_env!("REMPOST_INBOUND_TOKEN"),
    admin_username: System.fetch_env!("REMPOST_ADMIN_USER"),
    admin_password: System.fetch_env!("REMPOST_ADMIN_PASSWORD"),
    portal_access_answer: System.get_env("REMPOST_PORTAL_ACCESS_ANSWER")

  config :rempost, Rempost.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
