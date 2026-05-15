defmodule Rempost.Repo.Migrations.AddRichParsedFields do
  use Ecto.Migration

  def change do
    alter table(:shipments) do
      add :estimated_delivery_text, :text
      add :delivered_at_text, :text
      add :signature_required, :boolean, default: false, null: false
      add :latest_email_subject, :string
    end

    alter table(:orders) do
      add :merchant_legal_entity, :string
      add :customer_city, :string
    end
  end
end
