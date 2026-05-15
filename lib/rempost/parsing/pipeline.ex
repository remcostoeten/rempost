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
      shipment = upsert_shipment!(order, parsed, email)
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
      merchant_name: parsed[:merchant_name] || email.from_email,
      merchant_legal_entity: parsed[:merchant_legal_entity],
      customer_name: parsed.customer_name,
      customer_postal_code: parsed.customer_postal_code,
      customer_street: parsed.customer_street,
      customer_house_number: parsed.customer_house_number,
      customer_city: parsed[:customer_city]
    }

    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert!(
      on_conflict:
        from(o in Order,
          update: [
            set: [
              merchant_name: fragment("COALESCE(EXCLUDED.merchant_name, ?)", o.merchant_name),
              merchant_legal_entity:
                fragment("COALESCE(EXCLUDED.merchant_legal_entity, ?)", o.merchant_legal_entity),
              customer_name: fragment("COALESCE(EXCLUDED.customer_name, ?)", o.customer_name),
              customer_postal_code:
                fragment("COALESCE(EXCLUDED.customer_postal_code, ?)", o.customer_postal_code),
              customer_street:
                fragment("COALESCE(EXCLUDED.customer_street, ?)", o.customer_street),
              customer_house_number:
                fragment("COALESCE(EXCLUDED.customer_house_number, ?)", o.customer_house_number),
              customer_city:
                fragment("COALESCE(EXCLUDED.customer_city, ?)", o.customer_city),
              updated_at: ^now
            ]
          ]
        ),
      conflict_target: :order_number,
      returning: true
    )
  end

  defp upsert_shipment!(order, parsed, email) do
    if is_nil(parsed.tracking_number), do: nil, else: do_upsert_shipment!(order, parsed, email)
  end

  defp do_upsert_shipment!(order, parsed, email) do
    now = DateTime.utc_now()
    event_at = email.received_at || now

    attrs = %{
      order_id: order.id,
      carrier: parsed.carrier,
      tracking_number: parsed.tracking_number,
      tracking_url: parsed.tracking_url,
      status: parsed.status,
      last_event_at: event_at,
      estimated_delivery_text: parsed[:estimated_delivery_text],
      delivered_at_text: parsed[:delivered_at_text],
      signature_required: parsed[:signature_required] || false,
      latest_email_subject: parsed[:latest_email_subject]
    }

    %Shipment{}
    |> Shipment.changeset(attrs)
    |> Repo.insert!(
      on_conflict:
        from(s in Shipment,
          update: [
            set: [
              order_id: ^attrs.order_id,
              status: ^attrs.status,
              carrier: ^attrs.carrier,
              tracking_url: fragment("COALESCE(EXCLUDED.tracking_url, ?)", s.tracking_url),
              estimated_delivery_text:
                fragment(
                  "COALESCE(EXCLUDED.estimated_delivery_text, ?)",
                  s.estimated_delivery_text
                ),
              delivered_at_text:
                fragment("COALESCE(EXCLUDED.delivered_at_text, ?)", s.delivered_at_text),
              signature_required:
                fragment("(? OR EXCLUDED.signature_required)", s.signature_required),
              latest_email_subject:
                fragment("COALESCE(EXCLUDED.latest_email_subject, ?)", s.latest_email_subject),
              last_event_at:
                fragment("GREATEST(EXCLUDED.last_event_at, ?)", s.last_event_at),
              updated_at: ^now
            ]
          ]
        ),
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
