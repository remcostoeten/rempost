defmodule RempostWeb.InboundEmailController do
  use RempostWeb, :controller

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
      {:ok, email} -> json(conn |> put_status(:accepted), %{id: email.id, status: "queued"})
      {:error, reason} -> json(conn |> put_status(:unprocessable_entity), %{error: inspect(reason)})
    end
  end
end
