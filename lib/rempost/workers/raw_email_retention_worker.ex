defmodule Rempost.Workers.RawEmailRetentionWorker do
  use Oban.Worker, queue: :default, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    retention_days = Map.get(args, "retention_days", 30)

    {count, _} = Rempost.Emails.purge_old_raw_emails(retention_days)

    {:ok, %{purged_count: count, retention_days: retention_days}}
  end
end
