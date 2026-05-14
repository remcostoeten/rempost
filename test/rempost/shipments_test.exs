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

  defp insert_order!(order_number, merchant_name) do
    %Order{}
    |> Order.changeset(%{order_number: order_number, merchant_name: merchant_name})
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
