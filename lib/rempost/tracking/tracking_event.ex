defmodule Rempost.Tracking.TrackingEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tracking_events" do
    field :status, :string
    field :location, :string
    field :occurred_at, :utc_datetime
    field :metadata, :map, default: %{}
    belongs_to :workspace, Rempost.Workspaces.Workspace
    belongs_to :shipment, Rempost.Shipments.Shipment
    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs),
    do:
      event
      |> cast(attrs, [:workspace_id, :shipment_id, :status, :location, :occurred_at, :metadata])
      |> validate_required([:workspace_id, :shipment_id, :status, :occurred_at])
end
