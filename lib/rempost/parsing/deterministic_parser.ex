defmodule Rempost.Parsing.DeterministicParser do
  alias Rempost.Parsing.TrackingUrl

  @tracking_regex ~r/\b(?:JVGL[0-9A-Z]{10,30}|3S[0-9A-Z]{8,30}|\d{10,20})\b/i
  @order_regex ~r/\b(?:order(?:nummer)?|bestelling|bestelnummer)\b[^A-Z0-9\n\r]{0,20}#?\s*([A-Z0-9][A-Z0-9\-]{2,})\b/i
  @track_and_trace_regex ~r/track\s*&?\s*trace.*?([A-Z0-9]{6,})/i
  @invalid_order_numbers ~w(BEZORGD DIV KLAAR LATER ONDERWEG VERZENDING)
  @customer_name_regexes [
    ~r/(?:naam|name)\s*:\s*([^\n\r<]+)/i,
    ~r/\b(?:beste|dear|hallo|hi|hey)\s+([A-ZÀ-ÿ][^\n\r,<.!?]+?)[,.!?\n]/i,
    ~r/(?:Nederland|Netherlands)\s+([A-ZÀ-ÿ][^\n\r,<]+),/i,
    ~r/^\s*([A-ZÀ-ÿ][A-ZÀ-ÿ' .-]+),\s*$/im
  ]
  @postal_code_regex ~r/\b([1-9][0-9]{3}\s?[A-Z]{2})\b/i
  @postcode_city_regex ~r/\b[1-9][0-9]{3}\s?[A-Z]{2}\s+([A-ZÀ-ÿ][A-ZÀ-ÿ' .-]{1,40})/i
  @address_regexes [
    ~r/(?:adres|address)\s*:\s*([^\n\r,]+?)\s+(\d{1,5}\s?[A-Za-z]?(?:-\d+)?)\b/i,
    ~r/^\s*([A-ZÀ-ÿ][A-ZÀ-ÿ0-9' .-]{2,}?)\s+(\d{1,5}\s?[A-Za-z]?(?:-\d+)?)\s*$/im
  ]

  @merchant_legal_regex ~r/\bvan\s+([A-Z0-9][^\n\r]+?)\s+-\s+([A-Z0-9][^\n\r]+?B\.?V\.?|[A-Z0-9][^\n\r]+?N\.?V\.?|[A-Z0-9][^\n\r]+?GmbH)\b/i
  @expected_delivery_regex ~r/(?:verwacht\s+bezorgmoment|verwachte\s+bezorging|bezorgmoment|verwacht\s+op)[\s:]+([^<]{6,200}?(?:\d{1,2}[:.]\d{2}\s*[-–—]\s*\d{1,2}[:.]\d{2}\s*uur|\d{1,2}[:.]\d{2}\s*uur|\buur\b))/is
  @delivered_at_regex ~r/is\s+op\s+([a-zà-ÿ]+\s+\d{1,2}\s+[a-zà-ÿ]+(?:\s+\d{4})?\s+om\s+\d{1,2}[:.]\d{2})\s+bezorgd/i
  @signature_regex ~r/handtekening\s+(?:nodig|vereist|is\s+nodig|noodzakelijk)/i

  def parse(email) do
    raw = build_raw(email)
    {street, house_number} = address(raw)
    carrier = carrier(raw)
    tracking_number = tracking_number(raw)
    postcode = postal_code(raw)
    {merchant_name, merchant_legal} = merchant(raw)

    %{
      carrier: carrier,
      tracking_number: tracking_number,
      tracking_url: tracking_url(raw, carrier, tracking_number, postcode),
      order_number: extract_group(@order_regex, raw, 1) |> normalize_order_number(),
      customer_name: customer_name(raw),
      customer_postal_code: postcode,
      customer_street: street,
      customer_house_number: house_number,
      customer_city: city(raw),
      status: status(raw),
      merchant_name: merchant_name,
      merchant_legal_entity: merchant_legal,
      estimated_delivery_text: estimated_delivery_text(raw),
      delivered_at_text: delivered_at_text(raw),
      signature_required: Regex.match?(@signature_regex, raw),
      latest_email_subject: normalize_text(Map.get(email, :subject))
    }
  end

  defp build_raw(email) do
    subject = email.subject || ""
    raw_text = email.raw_text || ""
    raw_html = Map.get(email, :raw_html) || ""

    text_part =
      if usable_text?(raw_text), do: raw_text, else: html_to_text(raw_html)

    [subject, text_part, html_to_text(raw_html)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  # Heuristic: when the plain-text part is mostly CSS/MJML noise (lots of
  # braces, very few sentence-ending punctuation marks), fall back to the HTML
  # body. Anything below this ratio is treated as "real" prose.
  defp usable_text?(text) when is_binary(text) and byte_size(text) > 0 do
    braces = text |> String.graphemes() |> Enum.count(&(&1 in ["{", "}"]))
    size = byte_size(text)
    braces / max(size, 1) < 0.01
  end

  defp usable_text?(_), do: false

  defp html_to_text(""), do: ""
  defp html_to_text(nil), do: ""

  defp html_to_text(html) do
    html
    |> String.replace(~r/<style[^>]*>.*?<\/style>/is, " ")
    |> String.replace(~r/<script[^>]*>.*?<\/script>/is, " ")
    |> String.replace(~r/<!--.*?-->/s, " ")
    |> String.replace(~r/<br\s*\/?>/i, "\n")
    |> String.replace(~r/<\/(p|div|li|tr|h[1-6])>/i, "\n")
    |> String.replace(~r/<[^>]+>/, " ")
    |> decode_entities()
    |> String.replace(~r/[ \t]+/, " ")
    |> String.replace(~r/\n{2,}/, "\n\n")
  end

  defp decode_entities(text) do
    text
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&euro;", "€")
  end

  defp carrier(raw) do
    text = String.downcase(raw)

    cond do
      String.contains?(text, "jvgl") -> "dhl"
      String.contains?(text, "dhl") -> "dhl"
      String.contains?(text, "postnl") -> "postnl"
      String.contains?(text, "3s") -> "postnl"
      String.contains?(text, "ups") -> "ups"
      String.contains?(text, "fedex") -> "fedex"
      true -> "unknown"
    end
  end

  defp status(raw) do
    text = String.downcase(raw)

    cond do
      String.contains?(text, "wordt bezorgd") -> :in_transit
      String.contains?(text, "bezorgd") -> :delivered
      String.contains?(text, "onderweg") -> :in_transit
      String.contains?(text, "voor de deur") -> :in_transit
      String.contains?(text, "klaar voor verzending") -> :shipped
      String.contains?(text, "ligt voor je klaar") -> :shipped
      String.contains?(text, "delivered") -> :delivered
      String.contains?(text, "in transit") -> :in_transit
      String.contains?(text, "shipped") -> :shipped
      true -> :ordered
    end
  end

  defp tracking_number(raw) do
    tracking_number =
      extract(@tracking_regex, raw) ||
        extract_group(@track_and_trace_regex, raw, 1)

    normalize_tracking_number(tracking_number)
  end

  defp tracking_url(raw, carrier, tracking_number, postal_code) do
    TrackingUrl.allowlist_url(raw) ||
      TrackingUrl.build(carrier, tracking_number, postal_code)
  end

  defp customer_name(raw) do
    @customer_name_regexes
    |> Enum.find_value(&extract_group(&1, raw, 1))
    |> normalize_text()
  end

  defp postal_code(raw) do
    @postal_code_regex
    |> extract_group(raw, 1)
    |> normalize_postal_code()
  end

  defp city(raw) do
    @postcode_city_regex
    |> extract_group(raw, 1)
    |> normalize_text()
  end

  defp address(raw) do
    @address_regexes
    |> Enum.find_value(fn regex ->
      case Regex.run(regex, raw) do
        [_full, street, house_number | _] ->
          {normalize_text(street), normalize_house_number(house_number)}

        _ ->
          nil
      end
    end)
    |> case do
      {street, house_number} -> {street, house_number}
      nil -> {nil, nil}
    end
  end

  defp merchant(raw) do
    case Regex.run(@merchant_legal_regex, raw) do
      [_full, name, legal | _] ->
        {normalize_text(name), normalize_text(legal)}

      _ ->
        {nil, nil}
    end
  end

  defp estimated_delivery_text(raw) do
    @expected_delivery_regex
    |> extract_group(raw, 1)
    |> normalize_text()
  end

  defp delivered_at_text(raw) do
    @delivered_at_regex
    |> extract_group(raw, 1)
    |> normalize_text()
  end

  defp extract(regex, raw) do
    case Regex.run(regex, raw) do
      nil -> nil
      [first | _] -> first
    end
  end

  defp extract_group(regex, raw, idx) do
    case Regex.run(regex, raw) do
      nil -> nil
      groups -> Enum.at(groups, idx)
    end
  end

  defp normalize_order_number(nil), do: nil
  defp normalize_order_number(""), do: nil

  defp normalize_order_number(order_number) do
    normalized =
      order_number
      |> String.trim()
      |> String.upcase()

    cond do
      normalized in @invalid_order_numbers -> nil
      not String.match?(normalized, ~r/\d/) -> nil
      true -> normalized
    end
  end

  defp normalize_tracking_number(nil), do: nil
  defp normalize_tracking_number(""), do: nil

  defp normalize_tracking_number(tracking_number) do
    tracking_number
    |> String.trim()
    |> String.upcase()
    |> blank_to_nil()
  end

  defp normalize_text(nil), do: nil
  defp normalize_text(""), do: nil

  defp normalize_text(value) do
    value
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> blank_to_nil()
  end

  defp normalize_postal_code(nil), do: nil

  defp normalize_postal_code(value) do
    value
    |> String.upcase()
    |> String.replace(~r/\s+/, "")
    |> blank_to_nil()
  end

  defp normalize_house_number(nil), do: nil

  defp normalize_house_number(value) do
    value
    |> String.upcase()
    |> String.replace(~r/\s+/, "")
    |> blank_to_nil()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
