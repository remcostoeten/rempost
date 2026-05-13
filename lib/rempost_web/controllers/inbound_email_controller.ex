defmodule RempostWeb.InboundEmailController do
  use RempostWeb, :controller
  require Logger

  @required_fields ~w(message_id from_email raw_text)a


  def index(conn, params) do
    with :ok <- authorize(conn, params) do
      workspace_id = params["workspace_id"] || Rempost.Runtime.workspace_id()
      q = params["q"]
      limit = parse_limit(params["limit"])

      emails =
        Rempost.Emails.search_recent(workspace_id, q, limit)
        |> Enum.map(fn email ->
          %{
            id: email.id,
            message_id: email.message_id,
            from_email: email.from_email,
            subject: email.subject,
            status: email.status,
            received_at: email.received_at,
            inserted_at: email.inserted_at
          }
        end)

      json(conn, %{workspace_id: workspace_id, count: length(emails), limit: limit, emails: emails})
    else
      {:error, :unauthorized} ->
        json(conn |> put_status(:unauthorized), %{error: "unauthorized"})
    end
  end

  def create(conn, params) do
    with :ok <- authorize(conn, params) do
      normalized = normalize_cloudflare_params(params)

      with :ok <- validate_required(normalized),
           {:ok, received_at} <- parse_received_at(normalized["received_at"]) do
        attrs = %{
          workspace_id: normalized["workspace_id"] || Rempost.Runtime.workspace_id(),
          message_id: normalized["message_id"],
          from_email: normalized["from_email"],
          subject: normalized["subject"],
          received_at: received_at,
          raw_headers: normalized["headers"] || %{},
          raw_text: normalized["raw_text"] || "",
          raw_html: normalized["raw_html"]
        }

        case Rempost.Emails.ingest_email(attrs) do
          {:ok, email} ->
            json(conn |> put_status(:accepted), %{id: email.id, status: "queued"})

          {:error, reason} ->
            Logger.warning("Inbound email ingestion failed", reason: inspect(reason), workspace_id: attrs.workspace_id, message_id: attrs.message_id)
            json(conn |> put_status(:unprocessable_entity), %{error: "unable_to_ingest_email"})
        end
      else
        {:error, :missing_required_fields} ->
          json(conn |> put_status(:bad_request), %{error: "missing_required_fields", required: Enum.map(@required_fields, &Atom.to_string/1)})

        {:error, :invalid_received_at} ->
          json(conn |> put_status(:bad_request), %{error: "invalid_received_at", format: "ISO8601"})
      end
    else
      {:error, :unauthorized} ->
        json(conn |> put_status(:unauthorized), %{error: "unauthorized"})
    end
  end

  defp authorize(conn, params) do
    expected = Application.get_env(:rempost, :inbound_token, "")

    provided =
      get_req_header(conn, "x-rempost-token")
      |> List.first()
      |> case do
        nil -> params["token"]
        header -> header
      end

    if is_binary(expected) and expected != "" and provided == expected do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp normalize_cloudflare_params(params) do
    %{
      "workspace_id" => params["workspace_id"],
      "message_id" => params["message_id"] || params["id"],
      "from_email" => params["from_email"] || params["from"],
      "subject" => params["subject"],
      "received_at" => params["received_at"] || params["date"],
      "headers" => params["headers"],
      "raw_text" => params["raw_text"] || params["text"] || params["raw"],
      "raw_html" => params["raw_html"] || params["html"]
    }
  end

  defp validate_required(params) do
    if Enum.all?(@required_fields, fn field -> present?(params[Atom.to_string(field)]) end) do
      :ok
    else
      {:error, :missing_required_fields}
    end
  end

  defp parse_limit(nil), do: 100

  defp parse_limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {limit, ""} -> min(max(limit, 1), 200)
      _ -> 100
    end
  end

  defp parse_limit(_), do: 100

  defp parse_received_at(nil), do: {:ok, DateTime.utc_now()}

  defp parse_received_at(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, :invalid_received_at}
    end
  end

  defp parse_received_at(_), do: {:error, :invalid_received_at}

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
