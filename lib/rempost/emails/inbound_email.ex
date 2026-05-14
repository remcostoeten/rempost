defmodule Rempost.Emails.InboundEmail do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:pending, :processing, :parsed, :failed]
  schema "inbound_emails" do
    field :message_id, :string
    field :from_email, :string
    field :subject, :string
    field :received_at, :utc_datetime
    field :raw_headers, :map
    field :raw_text, :string
    field :raw_html, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :parse_error, :string
    timestamps(type: :utc_datetime)
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, [
      :message_id,
      :from_email,
      :subject,
      :received_at,
      :raw_headers,
      :raw_text,
      :raw_html,
      :status,
      :parse_error
    ])
    |> validate_required([:message_id, :from_email, :received_at, :raw_text])
    |> unique_constraint(:message_id)
  end
end
