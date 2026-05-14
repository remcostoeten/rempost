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

  test "moves an existing tracking number to the newly parsed order owner" do
    first_email =
      insert_email!(%{
        message_id: "first-owner@example",
        subject: "Shipment update",
        raw_text: """
        Naam: Sven de Langen
        Adres: Schoolstraat 37
        1948 DG Beverwijk
        Track & Trace JVGL06178784002102090726
        """
      })

    first_parsed = DeterministicParser.parse(first_email)
    assert {:ok, %{shipment: first_shipment}} = Pipeline.apply!(first_email, first_parsed)

    second_email =
      insert_email!(%{
        message_id: "second-owner@example",
        subject: "DHL eCommerce Benelux is onderweg",
        raw_text: """
        Bezorgadres
        Monteverdistraat 212
        2035 PH Haarlem
        Nederland

        Iduna Bink,

        Je order 5234424 is onderweg en wordt bezorgd door DHL eCommerce Benelux.
        Track & Trace JVGL06178784002102090726
        """
      })

    second_parsed = DeterministicParser.parse(second_email)
    assert {:ok, %{shipment: moved_shipment}} = Pipeline.apply!(second_email, second_parsed)

    assert moved_shipment.id == first_shipment.id

    moved_shipment = Rempost.Shipments.get_shipment!(moved_shipment.id)

    assert moved_shipment.order.customer_name == "Iduna Bink"
    assert moved_shipment.order.customer_postal_code == "2035PH"
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
