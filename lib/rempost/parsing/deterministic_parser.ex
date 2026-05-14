defmodule Rempost.Parsing.DeterministicParser do
  @tracking_regex ~r/\b(?:JVGL[0-9A-Z]{10,30}|\d{10,20})\b/
  @order_regex ~r/\b(?:order|bestelling|bestelnummer|ordernummer)\b[^A-Z0-9]{0,12}(?:#\s*)?([A-Z0-9\-]{3,})\b/i
  @track_and_trace_regex ~r/track\s*&?\s*trace.*?([A-Z0-9]{6,})/i
  @tracking_url_regex ~r/https?:\/\/[^\s<>"']*(?:track|trace|parcel|pakket|zending|jvgl|dhl|postnl)[^\s<>"']*/i

  def parse(email) do
    raw = [email.subject, email.raw_text, Map.get(email, :raw_html)] |> Enum.join("\n")

    %{
      carrier: carrier(raw),
      tracking_number: tracking_number(raw),
      tracking_url: tracking_url(raw),
      order_number: extract_group(@order_regex, raw, 1) |> normalize_order_number(),
      status: status(raw)
    }
  end

  defp carrier(raw) do
    text = String.downcase(raw)

    cond do
      String.contains?(text, "jvgl") -> "dhl"
      String.contains?(text, "dhl") -> "dhl"
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
    extract(@tracking_regex, raw) ||
      extract_group(@track_and_trace_regex, raw, 1)
  end

  defp tracking_url(raw), do: extract(@tracking_url_regex, raw)

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
    order_number
    |> String.trim()
    |> String.upcase()
  end
end
