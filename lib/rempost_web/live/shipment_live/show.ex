defmodule RempostWeb.ShipmentLive.Show do
  use RempostWeb, :live_view

  def mount(%{"id" => id}, _session, socket),
    do:
      {:ok,
       assign(socket,
         shipment: Rempost.Shipments.get_shipment!(id)
       )}

  def format_event_time(nil), do: "Nog niet bekend"

  def format_event_time(%DateTime{} = dt),
    do: Calendar.strftime(dt, "%d-%m-%Y %H:%M")

  def format_event_time(%NaiveDateTime{} = dt),
    do: Calendar.strftime(dt, "%d-%m-%Y %H:%M")

  def format_event_time(other), do: to_string(other)

  def humanize_event_status(status) when is_binary(status) do
    status
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def humanize_event_status(status), do: status |> to_string() |> humanize_event_status()

  @timeline_steps [
    {:ordered, "Besteld"},
    {:shipped, "Verzonden"},
    {:in_transit, "Onderweg"},
    {:delivered, "Bezorgd"}
  ]

  def timeline_steps, do: @timeline_steps

  def timeline_step_complete?(:failed, _step), do: false

  def timeline_step_complete?(current, step) do
    statuses = Enum.map(@timeline_steps, &elem(&1, 0))
    current_index = Enum.find_index(statuses, &(&1 == current)) || 0
    step_index = Enum.find_index(statuses, &(&1 == step)) || 0
    step_index <= current_index
  end
end
