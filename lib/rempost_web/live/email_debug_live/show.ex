defmodule RempostWeb.EmailDebugLive.Show do
  use RempostWeb, :live_view

  alias Rempost.Parsing.DeterministicParser

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
    email = Rempost.Emails.get_email!(id)
    parsed = safe_parse(email)

    socket
    |> assign(:email, email)
    |> assign(:parsed, parsed)
  end

  defp safe_parse(email) do
    DeterministicParser.parse(email)
  rescue
    _ -> nil
  end

  def linkify(nil), do: []
  def linkify(""), do: []

  def linkify(text) do
    pattern =
      ~r/(https?:\/\/[^\s<>"']+|\bJVGL[0-9A-Z]{10,30}\b|\b3S[0-9A-Z]{8,30}\b)/i

    text
    |> String.split(pattern, include_captures: true)
    |> Enum.map(&classify_token/1)
  end

  defp classify_token("https://" <> _ = url), do: {:link, url, url}
  defp classify_token("http://" <> _ = url), do: {:link, url, url}

  defp classify_token(token) do
    cond do
      String.match?(token, ~r/^JVGL[0-9A-Z]{10,30}$/i) ->
        {:link,
         "https://my.dhlecommerce.nl/home/tracktrace/#{String.upcase(token)}?role=consumer-receiver",
         token}

      String.match?(token, ~r/^3S[0-9A-Z]{8,30}$/i) ->
        {:link, "https://postnl.nl/tracktrace/?B=#{String.upcase(token)}&P=&D=NL&T=C", token}

      true ->
        {:text, token}
    end
  end

  def field_or_dash(nil), do: "—"
  def field_or_dash(""), do: "—"
  def field_or_dash(value), do: to_string(value)
end
