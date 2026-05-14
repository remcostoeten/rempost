defmodule Rempost.Settings.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @required_fields [:key, :value]

  schema "settings" do
    field :key, :string
    field :value, :string

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required(@required_fields)
    |> unique_constraint(:key)
  end
end
