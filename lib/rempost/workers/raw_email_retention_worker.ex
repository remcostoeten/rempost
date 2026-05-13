defmodule Rempost.Workers.RawEmailRetentionWorker do
  use Oban.Worker, queue: :default, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    retention_days = Map.get(args, "retention_days", 30)
    workspace_id = Map.get(args, "workspace_id", Rempost.Runtime.workspace_id())

    {count, _} = Rempost.Emails.purge_old_raw_emails(workspace_id, retention_days)

    {:ok, %{purged_count: count, retention_days: retention_days, workspace_id: workspace_id}}
  end
end
