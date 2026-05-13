defmodule RempostWeb.DashboardLive.Index do
  use RempostWeb, :live_view

  def mount(_params, _session, socket) do
    workspace_id = 1

    if connected?(socket) do
      Rempost.Shipments.subscribe(workspace_id)
      Rempost.Emails.subscribe(workspace_id)
    end

    {:ok, load_dashboard(socket, workspace_id)}
  end

  def handle_info({:shipment_updated, _id}, socket), do: {:noreply, refresh(socket)}
  def handle_info({event, _id}, socket) when event in [:email_ingested, :email_processing, :email_parsed, :email_failed, :email_retry_queued], do: {:noreply, refresh(socket)}

  defp refresh(socket), do: load_dashboard(socket, socket.assigns.workspace_id)

  defp load_dashboard(socket, workspace_id) do
    shipments = Rempost.Shipments.list_shipments(workspace_id)
    shipment_stats = Rempost.Shipments.stats(workspace_id)
    emails = Rempost.Emails.list_recent(workspace_id)
    email_stats = Rempost.Emails.stats(workspace_id)

    assign(socket,
      workspace_id: workspace_id,
      shipments: shipments,
      shipment_stats: shipment_stats,
      emails: emails,
      email_stats: email_stats
    )
  end
end
