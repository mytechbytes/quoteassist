defmodule QuoteAssistWeb.Plugs.RequirePlatform do
  @moduledoc """
  The inverse of `RequireTenant`: ensures the request is on the platform host. Admin
  routes (`/admin/*`) live only on the platform host — never a tenant subdomain or
  verified custom domain. On a tenant host (`:current_tenant` assigned by
  `TenantResolver`), this renders a 404 and halts, so `/admin` is invisible there and
  reveals nothing.

  Runs after `TenantResolver` in the pipeline.
  """
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, put_format: 2, render: 2]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if Map.get(conn.assigns, :current_tenant) do
      conn
      |> put_status(:not_found)
      |> put_format("html")
      |> put_view(html: QuoteAssistWeb.ErrorHTML)
      |> render(:"404")
      |> halt()
    else
      conn
    end
  end
end
