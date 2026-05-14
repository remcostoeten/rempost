defmodule Rempost.Shipments do
  import Ecto.Query

  alias Rempost.{
    Emails.InboundEmail,
    Orders.Order,
    Repo,
    Shipments.Shipment,
    Tracking.TrackingEvent
  }

  def topic, do: "shipments"
  def subscribe, do: Phoenix.PubSub.subscribe(Rempost.PubSub, topic())

  def broadcast(event, payload),
    do: Phoenix.PubSub.broadcast(Rempost.PubSub, topic(), {event, payload})

  def list_shipments(opts \\ []) do
    Shipment
    |> join(:left, [s], o in assoc(s, :order))
    |> join(:left, [_s, o], e in InboundEmail, on: e.id == o.inbound_email_id)
    |> maybe_filter_customer(Keyword.get(opts, :customer_name))
    |> maybe_semantic_search(Keyword.get(opts, :search))
    |> order_by([s], desc: s.updated_at)
    |> preload([_s, o, _e], order: o)
    |> Repo.all()
  end

  @suggest_default_limit 8

  def suggest_recipients(query, limit \\ @suggest_default_limit) do
    trimmed = query |> to_string() |> String.trim()

    if String.length(trimmed) < 2 do
      []
    else
      folded = String.downcase(trimmed)

      Shipment
      |> join(:inner, [s], o in assoc(s, :order))
      |> where(
        [_s, o],
        fragment("unaccent(lower(?)) LIKE '%' || unaccent(?) || '%'", o.customer_name, ^folded)
      )
      |> where([_s, o], not is_nil(o.customer_name) and o.customer_name != "")
      |> group_by([_s, o], o.customer_name)
      |> select([s, o], %{
        name: o.customer_name,
        shipment_count: count(s.id),
        latest_activity_at: max(s.updated_at)
      })
      |> order_by([s, _o], desc: max(s.updated_at))
      |> limit(^limit)
      |> Repo.all()
    end
  end

  def lookup_by_recipient(name) when is_binary(name) do
    trimmed = String.trim(name)

    if trimmed == "" do
      []
    else
      folded = String.downcase(trimmed)

      Shipment
      |> join(:inner, [s], o in assoc(s, :order))
      |> where(
        [_s, o],
        fragment("unaccent(lower(?)) = unaccent(?)", o.customer_name, ^folded)
      )
      |> order_by([s], desc: s.updated_at)
      |> preload([_s, o], order: o)
      |> Repo.all()
    end
  end

  def lookup_by_recipient(_), do: []

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
    with {:ok, order_address_dynamic} <- public_address_match(mode, value, :order),
         {:ok, shipment_address_dynamic} <- public_address_match(mode, value, :shipment),
         name when is_binary(name) <- normalize_text(name) do
      term = "%#{name}%"
      verified_names = verified_customer_names(term, order_address_dynamic)

      Shipment
      |> join(:inner, [s], o in assoc(s, :order))
      |> where([_s, o], o.customer_name in ^verified_names)
      |> where(^public_shipment_scope(shipment_address_dynamic))
      |> order_by([s], desc: s.updated_at)
      |> limit(^limit)
      |> preload([_s, o], order: o)
      |> Repo.all()
      |> Enum.uniq_by(&normalized_tracking_number/1)
    else
      _ -> []
    end
  end

  defp verified_customer_names(term, address_dynamic) do
    Order
    |> where([o], ilike(o.customer_name, ^term))
    |> where(^address_dynamic)
    |> distinct(true)
    |> select([o], o.customer_name)
    |> Repo.all()
  end

  defp normalized_tracking_number(%Shipment{tracking_number: tracking_number}) do
    tracking_number
    |> to_string()
    |> String.upcase()
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

  defp maybe_filter_customer(query, nil), do: query
  defp maybe_filter_customer(query, ""), do: query

  defp maybe_filter_customer(query, customer_name) do
    customer_key = normalize_customer_key(customer_name)

    where(
      query,
      [_s, o],
      fragment("lower(regexp_replace(btrim(?), '\\s+', ' ', 'g'))", o.customer_name) ==
        ^customer_key
    )
  end

  defp maybe_semantic_search(query, nil), do: query
  defp maybe_semantic_search(query, ""), do: query

  defp maybe_semantic_search(query, raw_term) do
    terms = search_terms(raw_term)

    where(query, [s, o, e], ^semantic_search_dynamic(terms))
  end

  defp semantic_search_dynamic(terms) do
    Enum.reduce(terms, false, fn term, dynamic ->
      like = "%#{term}%"
      postal_code = normalize_postal_code(term)

      dynamic(
        [s, o, e],
        ^dynamic or
          ilike(fragment("lower(?)", s.tracking_number), ^like) or
          ilike(fragment("lower(?)", s.carrier), ^like) or
          ilike(fragment("lower(?)", s.tracking_url), ^like) or
          ilike(fragment("lower(?)", type(s.status, :string)), ^like) or
          ilike(fragment("lower(?)", o.order_number), ^like) or
          ilike(fragment("lower(?)", o.merchant_name), ^like) or
          ilike(fragment("lower(?)", o.customer_name), ^like) or
          ilike(fragment("lower(?)", o.customer_street), ^like) or
          ilike(fragment("lower(?)", o.customer_house_number), ^like) or
          o.customer_postal_code == ^postal_code or
          ilike(fragment("lower(?)", e.from_email), ^like) or
          ilike(fragment("lower(?)", e.subject), ^like) or
          ilike(fragment("lower(?)", e.raw_text), ^like) or
          ilike(fragment("lower(?)", e.message_id), ^like) or
          ilike(fragment("lower(?)", type(e.status, :string)), ^like) or
          ilike(fragment("to_char(?, 'YYYY-MM-DD HH24:MI')", e.received_at), ^like) or
          ilike(fragment("to_char(?, 'DD-MM-YYYY HH24:MI')", e.received_at), ^like) or
          ilike(fragment("to_char(?, 'YYYY-MM-DD HH24:MI')", s.updated_at), ^like) or
          ilike(fragment("to_char(?, 'DD-MM-YYYY HH24:MI')", s.updated_at), ^like)
      )
    end)
  end

  defp public_address_match(mode, value, binding) do
    case {mode, normalize_text(value)} do
      {"postcode", value} when is_binary(value) ->
        postal_code = normalize_postal_code(value)
        {:ok, address_dynamic(binding, :postal_code, postal_code)}

      {"house_number", value} when is_binary(value) ->
        {street, house_number} = split_address(value)

        if is_binary(street) and is_binary(house_number) do
          street = "%#{street}%"
          {:ok, address_dynamic(binding, :street_house_number, {street, house_number})}
        else
          house_number = normalize_house_number(value)
          {:ok, address_dynamic(binding, :house_number, house_number)}
        end

      _ ->
        :error
    end
  end

  defp address_dynamic(:order, :postal_code, postal_code),
    do: dynamic([o], o.customer_postal_code == ^postal_code)

  defp address_dynamic(:order, :street_house_number, {street, house_number}),
    do:
      dynamic([o], ilike(o.customer_street, ^street) and o.customer_house_number == ^house_number)

  defp address_dynamic(:order, :house_number, house_number),
    do: dynamic([o], o.customer_house_number == ^house_number)

  defp address_dynamic(:shipment, :postal_code, postal_code),
    do: dynamic([_s, o], o.customer_postal_code == ^postal_code)

  defp address_dynamic(:shipment, :street_house_number, {street, house_number}),
    do:
      dynamic(
        [_s, o],
        ilike(o.customer_street, ^street) and o.customer_house_number == ^house_number
      )

  defp address_dynamic(:shipment, :house_number, house_number),
    do: dynamic([_s, o], o.customer_house_number == ^house_number)

  defp public_shipment_scope(address_dynamic) do
    dynamic(
      [_s, o],
      ^address_dynamic or
        (is_nil(o.customer_postal_code) and is_nil(o.customer_street) and
           is_nil(o.customer_house_number))
    )
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

  defp normalize_customer_key(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> String.downcase()
  end

  defp search_terms(raw_term) do
    raw_term
    |> normalize_search_text()
    |> expand_semantic_terms()
    |> Enum.uniq()
  end

  defp normalize_search_text(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp expand_semantic_terms(""), do: []

  defp expand_semantic_terms(term) do
    [term | semantic_aliases(term)]
  end

  defp semantic_aliases(term) do
    cond do
      term in ["bezorgd", "geleverd", "delivered", "afgeleverd"] -> ["delivered"]
      term in ["onderweg", "in transit", "transport"] -> ["in_transit", "shipped"]
      term in ["verzonden", "shipped", "verstuurd"] -> ["shipped", "in_transit"]
      term in ["besteld", "order", "ordered", "placed"] -> ["ordered", "placed"]
      term in ["mislukt", "failed", "fout", "aandacht"] -> ["failed"]
      term in ["tracking", "track", "pakket", "shipment", "zending"] -> ["tracking", "shipment"]
      true -> []
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
