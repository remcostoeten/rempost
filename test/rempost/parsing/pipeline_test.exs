defmodule Rempost.Parsing.PipelineTest do
  use Rempost.DataCase

  alias Rempost.Emails.InboundEmail
  alias Rempost.Orders.Order
  alias Rempost.Parsing.{DeterministicParser, Pipeline}
  alias Rempost.Repo
  alias Rempost.Shipments.Shipment

  test "marks no-tracking emails parsed without creating shipments" do
    email =
      insert_email!(%{
        message_id: "no-tracking@example",
        subject: "Order received",
        raw_text: "We received order 12345 and will prepare it soon."
      })

    parsed = DeterministicParser.parse(email)

    assert parsed.tracking_number == nil

    assert {:ok, %{shipment: nil}} = Pipeline.apply!(email, parsed)
    assert Repo.aggregate(Shipment, :count) == 0
    assert Repo.reload!(email).status == :parsed
  end

  test "persists parsed customer lookup fields on derived orders" do
    email =
      insert_email!(%{
        message_id: "lookup-fields@example",
        subject: "DHL update for order #lookup-100",
        raw_text: """
        Naam: Jane van Dijk
        Adres: Hoofdstraat 12 B
        1234 AB Amsterdam
        Tracking number: 123456789012
        """
      })

    parsed = DeterministicParser.parse(email)

    assert {:ok, %{order: order}} = Pipeline.apply!(email, parsed)

    order = Repo.get!(Order, order.id)
    assert order.customer_name == "Jane van Dijk"
    assert order.customer_postal_code == "1234AB"
    assert order.customer_street == "Hoofdstraat"
    assert order.customer_house_number == "12B"
  end

  defp insert_email!(attrs) do
    defaults = %{
      message_id: "message@example",
      from_email: "shop@example.com",
      subject: "Shipment update",
      received_at: DateTime.truncate(DateTime.utc_now(), :second),
      raw_headers: %{},
      raw_text: "Tracking number: 123456789012"
    }

    %InboundEmail{}
    |> InboundEmail.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
