defmodule Rempost.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workspaces" do
    field :name, :string
    field :slug, :string
    has_many :inbound_emails, Rempost.Emails.InboundEmail
    timestamps(type: :utc_datetime)
  end

  def changeset(workspace, attrs),
    do:
      workspace
      |> cast(attrs, [:name, :slug])
      |> validate_required([:name, :slug])
      |> unique_constraint(:slug)
end
