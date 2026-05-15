defmodule Rempost.Parsing.DeterministicParserTest do
  use ExUnit.Case, async: true

  alias Rempost.Parsing.DeterministicParser

  defp email(attrs) do
    Map.merge(
      %{
        subject: "",
        raw_text: "",
        raw_html: nil
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

  describe "tracking_url synthesis and allowlist" do
    test "synthesizes DHL eCommerce URL from JVGL tracking number when no clean URL in body" do
      parsed =
        email(%{
          subject: "DHL eCommerce Benelux is onderweg",
          raw_text:
            "Je pakket JVGL06178784002102090726 is onderweg. https://u123.sendcloud.com/ls/click?upn=ABC"
        })
        |> DeterministicParser.parse()

      assert parsed.tracking_number == "JVGL06178784002102090726"
      assert parsed.tracking_url ==
               "https://my.dhlecommerce.nl/home/tracktrace/JVGL06178784002102090726?role=consumer-receiver"
    end

    test "synthesizes PostNL URL from 3S code" do
      parsed =
        email(%{
          subject: "PostNL is onderweg",
          raw_text: "PostNL Tracking 3SABCD12345678 https://email-tracker.example/pixel.gif"
        })
        |> DeterministicParser.parse()

      assert parsed.tracking_number == "3SABCD12345678"
      assert parsed.tracking_url =~ "postnl.nl"
      assert parsed.tracking_url =~ "3SABCD12345678"
    end

    test "prefers allowlisted carrier URL from the body when present" do
      parsed =
        email(%{
          subject: "Pakket onderweg",
          raw_text:
            "Bekijk je pakket: https://my.dhlecommerce.nl/receiver/track/JVGL06178784002102090726/NL"
        })
        |> DeterministicParser.parse()

      assert parsed.tracking_url =~ "my.dhlecommerce.nl"
    end

    test "rejects sendgrid/sendcloud tracking pixel URLs" do
      parsed =
        email(%{
          subject: "Onderweg",
          raw_text:
            "open https://u123.sendgrid.net/wf/click?upn=ABC and https://u123.sendcloud.com/track"
        })
        |> DeterministicParser.parse()

      refute parsed.tracking_url
    end
  end

  describe "rich DHL fields" do
    test "extracts expected delivery window, merchant, signature flag, and subject" do
      parsed =
        email(%{
          subject: "We staan vandaag voor de deur tussen 14.40 - 18.00 uur (JVGL06178784001398345296)",
          raw_text: """
          We staan vandaag voor de deur Beste Jonathan Arendsen,
          Onze bezorger staat vandaag op de stoep met je pakket van XXL Nutrition - XXL Nutrition B.V..
          Om dit pakket aan te nemen is een handtekening nodig op verzoek van de verzender.
          Verwacht bezorgmoment donderdag 9 april tussen 14.40 - 18.00 uur
          Zendingsnummer JVGL06178784001398345296
          """
        })
        |> DeterministicParser.parse()

      assert parsed.tracking_number == "JVGL06178784001398345296"
      assert parsed.customer_name == "Jonathan Arendsen"
      assert parsed.merchant_name == "XXL Nutrition"
      assert parsed.merchant_legal_entity =~ "XXL Nutrition B.V"
      assert parsed.estimated_delivery_text =~ "tussen 14.40 - 18.00 uur"
      assert parsed.signature_required == true
      assert parsed.status == :in_transit
      assert parsed.latest_email_subject =~ "voor de deur"
    end

    test "extracts delivered timestamp text" do
      parsed =
        email(%{
          subject: "Je pakket is bezorgd (JVGL06178784002102090726)",
          raw_text:
            "Beste Iduna Bink, Je pakket JVGL06178784002102090726 van XXL Nutrition - XXL Nutrition B.V. is op maandag 4 mei om 13.02 bezorgd."
        })
        |> DeterministicParser.parse()

      assert parsed.status == :delivered
      assert parsed.delivered_at_text =~ "maandag 4 mei"
      assert parsed.delivered_at_text =~ "13.02"
      assert parsed.merchant_name == "XXL Nutrition"
    end

    test "falls back to HTML body when raw_text is mostly MJML/CSS noise" do
      css_noise =
        String.duplicate("table, td { border-collapse: collapse; mso-table-lspace: 0pt; } ", 40)

      html = """
      <html><head><style>body { margin: 0; }</style></head><body>
      <p>Beste Iduna Bink,</p>
      <p>Je pakket <a href="https://my.dhlecommerce.nl/track/JVGL06178784002034591522">JVGL06178784002034591522</a> is onderweg.</p>
      <p>Verwacht bezorgmoment vrijdag 14 mei tussen 09.00 - 12.00 uur</p>
      </body></html>
      """

      parsed =
        email(%{
          subject: "DHL eCommerce Benelux is onderweg",
          raw_text: css_noise,
          raw_html: html
        })
        |> DeterministicParser.parse()

      assert parsed.tracking_number == "JVGL06178784002034591522"
      assert parsed.customer_name == "Iduna Bink"
      assert parsed.estimated_delivery_text =~ "vrijdag 14 mei"
      assert parsed.status == :in_transit
    end

    test "extracts multi-line 'Verwacht bezorgmoment' block from real DHL mail" do
      parsed =
        email(%{
          subject: "DHL eCommerce Benelux is onderweg",
          raw_text: """
          Onze bezorger staat vandaag op de stoep met je pakket JVGL06178784002034591522
          van XXL Nutrition - XXL Nutrition B.V.. Komt het niet goed uit?

          https://my.dhlecommerce.nl/home/tracktrace/JVGL06178784002034591522?role=consumer-receiver

          Verwacht bezorgmoment
          Dinsdag 12 mei

          Tussen 13.20 - 17.20 uur
          """
        })
        |> DeterministicParser.parse()

      assert parsed.tracking_number == "JVGL06178784002034591522"
      assert parsed.merchant_name == "XXL Nutrition"
      assert parsed.estimated_delivery_text =~ "Dinsdag 12 mei"
      assert parsed.estimated_delivery_text =~ "13.20 - 17.20 uur"
      assert parsed.tracking_url =~ "my.dhlecommerce.nl"
    end

    test "extracts city next to postcode" do
      parsed =
        email(%{
          subject: "PostNL is onderweg",
          raw_text: """
          Bezorgadres
          Monteverdistraat 212
          2035 PH Haarlem
          Nederland
          """
        })
        |> DeterministicParser.parse()

      assert parsed.customer_postal_code == "2035PH"
      assert parsed.customer_city == "Haarlem"
    end
  end

  describe "order number patterns" do
    test "matches XXL Nutrition style 'Ordernummer: #1234567'" do
      parsed =
        email(%{
          subject: "Je bestelling is klaar voor verzending",
          raw_text: "Ordernummer: #1234567\nBedankt voor je bestelling."
        })
        |> DeterministicParser.parse()

      assert parsed.order_number == "1234567"
    end
  end
end
