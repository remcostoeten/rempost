defmodule RempostWeb.EmailDebugLive.Show do
  use RempostWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Rempost.Emails.subscribe()

    {:ok,
     socket
     |> assign_email(id)
     |> assign(:retry_error, nil)}
  end

  def handle_event("retry_parse", _params, socket) do
    case Rempost.Emails.retry_parsing(socket.assigns.email) do
      {:ok, _email} ->
        {:noreply, socket |> assign(:retry_error, nil) |> assign_email(socket.assigns.email.id)}

      {:error, reason} ->
        {:noreply, assign(socket, :retry_error, inspect(reason))}
    end
  end

  def handle_info({event, email_id}, socket)
      when event in [:email_processing, :email_parsed, :email_failed, :email_retry_queued] do
    if socket.assigns.email.id == email_id do
      {:noreply, assign_email(socket, email_id)}
    else
      {:noreply, socket}
    end
  end

  defp assign_email(socket, id) do
    assign(socket, :email, Rempost.Emails.get_email!(id))
  end
end
