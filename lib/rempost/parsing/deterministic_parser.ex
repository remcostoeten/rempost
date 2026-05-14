defmodule Rempost.Parsing.DeterministicParser do
  @tracking_regex ~r/\b(?:JVGL[0-9A-Z]{10,30}|3S[0-9A-Z]{8,30}|\d{10,20})\b/i
  @order_regex ~r/\b(?:order|bestelling|bestelnummer|ordernummer)\b[^A-Z0-9]{0,12}(?:#\s*)?([A-Z0-9\-]{3,})\b/i
  @track_and_trace_regex ~r/track\s*&?\s*trace.*?([A-Z0-9]{6,})/i
  @tracking_url_regex ~r/https?:\/\/[^\s<>"']*(?:track|trace|parcel|pakket|zending|jvgl|dhl|postnl)[^\s<>"']*/i
  @invalid_order_numbers ~w(BEZORGD DIV KLAAR LATER ONDERWEG VERZENDING)
  @customer_name_regexes [
    ~r/(?:naam|name)\s*:\s*([^\n\r<]+)/i,
    ~r/(?:Nederland|Netherlands)\s+([A-ZÀ-ÿ][^\n\r,<]+),/i,
    ~r/(?:beste|dear)\s+([A-ZÀ-ÿ][^\n\r,<]+)/i,
    ~r/^\s*([A-ZÀ-ÿ][A-ZÀ-ÿ' .-]+),\s*$/im
  ]
  @postal_code_regex ~r/\b([1-9][0-9]{3}\s?[A-Z]{2})\b/i
  @address_regexes [
    ~r/(?:adres|address)\s*:\s*([^\n\r,]+?)\s+(\d{1,5}\s?[A-Za-z]?(?:-\d+)?)\b/i,
    ~r/^\s*([A-ZÀ-ÿ][A-ZÀ-ÿ0-9' .-]{2,}?)\s+(\d{1,5}\s?[A-Za-z]?(?:-\d+)?)\s*$/im
  ]

  def parse(email) do
    raw = [email.subject, email.raw_text, Map.get(email, :raw_html)] |> Enum.join("\n")
    {street, house_number} = address(raw)

    %{
      carrier: carrier(raw),
      tracking_number: tracking_number(raw),
      tracking_url: tracking_url(raw),
      order_number: extract_group(@order_regex, raw, 1) |> normalize_order_number(),
      customer_name: customer_name(raw),
      customer_postal_code: postal_code(raw),
      customer_street: street,
      customer_house_number: house_number,
      status: status(raw)
    }
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
      String.contains?(text, "klaar voor verzending") -> :shipped
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

  defp tracking_url(raw), do: extract(@tracking_url_regex, raw)

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
