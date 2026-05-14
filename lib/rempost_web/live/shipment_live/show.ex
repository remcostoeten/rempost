defmodule RempostWeb.ShipmentLive.Show do
  use RempostWeb, :live_view

  def mount(%{"id" => id}, _session, socket),
    do:
      {:ok,
       assign(socket,
         shipment: Rempost.Shipments.get_shipment!(id),
         verified?: false,
         verification_error: nil
       )}

  def handle_event("verify", %{"answer" => answer}, socket) do
    if Rempost.Access.portal_verified?(answer) do
      {:noreply, assign(socket, verified?: true, verification_error: nil)}
    else
      {:noreply, assign(socket, verification_error: "That answer did not match.")}
    end
  end
end
