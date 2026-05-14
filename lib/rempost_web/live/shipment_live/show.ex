defmodule RempostWeb.ShipmentLive.Show do
  use RempostWeb, :live_view

  def mount(%{"id" => id}, _session, socket),
    do: {:ok, assign(socket, shipment: Rempost.Shipments.get_shipment!(id))}
end
