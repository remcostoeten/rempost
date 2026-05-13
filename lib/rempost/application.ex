defmodule Rempost.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Rempost.Repo,
      {Task, fn -> Rempost.Workspaces.ensure_default_workspace!() end},
      {Oban, Application.fetch_env!(:rempost, Oban)},
      {Phoenix.PubSub, name: Rempost.PubSub},
      RempostWeb.Telemetry,
      RempostWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Rempost.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RempostWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
