defmodule Rempost.Repo.Migrations.RemoveWorkspaceScopeFromOperationalTables do
  use Ecto.Migration

  def up do
    drop_if_exists index(:orders, [:workspace_id, :order_number])
    drop_if_exists index(:shipments, [:workspace_id, :tracking_number])
    drop_if_exists index(:shipments, [:workspace_id, :status])

    execute "ALTER TABLE tracking_events DROP COLUMN IF EXISTS workspace_id"
    execute "ALTER TABLE shipments DROP COLUMN IF EXISTS workspace_id"
    execute "ALTER TABLE orders DROP COLUMN IF EXISTS workspace_id"

    create_if_not_exists unique_index(:orders, [:order_number])
    create_if_not_exists unique_index(:shipments, [:tracking_number])
    create_if_not_exists index(:shipments, [:status])
  end

  def down do
    drop_if_exists index(:orders, [:order_number])
    drop_if_exists index(:shipments, [:tracking_number])
    drop_if_exists index(:shipments, [:status])

    alter table(:orders) do
      add :workspace_id, :bigint, null: false
    end

    alter table(:shipments) do
      add :workspace_id, :bigint, null: false
    end

    alter table(:tracking_events) do
      add :workspace_id, :bigint, null: false
    end

    create_if_not_exists unique_index(:orders, [:workspace_id, :order_number])
    create_if_not_exists unique_index(:shipments, [:workspace_id, :tracking_number])
    create_if_not_exists index(:shipments, [:workspace_id, :status])
  end
end
