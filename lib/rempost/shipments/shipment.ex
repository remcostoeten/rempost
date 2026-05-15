defmodule Rempost.Shipments.Shipment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shipments" do
    field :carrier, :string
    field :tracking_number, :string
    field :tracking_url, :string

    field :status, Ecto.Enum,
      values: [:ordered, :shipped, :in_transit, :delivered, :failed],
      default: :ordered

    field :estimated_delivery_at, :utc_datetime
    field :estimated_delivery_text, :string
    field :delivered_at_text, :string
    field :signature_required, :boolean, default: false
    field :latest_email_subject, :string
    field :last_event_at, :utc_datetime
    belongs_to :order, Rempost.Orders.Order
    has_many :tracking_events, Rempost.Tracking.TrackingEvent
    timestamps(type: :utc_datetime)
  end

  def changeset(shipment, attrs),
    do:
      shipment
      |> cast(attrs, [
        :order_id,
        :carrier,
        :tracking_number,
        :tracking_url,
        :status,
        :estimated_delivery_at,
        :estimated_delivery_text,
        :delivered_at_text,
        :signature_required,
        :latest_email_subject,
        :last_event_at
      ])
      |> validate_required([:tracking_number, :status])
      |> unique_constraint(:tracking_number)
end
