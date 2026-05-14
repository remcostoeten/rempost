defmodule Rempost.Repo.Migrations.AddTrackingUrlToShipments do
  use Ecto.Migration

  def change do
    alter table(:shipments) do
      add :tracking_url, :text
    end
  end
end
