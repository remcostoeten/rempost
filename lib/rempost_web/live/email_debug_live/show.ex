defmodule RempostWeb.EmailDebugLive.Show do
  use RempostWeb, :live_view

  def mount(%{"id" => id}, _session, socket),
    do: {:ok, assign(socket, email: Rempost.Emails.get_email!(1, id))}
end
