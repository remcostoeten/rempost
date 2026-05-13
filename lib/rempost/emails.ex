defmodule Rempost.Emails do
  import Ecto.Query
  alias Rempost.{Repo, Emails.InboundEmail}
  alias Rempost.Workers.EmailParserWorker

  def topic(workspace_id), do: "workspace:#{workspace_id}:emails"

  def subscribe(workspace_id), do: Phoenix.PubSub.subscribe(Rempost.PubSub, topic(workspace_id))

  def broadcast(workspace_id, event, payload), do: Phoenix.PubSub.broadcast(Rempost.PubSub, topic(workspace_id), {event, payload})

  def ingest_email(attrs) do
    Repo.transaction(fn ->
      with {:ok, email} <- upsert_or_get_email(attrs),
           {:ok, _job} <- enqueue_parser_job(email) do
        broadcast(email.workspace_id, :email_ingested, email.id)
        email
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def retry_parsing(%InboundEmail{} = email) do
    Repo.transaction(fn ->
      with {:ok, email} <- reset_for_retry(email),
           {:ok, _job} <- enqueue_parser_job(email) do
        broadcast(email.workspace_id, :email_retry_queued, email.id)
        email
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def get_email!(workspace_id, id), do: Repo.get_by!(InboundEmail, id: id, workspace_id: workspace_id)

  def list_recent(workspace_id), do: search_recent(workspace_id, nil, 100)

  def search_recent(workspace_id, query, limit \\ 100) do
    InboundEmail
    |> where([e], e.workspace_id == ^workspace_id)
    |> maybe_search(query)
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, raw_term) do
    term = "%#{String.downcase(String.trim(raw_term))}%"

    where(
      query,
      [e],
      ilike(fragment("lower(?)", e.subject), ^term) or
        ilike(fragment("lower(?)", e.from_email), ^term) or
        ilike(fragment("lower(?)", e.message_id), ^term) or
        ilike(fragment("lower(?)", type(e.status, :string)), ^term)
    )
  end


  def purge_old_raw_emails(workspace_id, retention_days) when is_integer(retention_days) and retention_days > 0 do
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_days * 86_400, :second)

    InboundEmail
    |> where([e], e.workspace_id == ^workspace_id and e.inserted_at < ^cutoff)
    |> Repo.update_all(set: [raw_text: "", raw_html: nil, raw_headers: %{}])
  end
  def stats(workspace_id) do
    base =
      InboundEmail
      |> where([e], e.workspace_id == ^workspace_id)

    %{
      recent_count: Repo.aggregate(base, :count, :id),
      failed_parsing_count: Repo.aggregate(where(base, [e], e.status == :failed), :count, :id),
      processing_count: Repo.aggregate(where(base, [e], e.status == :processing), :count, :id)
    }
  end

  defp enqueue_parser_job(email) do
    EmailParserWorker.new(%{"inbound_email_id" => email.id, "workspace_id" => email.workspace_id})
    |> Oban.insert()
  end

  defp reset_for_retry(email) do
    email
    |> InboundEmail.changeset(%{status: :pending, parse_error: nil})
    |> Repo.update()
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
