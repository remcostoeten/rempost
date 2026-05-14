defmodule Rempost.Settings do
  alias Rempost.{Repo, Settings.Setting}

  def get(key) do
    case Repo.get_by(Setting, key: key) do
      %Setting{value: value} -> value
      nil -> nil
    end
  rescue
    # If settings table doesn't exist yet (e.g. before migration)
    _ -> nil
  end
end
