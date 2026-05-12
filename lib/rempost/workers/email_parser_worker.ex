defmodule Rempost.Workers.EmailParserWorker do
  use Oban.Worker, queue: :parsing, max_attempts: 20
  require Logger

  alias Rempost.{Repo, Emails.InboundEmail}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"inbound_email_id" => inbound_email_id, "workspace_id" => workspace_id}}) do
    with %InboundEmail{} = email <- Repo.get_by(InboundEmail, id: inbound_email_id, workspace_id: workspace_id) do
      parsed = Rempost.Parsing.DeterministicParser.parse(email)
      Rempost.Parsing.Pipeline.apply!(workspace_id, email, parsed)
      :ok
    else
      nil -> {:discard, :inbound_email_not_found}
    end
  rescue
    error ->
      Logger.error("Email parser worker failed", error: Exception.message(error), workspace_id: workspace_id, inbound_email_id: inbound_email_id)
      maybe_mark_failed(workspace_id, inbound_email_id, Exception.message(error))
      {:error, Exception.message(error)}
  end

  defp maybe_mark_failed(workspace_id, inbound_email_id, message) do
    case Repo.get_by(InboundEmail, id: inbound_email_id, workspace_id: workspace_id) do
      nil -> :ok
      email -> email |> InboundEmail.changeset(%{status: :failed, parse_error: message}) |> Repo.update()
    end
  end
end
