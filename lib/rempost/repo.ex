defmodule Rempost.Repo do
  use Ecto.Repo,
    otp_app: :rempost,
    adapter: Ecto.Adapters.Postgres
end
