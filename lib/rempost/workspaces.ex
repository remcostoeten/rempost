defmodule Rempost.Workspaces do
  alias Rempost.{Repo, Workspaces.Workspace}

  def ensure_default_workspace! do
    workspace_id = Rempost.Runtime.workspace_id()

    case Repo.get(Workspace, workspace_id) do
      %Workspace{} = workspace -> workspace
      nil -> create_default_workspace!(workspace_id)
    end
  end

  defp create_default_workspace!(workspace_id) do
    slug = "default-#{workspace_id}"

    Repo.insert!(
      %Workspace{id: workspace_id}
      |> Workspace.changeset(%{name: "Default Workspace", slug: slug})
    )
  end
end
