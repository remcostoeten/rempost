defmodule RempostWeb.ShipmentLiveIndexTest do
  use RempostWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Rempost.Orders.Order
  alias Rempost.Repo
  alias Rempost.Shipments.Shipment

  setup do
    previous_master = Application.get_env(:rempost, :portal_master_password)

    on_exit(fn ->
      restore_env(:portal_master_password, previous_master)
    end)

    :ok
  end

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

    assert html =~ "1 pakket gevonden"
    assert html =~ "XXL Nutrition"
    assert html =~ "JVGL06178784002102090726"
  end

  test "lookup state is reflected in url params and logo returns to start", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/portal")

    assert html =~ ~s(href="/portal?step=start")

    view
    |> form("form[phx-submit='identify']", lookup: %{name: "Iduna Bink"})
    |> render_submit()

    assert_patch(view, ~p"/portal?name=Iduna+Bink&step=verify")

    view
    |> element(~s(a[href="/portal?step=start"]))
    |> render_click()

    assert_patch(view, ~p"/portal?step=start")
    assert render(view) =~ "Naam op bestelling"
  end

  test "renders split address and tracking emails without internal order placeholders", %{
    conn: conn
  } do
    insert_order!(%{
      order_number: "XXL-PORTAL-2",
      merchant_name: "XXL Nutrition",
      customer_name: "Iduna Bink",
      customer_postal_code: "2035PH",
      customer_street: "Monteverdistraat",
      customer_house_number: "212"
    })

    tracking_order =
      insert_order!(%{
        order_number: "unknown-202",
        merchant_name: "noreply@dhlecommerce.nl",
        customer_name: "Iduna Bink"
      })

    insert_shipment!(tracking_order, "JVGL06178784002034591522")

    {:ok, view, _html} = live(conn, ~p"/portal")

    view
    |> form("form[phx-submit='identify']", lookup: %{name: "Iduna Bink"})
    |> render_submit()

    view
    |> form("form[phx-submit='verify_address']",
      verification: %{mode: "postcode", value: "2035 PH"}
    )
    |> render_submit()

    html = render(view)

    assert html =~ "1 pakket gevonden"
    assert html =~ "Pakket via DHL eCommerce"
    assert html =~ "JVGL06178784002034591522"
    refute html =~ "unknown-202"
    refute html =~ "dhlecommerce"
  end

  test "master password opens the full shipment list", %{conn: conn} do
    Application.put_env(:rempost, :portal_master_password, "master")

    order =
      insert_order!(%{
        order_number: "XXL-PORTAL-3",
        merchant_name: "XXL Nutrition",
        customer_name: "Someone Else",
        customer_postal_code: "9999ZZ",
        customer_street: "Somewhere",
        customer_house_number: "1"
      })

    insert_shipment!(order, "JVGL06178784009999999999")

    {:ok, view, html} = live(conn, ~p"/portal")

    assert html =~ "Master toegang"

    view
    |> form("form[phx-submit='master_access']", master: %{password: "master"})
    |> render_submit()

    html = render(view)

    assert html =~ "Alle zendingen"
    assert html =~ "JVGL06178784009999999999"
  end

  test "master results can be filtered by stored order person", %{conn: conn} do
    Application.put_env(:rempost, :portal_master_password, "master")

    iduna_order =
      insert_order!(%{
        order_number: "XXL-PORTAL-FILTER-1",
        merchant_name: "XXL Nutrition",
        customer_name: "Iduna Bink",
        customer_postal_code: "2035PH"
      })

    jane_order =
      insert_order!(%{
        order_number: "XXL-PORTAL-FILTER-2",
        merchant_name: "XXL Nutrition",
        customer_name: "Jane van Dijk",
        customer_postal_code: "1234AB"
      })

    insert_shipment!(iduna_order, "JVGL06178784001111111111")
    insert_shipment!(jane_order, "JVGL06178784002222222222")

    {:ok, view, _html} = live(conn, ~p"/portal")

    view
    |> form("form[phx-submit='master_access']", master: %{password: "master"})
    |> render_submit()

    html = render(view)
    assert html =~ "Iduna Bink"
    assert html =~ "Jane van Dijk"

    view
    |> element(~s(a[href="/portal?master=1&search=&step=results&customer=Iduna+Bink"]))
    |> render_click()

    assert_patch(view, ~p"/portal?master=1&search=&step=results&customer=Iduna+Bink")

    html = render(view)
    assert html =~ "JVGL06178784001111111111"
    refute html =~ "JVGL06178784002222222222"
  end

  test "master results search filters shipments semantically", %{conn: conn} do
    Application.put_env(:rempost, :portal_master_password, "master")

    matching_order =
      insert_order!(%{
        order_number: "XXL-PORTAL-SEARCH-1",
        merchant_name: "XXL Nutrition",
        customer_name: "Iduna Bink",
        customer_postal_code: "2035PH",
        customer_street: "Monteverdistraat",
        customer_house_number: "212"
      })

    other_order =
      insert_order!(%{
        order_number: "XXL-PORTAL-SEARCH-2",
        merchant_name: "Other Shop",
        customer_name: "Jane van Dijk",
        customer_postal_code: "1234AB",
        customer_street: "Hoofdstraat",
        customer_house_number: "12"
      })

    insert_shipment!(matching_order, "JVGL06178784003333333333")
    insert_shipment!(other_order, "JVGL06178784004444444444")

    {:ok, view, _html} = live(conn, ~p"/portal")

    view
    |> form("form[phx-submit='master_access']", master: %{password: "master"})
    |> render_submit()

    view
    |> form("form[phx-change='search_results']", filters: %{search: "Monteverdistraat"})
    |> render_change()

    assert_patch(view, ~p"/portal?master=1&search=Monteverdistraat&step=results&customer=")

    html = render(view)
    assert html =~ "JVGL06178784003333333333"
    refute html =~ "JVGL06178784004444444444"
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

  defp restore_env(key, nil), do: Application.delete_env(:rempost, key)
  defp restore_env(key, value), do: Application.put_env(:rempost, key, value)
end
