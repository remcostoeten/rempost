defmodule RempostWeb.ShipmentLive.Index do
  use RempostWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket), do: Rempost.Shipments.subscribe()

    {:ok,
     socket
     |> assign(:shipments, [])
     |> assign(:q, "")
     |> assign(:verified?, false)
     |> assign(:verification_error, nil)
     |> load_shipments()}
  end

  def handle_event("search", %{"q" => term}, socket) do
    {:noreply, socket |> assign(:q, term) |> load_shipments()}
  end

  def handle_event("verify", %{"answer" => answer}, socket) do
    if Rempost.Access.portal_verified?(answer) do
      {:noreply, assign(socket, verified?: true, verification_error: nil)}
    else
      {:noreply, assign(socket, verification_error: "That answer did not match.")}
    end
  end

  def handle_info({:shipment_updated, _id}, socket), do: {:noreply, load_shipments(socket)}

  defp load_shipments(socket) do
    assign(socket, :shipments, Rempost.Shipments.search_shipments(socket.assigns.q))
  end
end
