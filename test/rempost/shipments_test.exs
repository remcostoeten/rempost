defmodule Rempost.ShipmentsTest do
  use Rempost.DataCase

  alias Rempost.Orders.Order
  alias Rempost.Repo
  alias Rempost.Shipments
  alias Rempost.Shipments.Shipment

  test "searches shipments by order number, merchant, carrier, status, and tracking number" do
    order = insert_order!("XXL-100", "XXL Nutrition")
    insert_shipment!(order, "JVGL06178784002102090726", "dhl", :in_transit)

    assert [%Shipment{}] = Shipments.search_shipments("xxl-100")
    assert [%Shipment{}] = Shipments.search_shipments("nutrition")
    assert [%Shipment{}] = Shipments.search_shipments("dhl")
    assert [%Shipment{}] = Shipments.search_shipments("in_transit")
    assert [%Shipment{}] = Shipments.search_shipments("102090726")
    assert [] = Shipments.search_shipments("missing")
  end

  test "looks up public shipments by customer name and postal code" do
    order =
      insert_order!("XXL-200", "XXL Nutrition", %{
        customer_name: "Jane van Dijk",
        customer_postal_code: "1234AB",
        customer_house_number: "12B"
      })

    shipment = insert_shipment!(order, "JVGL06178784002102090727", "dhl", :in_transit)

    assert [match] = Shipments.lookup_public_shipments("jane", "postcode", "1234 ab")
    assert match.id == shipment.id
    assert match.order.id == order.id
    assert [] = Shipments.lookup_public_shipments("jane", "postcode", "9999ZZ")
  end

  test "looks up public shipments by customer name and street house number input" do
    order =
      insert_order!("XXL-201", "XXL Nutrition", %{
        customer_name: "Jane van Dijk",
        customer_street: "Hoofdstraat",
        customer_house_number: "12B"
      })

    shipment = insert_shipment!(order, "JVGL06178784002102090728", "dhl", :in_transit)

    assert [match] = Shipments.lookup_public_shipments("jane", "house_number", "Hoofdstraat 12 b")
    assert match.id == shipment.id
  end

  defp insert_order!(order_number, merchant_name) do
    insert_order!(order_number, merchant_name, %{})
  end

  defp insert_order!(order_number, merchant_name, attrs) do
    %Order{}
    |> Order.changeset(
      Map.merge(%{order_number: order_number, merchant_name: merchant_name}, attrs)
    )
    |> Repo.insert!()
  end

  defp insert_shipment!(order, tracking_number, carrier, status) do
    %Shipment{}
    |> Shipment.changeset(%{
      order_id: order.id,
      tracking_number: tracking_number,
      carrier: carrier,
      status: status
    })
    |> Repo.insert!()
  end
end
