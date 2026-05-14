defmodule RempostWeb.ShipmentLive.Index do
  use RempostWeb, :live_view

  def mount(_params, session, socket) do
    if connected?(socket), do: Rempost.Shipments.subscribe()

    {:ok,
     socket
     |> assign(:shipments, [])
     |> assign(:q, "")
     |> assign(:verified?, Rempost.Access.portal_session_verified?(session))
     |> assign(:verification_error, flash_error(socket.assigns.flash))
     |> load_shipments()}
  end

  def handle_event("search", %{"q" => term}, socket) do
    {:noreply, socket |> assign(:q, term) |> load_shipments()}
  end

  def handle_info({:shipment_updated, _id}, socket), do: {:noreply, load_shipments(socket)}

  defp load_shipments(socket) do
    assign(socket, :shipments, Rempost.Shipments.search_shipments(socket.assigns.q))
  end

  defp flash_error(flash), do: Map.get(flash, "error") || Map.get(flash, :error)
end
