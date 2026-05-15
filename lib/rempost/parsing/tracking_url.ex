defmodule Rempost.Parsing.TrackingUrl do
  @carrier_domains ~w(
    dhl.com dhl.nl dhlecommerce.nl dhlecommerce.com
    parcel.dhl.com track.dhlparcel.nl my.dhlecommerce.nl
    postnl.nl jouw.postnl.nl
    ups.com fedex.com
  )

  @pixel_hosts ~w(
    sendgrid.net sendgrid.com mailgun.org mailgun.net
    list-manage.com email-list-manage.com
    sendcloud.com sendcloud.sc em.sendcloud.com
  )

  @url_regex ~r{https?://[^\s<>"']+}i

  def allowlist_url(raw) when is_binary(raw) do
    raw
    |> all_urls()
    |> Enum.find(&carrier_url?/1)
  end

  def allowlist_url(_), do: nil

  def build(carrier, tracking_number, postal_code \\ nil)

  def build(_carrier, nil, _postal_code), do: nil

  def build(carrier, tracking_number, postal_code) do
    upcased = tracking_number |> to_string() |> String.upcase()

    cond do
      String.starts_with?(upcased, "JVGL") ->
        "https://my.dhlecommerce.nl/home/tracktrace/#{upcased}?role=consumer-receiver"

      String.starts_with?(upcased, "3S") ->
        postnl_url(upcased, postal_code)

      carrier == "postnl" ->
        postnl_url(upcased, postal_code)

      carrier == "dhl" ->
        "https://my.dhlecommerce.nl/home/tracktrace/#{upcased}?role=consumer-receiver"

      true ->
        nil
    end
  end

  defp postnl_url(code, nil), do: "https://postnl.nl/tracktrace/?B=#{code}&P=&D=NL&T=C"

  defp postnl_url(code, postal_code) do
    pc = postal_code |> to_string() |> String.replace(~r/\s+/, "") |> String.upcase()
    "https://jouw.postnl.nl/track-and-trace/#{code}/NL/#{pc}"
  end

  defp all_urls(raw), do: Regex.scan(@url_regex, raw) |> Enum.map(&List.first/1)

  defp carrier_url?(url) do
    host = host_of(url)
    host != nil and host not in @pixel_hosts and
      Enum.any?(@carrier_domains, fn d -> host == d or String.ends_with?(host, "." <> d) end)
  end

  defp host_of(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> String.downcase(host)
      _ -> nil
    end
  end
end
