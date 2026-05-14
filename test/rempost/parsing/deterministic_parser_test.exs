defmodule Rempost.Parsing.DeterministicParserTest do
  use ExUnit.Case, async: true

  alias Rempost.Parsing.DeterministicParser

  defp email(attrs) do
    Map.merge(
      %{
        subject: "",
        raw_text: ""
      },
      attrs
    )
  end

  test "extracts DHL shipment data from subject and body" do
    parsed =
      email(%{
        subject: "DHL Shipment update for order #ab-123",
        raw_text:
          "Your package is in transit. Tracking number: 123456789012 https://www.dhl.com/track/123456789012"
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "dhl"
    assert parsed.order_number == "AB-123"
    assert parsed.tracking_number == "123456789012"
    assert parsed.tracking_url == "https://www.dhl.com/track/123456789012"
    assert parsed.status == :in_transit
  end

  test "supports shipped and delivered status precedence" do
    parsed =
      email(%{
        subject: "UPS: package delivered",
        raw_text: "This was shipped yesterday and delivered today. 109876543210"
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "ups"
    assert parsed.status == :delivered
  end

  test "extracts dutch order confirmation data" do
    parsed =
      email(%{
        subject: "Je bestelling is klaar voor verzending",
        raw_text: "Je order 5234424 is onderweg en wordt bezorgd door DHL eCommerce Benelux."
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "dhl"
    assert parsed.order_number == "5234424"
    assert parsed.status == :in_transit
  end

  test "does not treat status words or html tags as order numbers" do
    parsed =
      email(%{
        subject: "Je bestelling is klaar voor verzending",
        raw_text: "<div>Je bestelling is later onderweg.</div>"
      })
      |> DeterministicParser.parse()

    assert parsed.order_number == nil
  end

  test "extracts conservative customer lookup fields" do
    parsed =
      email(%{
        subject: "XXL Nutrition order 7788",
        raw_text: """
        Naam: Jane van Dijk
        Adres: Hoofdstraat 12 B
        1234 AB Amsterdam
        Track & Trace JVGL06178784002102090726
        """
      })
      |> DeterministicParser.parse()

    assert parsed.customer_name == "Jane van Dijk"
    assert parsed.customer_postal_code == "1234AB"
    assert parsed.customer_street == "Hoofdstraat"
    assert parsed.customer_house_number == "12B"
  end

  test "extracts Sendcloud-style address and recipient blocks" do
    parsed =
      email(%{
        subject: "DHL eCommerce Benelux is onderweg",
        raw_text: """
        Bezorgadres
        Monteverdistraat 212
        2035 PH Haarlem
        Nederland

        Iduna Bink,

        Je order 5234424 is onderweg en wordt bezorgd door DHL eCommerce Benelux.
        """
      })
      |> DeterministicParser.parse()

    assert parsed.customer_name == "Iduna Bink"
    assert parsed.customer_postal_code == "2035PH"
    assert parsed.customer_street == "Monteverdistraat"
    assert parsed.customer_house_number == "212"
    assert parsed.order_number == "5234424"
  end

  test "extracts PostNL tracking codes from Sendcloud HTML" do
    parsed =
      email(%{
        subject: "PostNL is onderweg",
        raw_text: """
        Bezorgadres
        Monteverdistraat 212
        2035 PH Haarlem
        Nederland

        Iduna Bink,

        Je order 5085945 is onderweg en wordt bezorgd door PostNL.
        Track & Trace 3SBAAS8530142
        """
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "postnl"
    assert parsed.tracking_number == "3SBAAS8530142"
    assert parsed.customer_name == "Iduna Bink"
    assert parsed.customer_postal_code == "2035PH"
    assert parsed.order_number == "5085945"
  end

  test "extracts dutch delivered tracking data" do
    parsed =
      email(%{
        subject: "Je pakket is bezorgd (JVGL06178784002102090726)",
        raw_text: "Je pakket JVGL06178784002102090726 is bezorgd."
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "dhl"
    assert parsed.tracking_number == "JVGL06178784002102090726"
    assert parsed.status == :delivered
  end

  test "extracts dutch PostNL transit status" do
    parsed =
      email(%{
        subject: "PostNL is onderweg",
        raw_text: "Je bestelling is onderweg en komt binnenkort aan."
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "postnl"
    assert parsed.status == :in_transit
  end

  test "falls back to unknown carrier and ordered status" do
    parsed =
      email(%{
        subject: "Store update",
        raw_text: "We are preparing your purchase."
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "unknown"
    assert parsed.tracking_number == nil
    assert parsed.tracking_url == nil
    assert parsed.order_number == nil
    assert parsed.status == :ordered
  end
end
