import Config
if config_env() == :prod do
  database_url = System.fetch_env!("DATABASE_URL")
  config :rempost, Rempost.Repo, url: database_url, pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
