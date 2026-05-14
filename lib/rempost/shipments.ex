defmodule Rempost.Shipments do
  import Ecto.Query
  alias Rempost.{Repo, Shipments.Shipment, Tracking.TrackingEvent}

  def topic, do: "shipments"
  def subscribe, do: Phoenix.PubSub.subscribe(Rempost.PubSub, topic())

  def broadcast(event, payload),
    do: Phoenix.PubSub.broadcast(Rempost.PubSub, topic(), {event, payload})

  def list_shipments do
    Shipment
    |> order_by([s], desc: s.updated_at)
    |> preload(:order)
    |> Repo.all()
  end

  def search_shipments(query, limit \\ 100) do
    Shipment
    |> join(:left, [s], o in assoc(s, :order))
    |> maybe_search(query)
    |> order_by([s], desc: s.updated_at)
    |> limit(^limit)
    |> preload([_s, o], order: o)
    |> Repo.all()
  end

  def lookup_public_shipments(name, mode, value, limit \\ 25) do
    with {:ok, address_dynamic} <- public_address_match(mode, value),
         name when is_binary(name) <- normalize_text(name) do
      name = "%#{name}%"

      Shipment
      |> join(:inner, [s], o in assoc(s, :order))
      |> where([_s, o], ilike(o.customer_name, ^name))
      |> where(^address_dynamic)
      |> order_by([s], desc: s.updated_at)
      |> limit(^limit)
      |> preload([_s, o], order: o)
      |> Repo.all()
    else
      _ -> []
    end
  end

  def stats do
    base = Shipment

    %{
      active_count: Repo.aggregate(where(base, [s], s.status != :delivered), :count, :id),
      delayed_count:
        Repo.aggregate(
          where(
            base,
            [s],
            s.status in [:ordered, :shipped, :in_transit] and not is_nil(s.estimated_delivery_at) and
              s.estimated_delivery_at < ^DateTime.utc_now()
          ),
          :count,
          :id
        ),
      delivered_count: Repo.aggregate(where(base, [s], s.status == :delivered), :count, :id)
    }
  end

  def get_shipment!(id),
    do:
      Shipment
      |> where([s], s.id == ^id)
      |> preload([
        :order,
        tracking_events: ^from(t in TrackingEvent, order_by: [asc: t.occurred_at])
      ])
      |> Repo.one!()

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, raw_term) do
    term = "%#{String.downcase(String.trim(raw_term))}%"

    where(
      query,
      [s, o],
      ilike(fragment("lower(?)", s.tracking_number), ^term) or
        ilike(fragment("lower(?)", s.carrier), ^term) or
        ilike(fragment("lower(?)", type(s.status, :string)), ^term) or
        ilike(fragment("lower(?)", o.order_number), ^term) or
        ilike(fragment("lower(?)", o.merchant_name), ^term)
    )
  end

  defp public_address_match(mode, value) do
    case {mode, normalize_text(value)} do
      {"postcode", value} when is_binary(value) ->
        postal_code = normalize_postal_code(value)
        {:ok, dynamic([_s, o], o.customer_postal_code == ^postal_code)}

      {"house_number", value} when is_binary(value) ->
        {street, house_number} = split_address(value)

        if is_binary(street) and is_binary(house_number) do
          street = "%#{street}%"

          {:ok,
           dynamic(
             [_s, o],
             ilike(o.customer_street, ^street) and o.customer_house_number == ^house_number
           )}
        else
          house_number = normalize_house_number(value)
          {:ok, dynamic([_s, o], o.customer_house_number == ^house_number)}
        end

      _ ->
        :error
    end
  end

  defp split_address(value) do
    case Regex.run(~r/^(.+?)\s+(\d{1,5}\s?[A-Za-z]?(?:-\d+)?)$/, value) do
      [_full, street, house_number] ->
        {normalize_text(street), normalize_house_number(house_number)}

      _ ->
        {nil, nil}
    end
  end

  defp normalize_text(nil), do: nil
  defp normalize_text(""), do: nil

  defp normalize_text(value) do
    value
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> blank_to_nil()
  end

  defp normalize_postal_code(value) do
    value
    |> String.upcase()
    |> String.replace(~r/\s+/, "")
  end

  defp normalize_house_number(value) do
    value
    |> String.upcase()
    |> String.replace(~r/\s+/, "")
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
