defmodule RempostWeb.ErrorHTML do
  use RempostWeb, :html
  def render(_template, _assigns), do: "error"
end
