defmodule Rempost.Emails do
  import Ecto.Query
  alias Rempost.{Repo, Emails.InboundEmail}
  alias Rempost.Workers.EmailParserWorker

  def ingest_email(attrs) do
    Repo.transaction(fn ->
      with {:ok, email} <- %InboundEmail{} |> InboundEmail.changeset(attrs) |> Repo.insert(on_conflict: :nothing, conflict_target: [:workspace_id, :message_id], returning: true),
           {:ok, _job} <- EmailParserWorker.new(%{"inbound_email_id" => email.id, "workspace_id" => email.workspace_id}) |> Oban.insert() do
        email
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def get_email!(workspace_id, id), do: Repo.get_by!(InboundEmail, id: id, workspace_id: workspace_id)
  def list_recent(workspace_id), do: InboundEmail |> where([e], e.workspace_id == ^workspace_id) |> order_by([e], desc: e.inserted_at) |> limit(50) |> Repo.all()
end
