defmodule Rempost.Emails do
  import Ecto.Query
  alias Rempost.{Repo, Emails.InboundEmail}
  alias Rempost.Workers.EmailParserWorker

  def ingest_email(attrs) do
    Repo.transaction(fn ->
      with {:ok, email} <- upsert_or_get_email(attrs),
           {:ok, _job} <- EmailParserWorker.new(%{"inbound_email_id" => email.id, "workspace_id" => email.workspace_id}) |> Oban.insert() do
        email
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def get_email!(workspace_id, id), do: Repo.get_by!(InboundEmail, id: id, workspace_id: workspace_id)

  def list_recent(workspace_id) do
    InboundEmail
    |> where([e], e.workspace_id == ^workspace_id)
    |> order_by([e], desc: e.inserted_at)
    |> limit(50)
    |> Repo.all()
  end

  defp upsert_or_get_email(attrs) do
    changeset = InboundEmail.changeset(%InboundEmail{}, attrs)

    case Repo.insert(changeset, on_conflict: :nothing, conflict_target: [:workspace_id, :message_id], returning: true) do
      {:ok, %InboundEmail{id: nil}} -> fetch_existing(attrs)
      {:ok, %InboundEmail{} = email} -> {:ok, email}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_existing(%{workspace_id: workspace_id, message_id: message_id}) do
    case Repo.get_by(InboundEmail, workspace_id: workspace_id, message_id: message_id) do
      nil -> {:error, :email_conflict_not_found}
      email -> {:ok, email}
    end
  end
end
