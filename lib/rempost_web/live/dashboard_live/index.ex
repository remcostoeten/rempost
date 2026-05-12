defmodule RempostWeb.DashboardLive.Index do
  use RempostWeb, :live_view

  def mount(_params, _session, socket) do
    workspace_id = 1
    if connected?(socket), do: Rempost.Shipments.subscribe(workspace_id)
    shipments = Rempost.Shipments.list_shipments(workspace_id)
    emails = Rempost.Emails.list_recent(workspace_id)
    {:ok, assign(socket, workspace_id: workspace_id, shipments: shipments, emails: emails)}
  end

  def handle_info({:shipment_updated, _id}, socket),
    do:
      {:noreply,
       assign(socket, shipments: Rempost.Shipments.list_shipments(socket.assigns.workspace_id))}
end
