defmodule QuoteAssistWeb.Plugs.RequireTenant do
  @moduledoc """
  Ensures the request is on a resolved tenant host. On the platform host (no
  `:current_tenant`, set by `TenantResolver`) it redirects to the public tenant
  directory with a flash — so tenant login lives only on tenant subdomains / custom
  domains, never on the platform host (site admins use `/admin/login`, R3).

  Runs after `TenantResolver` in the pipeline.
  """
  @behaviour Plug

  use QuoteAssistWeb, :verified_routes

  import Plug.Conn, only: [halt: 1]
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%{assigns: %{current_tenant: %{}}} = conn, _opts), do: conn

  def call(conn, _opts) do
    conn
    |> put_flash(:info, "Choose your workspace to sign in.")
    |> redirect(to: ~p"/tenants")
    |> halt()
  end
end
