defmodule Rempost.Parsing.DeterministicParser do
  @dhl_regex ~r/\b\d{10,20}\b/
  @order_regex ~r/(order\s*#?\s*)([A-Z0-9\-]+)/i

  def parse(email) do
    raw = [email.subject, email.raw_text] |> Enum.join("\n")

    %{
      carrier: carrier(raw),
      tracking_number: extract(@dhl_regex, raw),
      order_number: extract_group(@order_regex, raw, 2),
      status: status(raw)
    }
  end

  defp carrier(raw) do
    text = String.downcase(raw)

    cond do
      String.contains?(text, "dhl") -> "dhl"
      String.contains?(text, "ups") -> "ups"
      String.contains?(text, "fedex") -> "fedex"
      true -> "unknown"
    end
  end

  defp status(raw) do
    text = String.downcase(raw)

    cond do
      String.contains?(text, "delivered") -> :delivered
      String.contains?(text, "in transit") -> :in_transit
      String.contains?(text, "shipped") -> :shipped
      true -> :ordered
    end
  end

  defp extract(regex, raw), do: Regex.run(regex, raw) |> List.first()

  defp extract_group(regex, raw, idx) do
    case Regex.run(regex, raw) do
      nil -> nil
      groups -> Enum.at(groups, idx)
    end
  end
end
