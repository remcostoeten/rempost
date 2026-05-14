defmodule Rempost.Orders do
  import Ecto.Query

  alias Rempost.{Orders.Order, Repo}
  alias Rempost.Shipments.Shipment

  def list_customer_summaries(limit \\ 50) do
    Order
    |> join(:left, [o], s in Shipment, on: s.order_id == o.id)
    |> where([o], not is_nil(o.customer_name) and o.customer_name != "")
    |> group_by(
      [o, _s],
      fragment("lower(regexp_replace(btrim(?), '\\s+', ' ', 'g'))", o.customer_name)
    )
    |> select([o, s], %{
      key: fragment("lower(regexp_replace(btrim(?), '\\s+', ' ', 'g'))", o.customer_name),
      name: fragment("max(?)", o.customer_name),
      order_count: count(o.id, :distinct),
      shipment_count: count(s.id)
    })
    |> order_by([o, _s], asc: fragment("max(?)", o.customer_name))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Looks up public order/shipment state by customer identity.

  Requires `:name` (or `:customer_name`) plus either `:postal_code`
  (or `:customer_postal_code`) or a street/house-number pair. Returns orders
  with preloaded shipments, newest first. Insufficient lookup input returns an
  empty list.
  """
  def public_lookup(attrs, limit \\ 25)

  def public_lookup(attrs, limit) when is_map(attrs) do
    attrs
    |> normalize_lookup()
    |> case do
      {:ok, criteria} -> lookup_orders(criteria, limit)
      :error -> []
    end
  end

  def public_lookup(_attrs, _limit), do: []

  defp lookup_orders(criteria, limit) do
    name = "%#{criteria.name}%"

    Order
    |> where([o], ilike(o.customer_name, ^name))
    |> where(^address_match(criteria))
    |> order_by([o], desc: o.updated_at)
    |> limit(^limit)
    |> preload(:shipments)
    |> Repo.all()
  end

  defp address_match(%{postal_code: postal_code}) when is_binary(postal_code) do
    dynamic([o], o.customer_postal_code == ^postal_code)
  end

  defp address_match(%{street: street, house_number: house_number}) do
    street = "%#{street}%"
    dynamic([o], ilike(o.customer_street, ^street) and o.customer_house_number == ^house_number)
  end

  defp normalize_lookup(attrs) do
    name =
      attrs |> first_value([:name, "name", :customer_name, "customer_name"]) |> normalize_text()

    postal_code =
      attrs
      |> first_value([:postal_code, "postal_code", :customer_postal_code, "customer_postal_code"])
      |> normalize_postal_code()

    {street, house_number} =
      attrs
      |> first_value([
        :street,
        "street",
        :customer_street,
        "customer_street",
        :address,
        "address"
      ])
      |> split_address(
        first_value(attrs, [
          :house_number,
          "house_number",
          :customer_house_number,
          "customer_house_number"
        ])
      )

    cond do
      is_nil(name) ->
        :error

      is_binary(postal_code) ->
        {:ok, %{name: name, postal_code: postal_code}}

      is_binary(street) and is_binary(house_number) ->
        {:ok, %{name: name, street: street, house_number: house_number}}

      true ->
        :error
    end
  end

  defp first_value(attrs, keys) do
    Enum.find_value(keys, &Map.get(attrs, &1))
  end

  defp split_address(raw_street, raw_house_number) do
    street = normalize_text(raw_street)
    house_number = normalize_house_number(raw_house_number)

    cond do
      is_binary(street) and is_binary(house_number) ->
        {street, house_number}

      is_binary(street) ->
        case Regex.run(~r/^(.+?)\s+(\d{1,5}\s?[A-Za-z]?(?:-\d+)?)$/, street) do
          [_full, street_part, house_number_part] ->
            {normalize_text(street_part), normalize_house_number(house_number_part)}

          _ ->
            {street, nil}
        end

      true ->
        {nil, house_number}
    end
  end

  defp normalize_text(nil), do: nil
  defp normalize_text(""), do: nil

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> blank_to_nil()
  end

  defp normalize_text(_value), do: nil

  defp normalize_postal_code(nil), do: nil

  defp normalize_postal_code(value) when is_binary(value) do
    value
    |> String.upcase()
    |> String.replace(~r/\s+/, "")
    |> blank_to_nil()
  end

  defp normalize_postal_code(_value), do: nil

  defp normalize_house_number(nil), do: nil

  defp normalize_house_number(value) when is_binary(value) do
    value
    |> String.upcase()
    |> String.replace(~r/\s+/, "")
    |> blank_to_nil()
  end

  defp normalize_house_number(_value), do: nil

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
