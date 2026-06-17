defmodule QuoteAssistWeb.TenantNotFoundError do
  @moduledoc """
  Raised when a tenant host (subdomain or custom domain) doesn't resolve to a live
  tenant. Rendered as a 404 via the `Plug.Exception` implementation below.
  """
  defexception message: "tenant not found"

  defimpl Plug.Exception do
    def status(_exception), do: 404
    def actions(_exception), do: []
  end
end

defmodule QuoteAssistWeb.Plugs.TenantResolver do
  @moduledoc """
  Resolves the tenant from the request **host** (never params) and assigns it to the
  conn as `:current_tenant`. On a tenant host it also writes the resolved tenant id
  into the host-scoped session, so LiveView mounts can reload it; on the platform
  host it clears that key. A tenant host that doesn't resolve to a live tenant
  (unknown / suspended / deleted) raises `QuoteAssistWeb.TenantNotFoundError` → 404.

  Cookies stay scoped to the exact resolved host: the endpoint session sets no
  `:domain`, so a session never leaks across tenants, nor between a tenant's
  subdomain and its custom domain. Do not add a parent-domain cookie.
  """
  @behaviour Plug

  import Plug.Conn

  alias QuoteAssist.Tenants

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case Tenants.resolve_host(conn.host) do
      :platform ->
        conn
        |> assign(:current_tenant, nil)
        |> delete_session(:tenant_id)

      {:ok, tenant} ->
        conn
        |> assign(:current_tenant, tenant)
        |> put_session(:tenant_id, tenant.id)

      :not_found ->
        raise QuoteAssistWeb.TenantNotFoundError
    end
  end
end
