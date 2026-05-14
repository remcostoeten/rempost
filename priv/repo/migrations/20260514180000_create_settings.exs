defmodule Rempost.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :text, null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:settings, [:key])

    execute("""
    INSERT INTO settings (id, key, value, inserted_at, updated_at)
    VALUES (gen_random_uuid(), 'portal_master_password', '257wds4k', now(), now())
    """)
  end
end
