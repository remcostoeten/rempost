defmodule Rempost.Repo.Migrations.CreateInboundEmails do
  use Ecto.Migration

  def change do
    create table(:inbound_emails) do
      add :message_id, :string, null: false
      add :from_email, :string, null: false
      add :subject, :string
      add :received_at, :utc_datetime, null: false
      add :raw_headers, :map, null: false, default: %{}
      add :raw_text, :text, null: false
      add :raw_html, :text
      add :status, :string, null: false, default: "pending"
      add :parse_error, :text
      timestamps(type: :utc_datetime)
    end

    create index(:inbound_emails, [:status])
    create unique_index(:inbound_emails, [:message_id])
  end
end
