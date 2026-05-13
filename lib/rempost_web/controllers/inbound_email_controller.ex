defmodule RempostWeb.InboundEmailController do
  use RempostWeb, :controller
  require Logger

  def create(conn, params) do
    attrs = %{
      workspace_id: params["workspace_id"],
      message_id: params["message_id"],
      from_email: params["from_email"],
      subject: params["subject"],
      received_at: DateTime.utc_now(),
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
  end
end
