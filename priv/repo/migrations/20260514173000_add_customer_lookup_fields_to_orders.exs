defmodule Rempost.Repo.Migrations.AddCustomerLookupFieldsToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :customer_name, :string
      add :customer_postal_code, :string
      add :customer_street, :string
      add :customer_house_number, :string
    end

    create index(:orders, [:customer_postal_code])
    create index(:orders, [:customer_street, :customer_house_number])
  end
end
