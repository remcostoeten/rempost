defmodule Rempost.Parsing.Pipeline do
  import Ecto.Query

  alias Rempost.{
    Repo,
    Orders.Order,
    Shipments.Shipment,
    Tracking.TrackingEvent,
    Emails.InboundEmail,
    Shipments
  }

  def apply!(email, parsed) do
    Repo.transaction(fn ->
      order = upsert_order!(email, parsed)
      shipment = upsert_shipment!(order, parsed)
      if shipment, do: create_tracking_event!(shipment, parsed)
      email |> InboundEmail.changeset(%{status: :parsed, parse_error: nil}) |> Repo.update!()
      if shipment, do: Shipments.broadcast(:shipment_updated, shipment.id)
      %{order: order, shipment: shipment}
    end)
  end

  defp upsert_order!(email, parsed) do
    now = DateTime.utc_now()

    attrs = %{
      inbound_email_id: email.id,
      order_number: parsed.order_number || "unknown-#{email.id}",
      merchant_name: email.from_email,
      customer_name: parsed.customer_name,
      customer_postal_code: parsed.customer_postal_code,
      customer_street: parsed.customer_street,
      customer_house_number: parsed.customer_house_number
    }

    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert!(
      on_conflict:
        from(o in Order,
          update: [
            set: [
              merchant_name: fragment("COALESCE(EXCLUDED.merchant_name, ?)", o.merchant_name),
              customer_name: fragment("COALESCE(EXCLUDED.customer_name, ?)", o.customer_name),
              customer_postal_code:
                fragment("COALESCE(EXCLUDED.customer_postal_code, ?)", o.customer_postal_code),
              customer_street:
                fragment("COALESCE(EXCLUDED.customer_street, ?)", o.customer_street),
              customer_house_number:
                fragment("COALESCE(EXCLUDED.customer_house_number, ?)", o.customer_house_number),
              updated_at: ^now
            ]
          ]
        ),
      conflict_target: :order_number,
      returning: true
    )
  end

  defp upsert_shipment!(order, parsed) do
    if is_nil(parsed.tracking_number), do: nil, else: do_upsert_shipment!(order, parsed)
  end

  defp do_upsert_shipment!(order, parsed) do
    attrs = %{
      order_id: order.id,
      carrier: parsed.carrier,
      tracking_number: parsed.tracking_number,
      tracking_url: parsed.tracking_url,
      status: parsed.status,
      last_event_at: DateTime.utc_now()
    }

    %Shipment{}
    |> Shipment.changeset(attrs)
    |> Repo.insert!(
      on_conflict: [
        set: [
          status: attrs.status,
          carrier: attrs.carrier,
          tracking_url: attrs.tracking_url,
          last_event_at: attrs.last_event_at,
          updated_at: DateTime.utc_now()
        ]
      ],
      conflict_target: :tracking_number,
      returning: true
    )
  end

  defp create_tracking_event!(shipment, parsed) do
    %TrackingEvent{}
    |> TrackingEvent.changeset(%{
      shipment_id: shipment.id,
      status: Atom.to_string(parsed.status),
      occurred_at: DateTime.utc_now(),
      metadata: %{carrier: parsed.carrier}
    })
    |> Repo.insert!()
  end
end
