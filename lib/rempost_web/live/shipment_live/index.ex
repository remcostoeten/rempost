defmodule RempostWeb.ShipmentLive.Index do
  use RempostWeb, :live_view

  def mount(params, session, socket) do
    if connected?(socket), do: Rempost.Shipments.subscribe()

    q = params |> Map.get("q", "") |> String.trim()
    verified? = Rempost.Access.portal_session_verified?(session)

    {:ok,
     socket
     |> assign(:shipments, [])
     |> assign(:q, q)
     |> assign(:lookup_name, q)
     |> assign(:step, initial_step(q, verified?))
     |> assign(:verified?, verified?)
     |> assign(:verification_error, flash_error(socket.assigns.flash))
     |> load_shipments()}
  end

  def handle_event("identify", %{"lookup" => %{"name" => name}}, socket) do
    name = String.trim(name)

    {:noreply,
     socket
     |> assign(:q, name)
     |> assign(:lookup_name, name)
     |> assign(:step, if(socket.assigns.verified?, do: :results, else: :verify))
     |> load_shipments()}
  end

  def handle_event("edit_lookup", _params, socket) do
    {:noreply, assign(socket, :step, :identify)}
  end

  def handle_event("search", %{"q" => term}, socket) do
    {:noreply, socket |> assign(:q, term) |> assign(:lookup_name, term) |> load_shipments()}
  end

  def handle_info({:shipment_updated, _id}, socket), do: {:noreply, load_shipments(socket)}

  defp initial_step("", _verified?), do: :identify
  defp initial_step(_q, true), do: :results
  defp initial_step(_q, false), do: :verify

  defp portal_return_to(""), do: ~p"/portal"
  defp portal_return_to(q), do: ~p"/portal?#{[q: q]}"

  defp load_shipments(socket) do
    assign(socket, :shipments, Rempost.Shipments.search_shipments(socket.assigns.q))
  end

  defp flash_error(flash), do: Map.get(flash, "error") || Map.get(flash, :error)
end
