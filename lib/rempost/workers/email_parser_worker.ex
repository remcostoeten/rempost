defmodule Rempost.Workers.EmailParserWorker do
  use Oban.Worker, queue: :parsing, max_attempts: 20
  alias Rempost.{Repo, Emails.InboundEmail}

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"inbound_email_id" => inbound_email_id, "workspace_id" => workspace_id}
      }) do
    email = Repo.get_by!(InboundEmail, id: inbound_email_id, workspace_id: workspace_id)

    try do
      parsed = Rempost.Parsing.DeterministicParser.parse(email)
      Rempost.Parsing.Pipeline.apply!(workspace_id, email, parsed)
      :ok
    rescue
      error ->
        email
        |> InboundEmail.changeset(%{status: :failed, parse_error: Exception.message(error)})
        |> Repo.update()

        {:error, Exception.message(error)}
    end
  end
end
