defmodule RempostWeb.ShipmentLive.Index do
  use RempostWeb, :live_view

  def mount(params, session, socket) do
    if connected?(socket), do: Rempost.Shipments.subscribe()

    q = params |> Map.get("q", "") |> String.trim()
    verified? = Rempost.Access.portal_session_verified?(session)

    {:ok,
     socket
     |> assign(:shipments, [])
     |> assign(:selected_shipment_id, nil)
     |> assign(:q, q)
     |> assign(:lookup_name, q)
     |> assign(:verification_mode, "postcode")
     |> assign(:verification_value, "")
     |> assign(:lookup_status, :idle)
     |> assign(:lookup_error, nil)
     |> assign(:step, initial_step(q, verified?))
     |> assign(:verified?, verified?)
     |> assign(:verification_error, flash_error(socket.assigns.flash))
     |> maybe_load_initial_shipments()}
  end

  def handle_event("identify", %{"lookup" => %{"name" => name}}, socket) do
    name = String.trim(name)

    socket =
      socket
      |> assign(:q, name)
      |> assign(:lookup_name, name)
      |> assign(:lookup_error, nil)

    if name == "" do
      {:noreply,
       socket
       |> assign(:lookup_status, :error)
       |> assign(:lookup_error, "Vul eerst de naam in waarop je besteld hebt.")}
    else
      {:noreply,
       socket
       |> assign(:lookup_status, :idle)
       |> assign(:step, :verify)}
    end
  end

  def handle_event("edit_lookup", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :identify)
     |> assign(:lookup_status, :idle)
     |> assign(:lookup_error, nil)}
  end

  def handle_event(
        "verify_address",
        %{"verification" => %{"mode" => mode, "value" => value}},
        socket
      ) do
    value = String.trim(value)
    mode = normalize_mode(mode)

    socket =
      socket
      |> assign(:verification_mode, mode)
      |> assign(:verification_value, value)
      |> assign(:lookup_error, nil)

    cond do
      socket.assigns.lookup_name == "" ->
        {:noreply,
         socket
         |> assign(:step, :identify)
         |> assign(:lookup_status, :error)
         |> assign(:lookup_error, "Vul eerst de naam in waarop je besteld hebt.")}

      value == "" ->
        {:noreply,
         socket
         |> assign(:lookup_status, :error)
         |> assign(:lookup_error, verification_prompt(mode))}

      true ->
        {:noreply,
         socket
         |> assign(:lookup_status, :success)
         |> assign(:step, :results)
         |> load_public_shipments()}
    end
  end

  def handle_event("select_shipment", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_shipment_id, parse_selected_id(id))}
  end

  def handle_event("back_to_verify", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :verify)
     |> assign(:lookup_status, :idle)
     |> assign(:lookup_error, nil)}
  end

  def handle_info({:shipment_updated, _id}, %{assigns: %{step: :results}} = socket),
    do: {:noreply, load_public_shipments(socket)}

  def handle_info({:shipment_updated, _id}, socket), do: {:noreply, socket}

  defp initial_step("", _verified?), do: :identify
  defp initial_step(_q, true), do: :verify
  defp initial_step(_q, false), do: :verify

  defp maybe_load_initial_shipments(%{assigns: %{step: :results}} = socket),
    do: load_public_shipments(socket)

  defp maybe_load_initial_shipments(socket), do: socket

  defp load_public_shipments(socket) do
    shipments =
      Rempost.Shipments.lookup_public_shipments(
        socket.assigns.lookup_name,
        socket.assigns.verification_mode,
        socket.assigns.verification_value
      )

    socket
    |> assign(:shipments, shipments)
    |> assign(
      :selected_shipment_id,
      selected_shipment_id(shipments, socket.assigns.selected_shipment_id)
    )
  end

  defp flash_error(flash), do: Map.get(flash, "error") || Map.get(flash, :error)

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

  def status_feedback(:success),
    do: {"success", "Adres gecontroleerd. Dit zijn de zendingen die we konden koppelen."}

  def status_feedback(:loading), do: {"loading", "We controleren je gegevens..."}
  def status_feedback(:error), do: {"error", "Controleer de gegevens en probeer het opnieuw."}
  def status_feedback(_status), do: nil

  def format_datetime(nil), do: "Nog niet bekend"

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%d-%m-%Y %H:%M")
  end

  defp normalize_mode("house_number"), do: "house_number"
  defp normalize_mode("postcode"), do: "postcode"
  defp normalize_mode(_mode), do: "postcode"

  defp verification_prompt("house_number"),
    do: "Vul je huisnummer in om de zendingen te controleren."

  defp verification_prompt(_mode), do: "Vul je postcode in om de zendingen te controleren."
end
