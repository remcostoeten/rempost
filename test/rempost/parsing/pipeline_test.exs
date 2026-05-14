defmodule Rempost.Parsing.PipelineTest do
  use Rempost.DataCase

  alias Rempost.Emails.InboundEmail
  alias Rempost.Parsing.{DeterministicParser, Pipeline}
  alias Rempost.Repo
  alias Rempost.Shipments.Shipment

  test "marks no-tracking emails parsed without creating shipments" do
    email =
      insert_email!(%{
        message_id: "no-tracking@example",
        subject: "Order received",
        raw_text: "We received order 12345 and will prepare it soon."
      })

    parsed = DeterministicParser.parse(email)

    assert parsed.tracking_number == nil

    assert {:ok, %{shipment: nil}} = Pipeline.apply!(email, parsed)
    assert Repo.aggregate(Shipment, :count) == 0
    assert Repo.reload!(email).status == :parsed
  end

  defp insert_email!(attrs) do
    defaults = %{
      message_id: "message@example",
      from_email: "shop@example.com",
      subject: "Shipment update",
      received_at: DateTime.truncate(DateTime.utc_now(), :second),
      raw_headers: %{},
      raw_text: "Tracking number: 123456789012"
    }

    %InboundEmail{}
    |> InboundEmail.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
