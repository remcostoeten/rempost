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
