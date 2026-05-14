import Config

config :rempost,
       :inbound_token,
       System.get_env("REMPOST_INBOUND_TOKEN") ||
         "324b10a95e4a7ed7fcf82ca30b4986ee40200cb36b4dab70f0fb3fc9679bd1c2"

if config_env() == :prod do
  database_url = System.fetch_env!("DATABASE_URL")

  config :rempost, Rempost.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
