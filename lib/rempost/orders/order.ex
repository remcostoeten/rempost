defmodule Rempost.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset
  schema "orders" do
    field :order_number, :string
    field :merchant_name, :string
    field :status, Ecto.Enum, values: [:placed, :processing, :fulfilled, :cancelled], default: :placed
    field :ordered_at, :utc_datetime
    belongs_to :workspace, Rempost.Workspaces.Workspace
    belongs_to :inbound_email, Rempost.Emails.InboundEmail
    has_many :shipments, Rempost.Shipments.Shipment
    timestamps(type: :utc_datetime)
  end
  def changeset(order, attrs), do: order |> cast(attrs, [:workspace_id,:inbound_email_id,:order_number,:merchant_name,:status,:ordered_at]) |> validate_required([:workspace_id,:order_number])
end
