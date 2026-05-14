defmodule Rempost.Workers.EmailParserWorker do
  use Oban.Worker, queue: :parsing, max_attempts: 20
  require Logger

  alias Rempost.{Repo, Emails, Emails.InboundEmail}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"inbound_email_id" => inbound_email_id}}) do
    with %InboundEmail{} = email <- Repo.get(InboundEmail, inbound_email_id),
         {:ok, %InboundEmail{}} <- mark_processing(email) do
      Emails.broadcast(:email_processing, email.id)
      parsed = Rempost.Parsing.DeterministicParser.parse(email)
      Rempost.Parsing.Pipeline.apply!(email, parsed)
      Emails.broadcast(:email_parsed, email.id)
      :ok
    else
      nil -> {:discard, :inbound_email_not_found}
    end
  rescue
    error ->
      Logger.error("Email parser worker failed",
        error: Exception.message(error),
        inbound_email_id: inbound_email_id
      )

      maybe_mark_failed(inbound_email_id, Exception.message(error))
      Emails.broadcast(:email_failed, inbound_email_id)
      {:error, Exception.message(error)}
  end

  defp mark_processing(email) do
    email
    |> InboundEmail.changeset(%{status: :processing, parse_error: nil})
    |> Repo.update()
  end

  defp maybe_mark_failed(inbound_email_id, message) do
    case Repo.get(InboundEmail, inbound_email_id) do
      nil ->
        :ok

      email ->
        email |> InboundEmail.changeset(%{status: :failed, parse_error: message}) |> Repo.update()
    end
  end
end
