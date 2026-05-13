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
        raw_text: "Your package is in transit. Tracking number: 123456789012"
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "dhl"
    assert parsed.order_number == "AB-123"
    assert parsed.tracking_number == "123456789012"
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

  test "falls back to unknown carrier and ordered status" do
    parsed =
      email(%{
        subject: "Store update",
        raw_text: "We are preparing your purchase."
      })
      |> DeterministicParser.parse()

    assert parsed.carrier == "unknown"
    assert parsed.tracking_number == nil
    assert parsed.order_number == nil
    assert parsed.status == :ordered
  end
end
