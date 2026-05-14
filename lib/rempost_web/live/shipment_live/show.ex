defmodule RempostWeb.ShipmentLive.Show do
  use RempostWeb, :live_view

  def mount(%{"id" => id}, session, socket),
    do:
      {:ok,
       assign(socket,
         shipment: Rempost.Shipments.get_shipment!(id),
         verified?: Rempost.Access.portal_session_verified?(session),
         verification_error: flash_error(socket.assigns.flash)
       )}

  defp flash_error(flash), do: Map.get(flash, "error") || Map.get(flash, :error)
end
