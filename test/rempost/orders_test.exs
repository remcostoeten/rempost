defmodule Rempost.OrdersTest do
  use Rempost.DataCase

  alias Rempost.Orders
  alias Rempost.Orders.Order
  alias Rempost.Repo
  alias Rempost.Shipments.Shipment

  test "public lookup matches name with postal code and returns preloaded shipments" do
    order =
      insert_order!(%{
        order_number: "XXL-100",
        customer_name: "Jane van Dijk",
        customer_postal_code: "1234AB",
        customer_street: "Hoofdstraat",
        customer_house_number: "12B"
      })

    insert_shipment!(order, "JVGL06178784002102090726")

    insert_order!(%{
      order_number: "XXL-101",
      customer_name: "Jane van Dijk",
      customer_postal_code: "9999ZZ"
    })

    assert [match] = Orders.public_lookup(%{name: "jane", postal_code: "1234 ab"})
    assert match.id == order.id
    assert [%Shipment{}] = match.shipments
  end

  test "public lookup matches name with street and house number" do
    order =
      insert_order!(%{
        order_number: "XXL-200",
        customer_name: "Jane van Dijk",
        customer_street: "Hoofdstraat",
        customer_house_number: "12B"
      })

    assert [match] = Orders.public_lookup(%{name: "Jane", street: "Hoofdstraat 12 b"})
    assert match.id == order.id
  end

  test "public lookup requires name plus postal code or street and house number" do
    insert_order!(%{
      order_number: "XXL-300",
      customer_name: "Jane van Dijk",
      customer_postal_code: "1234AB",
      customer_street: "Hoofdstraat",
      customer_house_number: "12B"
    })

    assert [] = Orders.public_lookup(%{postal_code: "1234AB"})
    assert [] = Orders.public_lookup(%{name: "Jane"})
    assert [] = Orders.public_lookup(%{name: "Jane", street: "Hoofdstraat"})
  end

  defp insert_order!(attrs) do
    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_shipment!(order, tracking_number) do
    %Shipment{}
    |> Shipment.changeset(%{
      order_id: order.id,
      tracking_number: tracking_number,
      carrier: "dhl",
      status: :in_transit
    })
    |> Repo.insert!()
  end
end
