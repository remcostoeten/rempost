defmodule Rempost.Shipments.Shipment do
  use Ecto.Schema
  import Ecto.Changeset
  schema "shipments" do
    field :carrier, :string
    field :tracking_number, :string
    field :status, Ecto.Enum, values: [:ordered, :shipped, :in_transit, :delivered, :failed], default: :ordered
    field :estimated_delivery_at, :utc_datetime
    field :last_event_at, :utc_datetime
    belongs_to :workspace, Rempost.Workspaces.Workspace
    belongs_to :order, Rempost.Orders.Order
    has_many :tracking_events, Rempost.Tracking.TrackingEvent
    timestamps(type: :utc_datetime)
  end
  def changeset(shipment, attrs), do: shipment |> cast(attrs, [:workspace_id,:order_id,:carrier,:tracking_number,:status,:estimated_delivery_at,:last_event_at]) |> validate_required([:workspace_id,:tracking_number,:status]) |> unique_constraint([:workspace_id,:tracking_number])
end
