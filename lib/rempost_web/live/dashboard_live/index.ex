defmodule RempostWeb.DashboardLive.Index do
  use RempostWeb, :live_view

  def mount(_params, _session, socket) do
    workspace_id = Rempost.Runtime.workspace_id()

    if connected?(socket) do
      Rempost.Emails.subscribe(workspace_id)
    end

    {:ok,
     socket
     |> assign(workspace_id: workspace_id)
     |> assign(search: "")
     |> assign(total_count: 0)
     |> load_emails()}
  end

  def handle_event("search", %{"q" => term}, socket) do
    {:noreply, socket |> assign(search: term) |> load_emails()}
  end

  def handle_info({event, _id}, socket) when event in [:email_ingested, :email_processing, :email_parsed, :email_failed, :email_retry_queued] do
    {:noreply, load_emails(socket)}
  end

  defp load_emails(socket) do
    emails = Rempost.Emails.search_recent(socket.assigns.workspace_id, socket.assigns.search)
    assign(socket, emails: emails, total_count: length(emails))
  end
end
