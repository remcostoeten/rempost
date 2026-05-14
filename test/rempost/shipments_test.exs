defmodule Rempost.ShipmentsTest do
  use Rempost.DataCase

  alias Rempost.Orders.Order
  alias Rempost.Repo
  alias Rempost.Emails.InboundEmail
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

  test "filters all shipments by stored order customer name" do
    iduna_order =
      insert_order!("XXL-FILTER-1", "XXL Nutrition", %{
        customer_name: "Iduna Bink"
      })

    jane_order =
      insert_order!("XXL-FILTER-2", "XXL Nutrition", %{
        customer_name: "Jane van Dijk"
      })

    iduna_shipment = insert_shipment!(iduna_order, "JVGL06178784002111111111", "dhl", :in_transit)
    insert_shipment!(jane_order, "JVGL06178784002222222222", "dhl", :in_transit)

    assert [match] = Shipments.list_shipments(customer_name: " iduna  bink ")
    assert match.id == iduna_shipment.id
  end

  test "semantic shipment search matches customer, content, mail type, address, and date" do
    email =
      insert_email!(%{
        message_id: "semantic@example",
        from_email: "notify@carrier.example",
        subject: "Delivery exception update",
        received_at: ~U[2026-05-12 09:30:00Z],
        raw_text: "Fragile package for Monteverdistraat. Driver could not access the address."
      })

    order =
      insert_order!("XXL-SEMANTIC-1", "XXL Nutrition", %{
        inbound_email_id: email.id,
        customer_name: "Iduna Bink",
        customer_postal_code: "2035PH",
        customer_street: "Monteverdistraat",
        customer_house_number: "212"
      })

    shipment = insert_shipment!(order, "JVGL06178784002133333333", "dhl", :in_transit)

    assert [match] = Shipments.list_shipments(search: "Iduna")
    assert match.id == shipment.id

    assert [match] = Shipments.list_shipments(search: "fragile package")
    assert match.id == shipment.id

    assert [match] = Shipments.list_shipments(search: "Delivery exception")
    assert match.id == shipment.id

    assert [match] = Shipments.list_shipments(search: "Monteverdistraat")
    assert match.id == shipment.id

    assert [match] = Shipments.list_shipments(search: "2026-05-12")
    assert match.id == shipment.id

    assert [match] = Shipments.list_shipments(search: "onderweg")
    assert match.id == shipment.id
  end

  describe "suggest_recipients/2" do
    test "returns recipients matching a prefix, case- and accent-insensitive" do
      anna = insert_order!("ORD-S-1", "XXL Nutrition", %{customer_name: "Anna van Dijk"})
      insert_shipment!(anna, "JVGL000000000000000001", "dhl", :in_transit)

      jose = insert_order!("ORD-S-2", "XXL Nutrition", %{customer_name: "José Martínez"})
      insert_shipment!(jose, "JVGL000000000000000002", "dhl", :in_transit)

      assert [%{name: "Anna van Dijk", shipment_count: 1}] =
               Shipments.suggest_recipients("anna")

      assert [%{name: "José Martínez"}] = Shipments.suggest_recipients("jose")
    end

    test "matches substrings, not just prefixes" do
      order = insert_order!("ORD-S-3", "XXL Nutrition", %{customer_name: "Anna van Dijk"})
      insert_shipment!(order, "JVGL000000000000000003", "dhl", :in_transit)

      assert [%{name: "Anna van Dijk"}] = Shipments.suggest_recipients("dijk")
    end

    test "returns [] for queries shorter than 2 trimmed characters" do
      order = insert_order!("ORD-S-4", "XXL Nutrition", %{customer_name: "Anna van Dijk"})
      insert_shipment!(order, "JVGL000000000000000004", "dhl", :in_transit)

      assert [] = Shipments.suggest_recipients("")
      assert [] = Shipments.suggest_recipients(" ")
      assert [] = Shipments.suggest_recipients("a")
    end

    test "groups by name and counts shipments" do
      order = insert_order!("ORD-S-5", "XXL Nutrition", %{customer_name: "Tom Bakker"})
      insert_shipment!(order, "JVGL000000000000000005", "dhl", :in_transit)
      insert_shipment!(order, "JVGL000000000000000006", "dhl", :shipped)

      assert [%{name: "Tom Bakker", shipment_count: 2}] = Shipments.suggest_recipients("tom")
    end

    test "honours the limit" do
      for i <- 1..10 do
        order =
          insert_order!("ORD-S-LIM-#{i}", "XXL Nutrition", %{
            customer_name: "Recipient #{i}"
          })

        insert_shipment!(order, "JVGL00000000000000LIM#{i}", "dhl", :in_transit)
      end

      assert length(Shipments.suggest_recipients("recipient", 3)) == 3
    end
  end

  describe "lookup_by_recipient/1" do
    test "returns shipments whose order customer_name matches exactly (case and accent insensitive)" do
      iduna =
        insert_order!("ORD-L-1", "XXL Nutrition", %{customer_name: "Iduna Bink"})

      shipment = insert_shipment!(iduna, "JVGL00000000000000L001", "dhl", :in_transit)

      other =
        insert_order!("ORD-L-2", "XXL Nutrition", %{customer_name: "Jane van Dijk"})

      insert_shipment!(other, "JVGL00000000000000L002", "dhl", :in_transit)

      assert [match] = Shipments.lookup_by_recipient("iduna bink")
      assert match.id == shipment.id

      assert [match] = Shipments.lookup_by_recipient("IDUNA BINK")
      assert match.id == shipment.id
    end

    test "folds accents on both sides" do
      order = insert_order!("ORD-L-3", "XXL Nutrition", %{customer_name: "José Martínez"})
      shipment = insert_shipment!(order, "JVGL00000000000000L003", "dhl", :in_transit)

      assert [match] = Shipments.lookup_by_recipient("jose martinez")
      assert match.id == shipment.id
    end

    test "returns [] for an unknown name" do
      order = insert_order!("ORD-L-4", "XXL Nutrition", %{customer_name: "Iduna Bink"})
      insert_shipment!(order, "JVGL00000000000000L004", "dhl", :in_transit)

      assert [] = Shipments.lookup_by_recipient("nobody")
      assert [] = Shipments.lookup_by_recipient("")
      assert [] = Shipments.lookup_by_recipient(nil)
    end

    test "returns all shipments for a recipient with multiple orders" do
      order_a = insert_order!("ORD-L-5", "XXL Nutrition", %{customer_name: "Tom Bakker"})
      shipment_a = insert_shipment!(order_a, "JVGL00000000000000L005", "dhl", :in_transit)

      order_b = insert_order!("ORD-L-6", "XXL Nutrition", %{customer_name: "Tom Bakker"})
      shipment_b = insert_shipment!(order_b, "JVGL00000000000000L006", "dhl", :shipped)

      ids = Shipments.lookup_by_recipient("tom bakker") |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == Enum.sort([shipment_a.id, shipment_b.id])
    end

    test "preloads the order" do
      order = insert_order!("ORD-L-7", "XXL Nutrition", %{customer_name: "Anna van Dijk"})
      insert_shipment!(order, "JVGL00000000000000L007", "dhl", :in_transit)

      [match] = Shipments.lookup_by_recipient("anna van dijk")
      assert %Rempost.Orders.Order{order_number: "ORD-L-7"} = match.order
    end
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
