defmodule Rempost.Parsing.Pipeline do
  alias Rempost.{Repo, Orders.Order, Shipments.Shipment, Tracking.TrackingEvent, Emails.InboundEmail, Shipments}

  def apply!(workspace_id, email, parsed) do
    Repo.transaction(fn ->
      order = upsert_order!(workspace_id, email, parsed)
      shipment = upsert_shipment!(workspace_id, order, parsed)
      create_tracking_event!(workspace_id, shipment, parsed)
      email |> InboundEmail.changeset(%{status: :parsed, parse_error: nil}) |> Repo.update!()
      Shipments.broadcast(workspace_id, :shipment_updated, shipment.id)
      shipment
    end)
  end

  defp upsert_order!(workspace_id, email, parsed) do
    attrs = %{workspace_id: workspace_id, inbound_email_id: email.id, order_number: parsed.order_number || "unknown-#{email.id}", merchant_name: email.from_email}
    %Order{} |> Order.changeset(attrs) |> Repo.insert!(on_conflict: [set: [merchant_name: attrs.merchant_name, updated_at: DateTime.utc_now()]], conflict_target: [:workspace_id, :order_number], returning: true)
  end

  defp upsert_shipment!(workspace_id, order, parsed) do
    attrs = %{workspace_id: workspace_id, order_id: order.id, carrier: parsed.carrier, tracking_number: parsed.tracking_number || "pending-#{order.id}", status: parsed.status, last_event_at: DateTime.utc_now()}
    %Shipment{} |> Shipment.changeset(attrs) |> Repo.insert!(on_conflict: [set: [status: attrs.status, carrier: attrs.carrier, last_event_at: attrs.last_event_at, updated_at: DateTime.utc_now()]], conflict_target: [:workspace_id, :tracking_number], returning: true)
  end

  defp create_tracking_event!(workspace_id, shipment, parsed) do
    %TrackingEvent{} |> TrackingEvent.changeset(%{workspace_id: workspace_id, shipment_id: shipment.id, status: Atom.to_string(parsed.status), occurred_at: DateTime.utc_now(), metadata: %{carrier: parsed.carrier}}) |> Repo.insert!()
  end
end
