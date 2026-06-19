defmodule QuoteAssistWeb.FallbackController do
  @moduledoc """
  Translates controller-action error tuples into branded error pages (R6-errors).
  Wire it into a controller with `action_fallback QuoteAssistWeb.FallbackController`;
  an action that returns one of the tuples below then renders the matching
  `QuoteAssistWeb.ErrorHTML` page instead of crashing.

      {:error, :unauthenticated}  -> 401
      {:error, :unauthorized}     -> 403
      {:error, :not_found}        -> 404

  LiveViews use the raise path (`QuoteAssistWeb.Errors`) instead, since they have no
  action-result contract.
  """
  use QuoteAssistWeb, :controller

  def call(conn, {:error, :unauthenticated}), do: send_error(conn, :unauthorized, :"401")
  def call(conn, {:error, :unauthorized}), do: send_error(conn, :forbidden, :"403")
  def call(conn, {:error, :not_found}), do: send_error(conn, :not_found, :"404")

  # Mirrors the direct-render pattern used by the routing plugs: set the status and an
  # explicit HTML format, point at ErrorHTML, render the branded page.
  defp send_error(conn, status, template) do
    conn
    |> put_status(status)
    |> put_format("html")
    |> put_view(html: QuoteAssistWeb.ErrorHTML)
    |> render(template)
  end
end
