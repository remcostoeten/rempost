defmodule RempostWeb.ShipmentLive.Index do
  use RempostWeb, :live_view

  def mount(_params, _session, socket),
    do: {:ok, assign(socket, shipments: Rempost.Shipments.list_shipments(1), q: "")}
end
