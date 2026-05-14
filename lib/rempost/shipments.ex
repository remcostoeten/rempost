defmodule Rempost.Shipments do
  import Ecto.Query
  alias Rempost.{Repo, Shipments.Shipment, Tracking.TrackingEvent}

  def topic(workspace_id), do: "workspace:#{workspace_id}:shipments"
  def subscribe(workspace_id), do: Phoenix.PubSub.subscribe(Rempost.PubSub, topic(workspace_id))

  def broadcast(workspace_id, event, payload),
    do: Phoenix.PubSub.broadcast(Rempost.PubSub, topic(workspace_id), {event, payload})

  def list_shipments(workspace_id) do
    Shipment
    |> where([s], s.workspace_id == ^workspace_id)
    |> order_by([s], desc: s.updated_at)
    |> preload(:order)
    |> Repo.all()
  end

  def stats(workspace_id) do
    base = Shipment |> where([s], s.workspace_id == ^workspace_id)

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

  def get_shipment!(workspace_id, id),
    do:
      Shipment
      |> where([s], s.workspace_id == ^workspace_id and s.id == ^id)
      |> preload([
        :order,
        tracking_events: ^from(t in TrackingEvent, order_by: [asc: t.occurred_at])
      ])
      |> Repo.one!()
end
