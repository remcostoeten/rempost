defmodule Rempost.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Rempost.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Rempost.DataCase
    end
  end

  setup tags do
    Rempost.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Rempost.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
