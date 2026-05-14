defmodule Rempost.Shipments do
  import Ecto.Query
  alias Rempost.{Repo, Shipments.Shipment, Tracking.TrackingEvent}

  def topic, do: "shipments"
  def subscribe, do: Phoenix.PubSub.subscribe(Rempost.PubSub, topic())

  def broadcast(event, payload),
    do: Phoenix.PubSub.broadcast(Rempost.PubSub, topic(), {event, payload})

  def list_shipments do
    Shipment
    |> order_by([s], desc: s.updated_at)
    |> preload(:order)
    |> Repo.all()
  end

  def stats do
    base = Shipment

    %{
      active_count: Repo.aggregate(where(base, [s], s.status != :delivered), :count, :id),
      delayed_count:
        Repo.aggregate(
          where(
            base,
            [s],
            s.status in [:ordered, :shipped, :in_transit] and not is_nil(s.estimated_delivery_at) and
              s.estimated_delivery_at < ^DateTime.utc_now()
          ),
          :count,
          :id
        ),
      delivered_count: Repo.aggregate(where(base, [s], s.status == :delivered), :count, :id)
    }
  end

  def get_shipment!(id),
    do:
      Shipment
      |> where([s], s.id == ^id)
      |> preload([
        :order,
        tracking_events: ^from(t in TrackingEvent, order_by: [asc: t.occurred_at])
      ])
      |> Repo.one!()
end
