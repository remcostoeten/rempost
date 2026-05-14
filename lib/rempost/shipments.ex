defmodule Rempost.Shipments do
  import Ecto.Query

  alias Rempost.{
    Emails.InboundEmail,
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

  defp normalize_postal_code(value) do
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

end
