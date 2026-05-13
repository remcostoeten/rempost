defmodule RempostWeb.InboundEmailController do
  use RempostWeb, :controller
  require Logger

  @required_fields ~w(workspace_id message_id from_email raw_text)a

  def create(conn, params) do
    with :ok <- validate_required(params),
         {:ok, received_at} <- parse_received_at(params["received_at"]) do
      attrs = %{
        workspace_id: params["workspace_id"],
        message_id: params["message_id"],
        from_email: params["from_email"],
        subject: params["subject"],
        received_at: received_at,
        raw_headers: params["headers"] || %{},
        raw_text: params["raw_text"] || "",
        raw_html: params["raw_html"]
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
  end

  defp validate_required(params) do
    if Enum.all?(@required_fields, fn field -> present?(params[Atom.to_string(field)]) end) do
      :ok
    else
      {:error, :missing_required_fields}
    end
  end

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
