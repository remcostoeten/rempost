defmodule Rempost.Repo.Migrations.CreateOrdersShipmentsTracking do
  use Ecto.Migration
  def change do
    create table(:orders) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :inbound_email_id, references(:inbound_emails, on_delete: :nilify_all)
      add :order_number, :string, null: false
      add :merchant_name, :string
      add :status, :string, null: false, default: "placed"
      add :ordered_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end
    create unique_index(:orders, [:workspace_id, :order_number])

    create table(:shipments) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :carrier, :string
      add :tracking_number, :string, null: false
      add :status, :string, null: false, default: "ordered"
      add :estimated_delivery_at, :utc_datetime
      add :last_event_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end
    create unique_index(:shipments, [:workspace_id, :tracking_number])
    create index(:shipments, [:workspace_id, :status])

    create table(:tracking_events) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :shipment_id, references(:shipments, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :location, :string
      add :occurred_at, :utc_datetime, null: false
      add :metadata, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end
    create index(:tracking_events, [:shipment_id, :occurred_at])
  end
end
