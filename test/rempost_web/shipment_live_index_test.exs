defmodule RempostWeb.ShipmentLiveIndexTest do
  use RempostWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Rempost.Orders.Order
  alias Rempost.Repo
  alias Rempost.Shipments.Shipment

  test "looks up public shipments through name and postcode flow", %{conn: conn} do
    order =
      insert_order!(%{
        order_number: "XXL-PORTAL-1",
        merchant_name: "XXL Nutrition",
        customer_name: "Iduna Bink",
        customer_postal_code: "2035PH",
        customer_street: "Monteverdistraat",
        customer_house_number: "212"
      })

    insert_shipment!(order, "JVGL06178784002102090726")

    {:ok, view, html} = live(conn, ~p"/portal")

    assert html =~ "Naam op bestelling"

    view
    |> form("form[phx-submit='identify']", lookup: %{name: "Iduna"})
    |> render_submit()

    assert render(view) =~ "Welke postcode"

    view
    |> form("form[phx-submit='verify_address']",
      verification: %{mode: "postcode", value: "2035 PH"}
    )
    |> render_submit()

    html = render(view)

    assert html =~ "Pakketjes"
    assert html =~ "XXL Nutrition"
    assert html =~ "JVGL06178784002102090726"
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
