defmodule RempostWeb.ShipmentLive.Index do
  use RempostWeb, :live_view

  def mount(params, session, socket) do
    if connected?(socket), do: Rempost.Shipments.subscribe()

    name = params |> Map.get("name", "") |> String.trim()

    master_access? =
      Rempost.Access.portal_master_session_verified?(session) && params["step"] != "start"

    {:ok,
     socket
     |> assign(:shipments, [])
     |> assign(:customer_summaries, [])
     |> assign(:selected_customer, params |> Map.get("customer", "") |> String.trim())
     |> assign(:search_query, params |> Map.get("search", "") |> String.trim())
     |> assign(:selected_shipment_id, nil)
     |> assign(:query, name)
     |> assign(:suggestions, [])
     |> assign(:candidates, [])
     |> assign(:lookup_name, name)
     |> assign(:lookup_error, nil)
     |> assign(:master_access?, master_access?)
     |> assign(:step, initial_step(name, master_access?))
     |> maybe_load_initial_shipments()}
  end

  def handle_params(%{"step" => "start"}, _uri, socket) do
    {:noreply,
     socket
     |> assign(:shipments, [])
     |> assign(:customer_summaries, [])
     |> assign(:selected_customer, "")
     |> assign(:search_query, "")
     |> assign(:selected_shipment_id, nil)
     |> assign(:query, "")
     |> assign(:suggestions, [])
     |> assign(:candidates, [])
     |> assign(:lookup_name, "")
     |> assign(:lookup_error, nil)
     |> assign(:master_access?, false)
     |> assign(:step, :lookup)}
  end

  def handle_params(%{"name" => name} = params, _uri, socket) when name != "" do
    {:noreply,
     socket
     |> assign(:query, name)
     |> assign(:lookup_name, name)
     |> assign(:selected_customer, params |> Map.get("customer", "") |> String.trim())
     |> assign(:search_query, params |> Map.get("search", "") |> String.trim())
     |> assign(:lookup_error, nil)
     |> assign(:suggestions, [])
     |> assign(:candidates, [])
     |> assign(:step, :results)
     |> load_public_shipments()}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("suggest", %{"value" => q}, socket) do
    suggestions = Rempost.Shipments.suggest_recipients(q)
    {:noreply, socket |> assign(:query, q) |> assign(:suggestions, suggestions)}
  end

  def handle_event("pick", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: ~p"/portal?#{%{name: name}}")}
    end
  end

  def handle_event("submit", %{"lookup" => %{"name" => name}}, socket) do
    name = String.trim(name)

    cond do
      name == "" ->
        {:noreply,
         socket
         |> assign(:lookup_error, "Vul je naam in om verder te gaan.")
         |> assign(:candidates, [])}

      true ->
        case Rempost.Shipments.suggest_recipients(name) do
          [] ->
            {:noreply,
             socket
             |> assign(:lookup_error,
               "Geen pakketten gevonden onder die naam. Controleer de spelling.")
             |> assign(:candidates, [])}

          [%{name: exact}] ->
            {:noreply, push_patch(socket, to: ~p"/portal?#{%{name: exact}}")}

          [_ | _] = many ->
            {:noreply,
             socket
             |> assign(:lookup_error, nil)
             |> assign(:candidates, Enum.map(many, & &1.name))}
        end
    end
  end

  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:query, "")
     |> assign(:suggestions, [])
     |> assign(:candidates, [])
     |> assign(:lookup_error, nil)
     |> assign(:step, :lookup)
     |> push_patch(to: ~p"/portal?step=start")}
  end

  def handle_event("select_shipment", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_shipment_id, parse_selected_id(id))}
  end

  def handle_event("search_results", %{"filters" => %{"search" => search}}, socket) do
    search = String.trim(search)

    {:noreply,
     socket
     |> assign(:search_query, search)
     |> push_patch(
       to:
         ~p"/portal?#{%{master: "1", customer: socket.assigns.selected_customer, search: search}}"
     )}
  end

  def handle_event("master_access", %{"master" => %{"password" => password}}, socket) do
    password = String.trim(password)

    if Rempost.Access.portal_master_verified?(password) do
      {:noreply,
       socket
       |> assign(:master_access?, true)
       |> assign(:step, :results)
       |> assign(:lookup_error, nil)
       |> assign(:lookup_name, "Alle zendingen")
       |> assign(:selected_customer, "")
       |> assign(:search_query, "")
       |> load_public_shipments()
       |> push_patch(to: ~p"/portal?#{%{master: "1"}}")}
    else
      {:noreply, assign(socket, :lookup_error, "Master password klopt niet.")}
    end
  end

  def handle_info({:shipment_updated, _id}, %{assigns: %{step: :results}} = socket),
    do: {:noreply, load_public_shipments(socket)}

  def handle_info({:shipment_updated, _id}, socket), do: {:noreply, socket}

  defp initial_step(_name, true), do: :results
  defp initial_step("", _master?), do: :lookup
  defp initial_step(_name, false), do: :results

  defp maybe_load_initial_shipments(%{assigns: %{step: :results}} = socket),
    do: load_public_shipments(socket)

  defp maybe_load_initial_shipments(socket), do: socket

  defp load_public_shipments(socket) do
    shipments =
      if socket.assigns.master_access? do
        Rempost.Shipments.list_shipments(
          customer_name: socket.assigns.selected_customer,
          search: socket.assigns.search_query
        )
      else
        Rempost.Shipments.lookup_by_recipient(socket.assigns.lookup_name)
      end

    socket
    |> assign(:shipments, shipments)
    |> assign(:customer_summaries, load_customer_summaries(socket))
    |> assign(
      :selected_shipment_id,
      selected_shipment_id(shipments, socket.assigns.selected_shipment_id)
    )
  end

  defp load_customer_summaries(%{assigns: %{master_access?: true}}) do
    Rempost.Orders.list_customer_summaries()
  end

  defp load_customer_summaries(_socket), do: []

  defp selected_shipment_id([], _selected_id), do: nil

  defp selected_shipment_id(shipments, selected_id) do
    if Enum.any?(shipments, &(&1.id == selected_id)) do
      selected_id
    else
      shipments |> List.first() |> Map.get(:id)
    end
  end

  defp parse_selected_id(id) when is_integer(id), do: id

  defp parse_selected_id(id) do
    case Integer.parse(to_string(id)) do
      {id, ""} -> id
      _ -> nil
    end
  end

  def selected_shipment(shipments, selected_id) do
    Enum.find(shipments, &(&1.id == selected_id))
  end

  def shipment_count_label([_shipment]), do: "1 pakket gevonden"
  def shipment_count_label(shipments), do: "#{length(shipments)} pakketten gevonden"

  def total_order_count(customer_summaries) do
    Enum.reduce(customer_summaries, 0, &(&1.order_count + &2))
  end

  def master_results_url(search_query) do
    ~p"/portal?#{%{step: "results", master: "1", search: search_query}}"
  end

  def customer_filter_url(customer_name, search_query) do
    ~p"/portal?#{%{step: "results", master: "1", customer: customer_name, search: search_query}}"
  end

  def identity_label(_lookup_name, true), do: "Master toegang"
  def identity_label(lookup_name, false), do: lookup_name

  def shipment_title(shipment) do
    merchant =
      shipment
      |> shipment_merchant()
      |> merchant_label()

    case merchant do
      "DHL eCommerce" -> "Pakket via DHL eCommerce"
      "Sendcloud" -> "Pakket via Sendcloud"
      merchant -> merchant
    end
  end

  def shipment_subtitle(shipment) do
    [
      carrier_label(shipment.carrier),
      order_reference(shipment)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  def shipment_merchant(shipment), do: shipment.order && shipment.order.merchant_name

  def merchant_label(nil), do: "Pakket"

  def merchant_label(merchant_name) do
    value = merchant_name |> to_string() |> String.trim()
    downcased = String.downcase(value)

    cond do
      downcased =~ "xxlnutrition" -> "XXL Nutrition"
      downcased =~ "dhlecommerce" -> "DHL eCommerce"
      downcased =~ "sendcloud" -> "Sendcloud"
      downcased =~ "dhl" -> "DHL"
      String.contains?(value, "@") -> value |> email_domain_label() |> humanize_token()
      true -> value
    end
  end

  def merchant_initials(nil), do: "?"

  def merchant_initials(merchant_name) do
    merchant_name
    |> merchant_label()
    |> String.replace(~r/[^a-zA-ZÀ-ÿ0-9]/u, " ")
    |> String.split(~r/\s+/, trim: true)
    |> case do
      [] -> "?"
      [word] -> word |> String.slice(0, 2) |> String.upcase()
      [first, second | _] -> String.upcase(String.first(first) <> String.first(second))
    end
  end

  def carrier_label(nil), do: "Vervoerder onbekend"
  def carrier_label("dhl"), do: "DHL"
  def carrier_label("postnl"), do: "PostNL"
  def carrier_label("ups"), do: "UPS"
  def carrier_label("fedex"), do: "FedEx"
  def carrier_label("unknown"), do: "Vervoerder onbekend"
  def carrier_label(carrier), do: carrier |> to_string() |> humanize_token()

  def order_reference(%{order: %{order_number: order_number}}) do
    case display_order_number(order_number) do
      nil -> nil
      order_number -> "Order #{order_number}"
    end
  end

  def order_reference(_shipment), do: nil

  def tracking_tail(nil), do: nil

  def tracking_tail(tracking_number) do
    tracking_number
    |> to_string()
    |> String.upcase()
    |> String.slice(-8, 8)
  end

  def tracking_label(nil), do: "Onbekend"

  def tracking_label(tracking_number) do
    tracking_number
    |> to_string()
    |> String.upcase()
  end

  def status_description(:ordered), do: "We hebben de zending uit de mails gehaald."
  def status_description(:shipped), do: "De zending is aangemeld bij de vervoerder."
  def status_description(:in_transit), do: "Het pakket is onderweg naar het bezorgadres."
  def status_description(:delivered), do: "Het pakket is bezorgd."
  def status_description(:failed), do: "Deze zending heeft aandacht nodig."
  def status_description(_status), do: "Status bijgewerkt vanuit de doorgestuurde mails."

  def status_label(:ordered), do: "Besteld"
  def status_label(:shipped), do: "Verzonden"
  def status_label(:in_transit), do: "Onderweg"
  def status_label(:delivered), do: "Bezorgd"
  def status_label(:failed), do: "Aandacht nodig"
  def status_label(status), do: status |> to_string() |> String.replace("_", " ")

  def status_classes(:delivered), do: "border-emerald-200 bg-emerald-50 text-emerald-700"
  def status_classes(:failed), do: "border-red-200 bg-red-50 text-red-700"
  def status_classes(:in_transit), do: "border-blue-200 bg-blue-50 text-blue-700"
  def status_classes(:shipped), do: "border-amber-200 bg-amber-50 text-amber-700"
  def status_classes(_status), do: "border-zinc-200 bg-zinc-100 text-zinc-700"

  def timeline_steps do
    [
      {:ordered, "Besteld"},
      {:shipped, "Verzonden"},
      {:in_transit, "Onderweg"},
      {:delivered, "Bezorgd"}
    ]
  end

  def timeline_step_classes(current_status, step_status) do
    if timeline_step_complete?(current_status, step_status) do
      "border-[#db8142] bg-[#db8142] text-white"
    else
      "border-[#ded6ca] bg-white text-[#aaa39b]"
    end
  end

  def timeline_line_classes(current_status, step_status) do
    if timeline_step_complete?(current_status, step_status),
      do: "bg-[#db8142]",
      else: "bg-[#ded6ca]"
  end

  def format_datetime(nil), do: "Nog niet bekend"

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%d-%m-%Y %H:%M")
  end

  def short_date(nil), do: "--"

  def short_date(datetime) do
    Calendar.strftime(datetime, "%d-%m")
  end

  defp display_order_number(nil), do: nil
  defp display_order_number(""), do: nil
  defp display_order_number("unknown-" <> _id), do: nil
  defp display_order_number(order_number), do: order_number

  defp email_domain_label(email) do
    email
    |> String.split("@")
    |> List.last()
    |> to_string()
    |> String.replace(~r/\.(com|nl|be|de)$/i, "")
  end

  defp humanize_token(value) do
    value
    |> to_string()
    |> String.replace(~r/[-_.]+/, " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp timeline_step_complete?(:failed, _step_status), do: false

  defp timeline_step_complete?(current_status, step_status) do
    statuses = Enum.map(timeline_steps(), &elem(&1, 0))
    current_index = Enum.find_index(statuses, &(&1 == current_status)) || 0
    step_index = Enum.find_index(statuses, &(&1 == step_status)) || 0
    step_index <= current_index
  end

  def master_access_placeholder, do: "Master password"

  # Temporary stubs — referenced by template until Task 8 rewrites index.html.heex
  def step_active?(step_key, step), do: step_active_dot?(step_key, step)
  def address_label("house_number"), do: "Huisnummer"
  def address_label(_mode), do: "Postcode"
  def address_placeholder("house_number"), do: "Bijvoorbeeld 212"
  def address_placeholder(_mode), do: "Bijvoorbeeld 2035 PH"
  def address_toggle("house_number"), do: {"postcode", "Gebruik postcode in plaats daarvan"}

  def address_toggle(_mode),
    do: {"house_number", "Ik weet mijn postcode niet, maar wel mijn huisnummer"}

  def step_active_dot?(:lookup, _step), do: true
  def step_active_dot?(:results, :results), do: true
  def step_active_dot?(_, _), do: false
end
