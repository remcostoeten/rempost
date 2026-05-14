defmodule Rempost.Repo.Migrations.RemoveWorkspaceScopeFromInboundEmails do
  use Ecto.Migration

  def up do
    drop_if_exists index(:inbound_emails, [:workspace_id, :message_id])
    drop_if_exists index(:inbound_emails, [:workspace_id, :status])

    execute "ALTER TABLE inbound_emails DROP COLUMN IF EXISTS workspace_id"

    create_if_not_exists unique_index(:inbound_emails, [:message_id])
    create_if_not_exists index(:inbound_emails, [:status])
  end

  def down do
    drop_if_exists index(:inbound_emails, [:message_id])
    drop_if_exists index(:inbound_emails, [:status])

    alter table(:inbound_emails) do
      add :workspace_id, :bigint, null: false
    end

    create_if_not_exists unique_index(:inbound_emails, [:workspace_id, :message_id])
    create_if_not_exists index(:inbound_emails, [:workspace_id, :status])
  end
end
