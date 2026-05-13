defmodule Rempost.Runtime do
  @default_workspace_id 1

  def workspace_id do
    Application.get_env(:rempost, :workspace_id, @default_workspace_id)
  end
end
