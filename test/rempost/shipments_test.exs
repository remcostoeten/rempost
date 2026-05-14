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

  test "returns shipments for a verified customer when address is on a separate order email" do
    insert_order!("XXL-202", "XXL Nutrition", %{
      customer_name: "Iduna Bink",
      customer_postal_code: "2035PH",
      customer_street: "Monteverdistraat",
      customer_house_number: "212"
    })

    tracking_order =
      insert_order!("unknown-202", "DHL", %{
        customer_name: "Iduna Bink"
      })

    shipment = insert_shipment!(tracking_order, "JVGL06178784002102090729", "dhl", :in_transit)

    assert [match] = Shipments.lookup_public_shipments("Iduna Bink", "postcode", "2035 PH")
    assert match.id == shipment.id
    assert match.order.id == tracking_order.id
    assert [] = Shipments.lookup_public_shipments("Iduna Bink", "postcode", "9999ZZ")
  end

  test "does not return same-name shipments for a different known address" do
    insert_order!("XXL-202", "XXL Nutrition", %{
      customer_name: "Iduna Bink",
      customer_postal_code: "2035PH",
      customer_street: "Monteverdistraat",
      customer_house_number: "212"
    })

    other_address_order =
      insert_order!("XXL-203", "XXL Nutrition", %{
        customer_name: "Iduna Bink",
        customer_postal_code: "7051WG",
        customer_street: "Kraaienhof",
        customer_house_number: "17"
      })

    no_address_order =
      insert_order!("unknown-203", "DHL", %{
        customer_name: "Iduna Bink"
      })

    insert_shipment!(other_address_order, "3SBAAS8530142", "postnl", :in_transit)

    no_address_shipment =
      insert_shipment!(no_address_order, "JVGL06178784002034591522", "dhl", :shipped)

    assert [match] = Shipments.lookup_public_shipments("Iduna Bink", "postcode", "2035 PH")
    assert match.id == no_address_shipment.id
  end

  test "deduplicates tracking numbers that differ only by case" do
    order =
      insert_order!("XXL-204", "XXL Nutrition", %{
        customer_name: "Iduna Bink",
        customer_postal_code: "2035PH",
        customer_street: "Monteverdistraat",
        customer_house_number: "212"
      })

    insert_shipment!(order, "jvgl06178784001268735820", "dhl", :shipped)
    insert_shipment!(order, "JVGL06178784001268735820", "dhl", :delivered)

    assert [_match] = Shipments.lookup_public_shipments("Iduna Bink", "postcode", "2035 PH")
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
