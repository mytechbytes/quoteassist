defmodule QuoteAssistWeb.Plugs.TenantResolver do
  @moduledoc """
  Resolves the tenant from the request **host** (never params) and assigns it to the
  conn as `:current_tenant`. On a tenant host it also writes the resolved tenant id
  into the host-scoped session, so LiveView mounts can reload it; on the platform
  host it clears that key.

  A host that resolves to a **suspended** tenant renders a branded "workspace
  suspended" page with status **403** (the workspace exists, access is forbidden). A
  host with no live tenant — unknown, cancelled, or deleted — renders the branded
  "workspace not registered" page with status **404**. Both halt the pipeline (see
  `QuoteAssistWeb.TenantErrorHTML`).

  Cookies stay scoped to the exact resolved host: the endpoint session sets no
  `:domain`, so a session never leaks across tenants, nor between a tenant's
  subdomain and its custom domain. Do not add a parent-domain cookie.
  """
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, put_format: 2, render: 3]

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

      {:suspended, tenant} ->
        render_suspended(conn, tenant)

      :not_found ->
        render_not_found(conn)
    end
  end

  # Renders the standalone branded 404 page. Sets the format explicitly so this
  # works even when the surrounding pipeline's `:accepts` hasn't run (e.g. unit
  # tests calling the plug directly). No layout is applied — the template is a
  # complete document, since the root layout isn't set this early in the pipeline.
  defp render_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_format("html")
    |> put_view(html: QuoteAssistWeb.TenantErrorHTML)
    |> render(:tenant_not_found,
      host: conn.host,
      platform_url: platform_url("/"),
      directory_url: platform_url("/tenants")
    )
    |> halt()
  end

  # Renders the standalone branded "workspace suspended" page with status 403. The
  # tenant exists but its access is suspended (admin action or a lapsed trial), which
  # is a forbidden state — distinct from the 404 used for unknown/cancelled/deleted
  # hosts. No layout (the template is a complete document); the tenant id is not
  # written to the session, since the workspace must not be entered.
  defp render_suspended(conn, tenant) do
    conn
    |> put_status(:forbidden)
    |> put_format("html")
    |> put_view(html: QuoteAssistWeb.TenantErrorHTML)
    |> render(:tenant_suspended,
      host: conn.host,
      tenant_name: tenant.name,
      platform_url: platform_url("/"),
      directory_url: platform_url("/tenants")
    )
    |> halt()
  end

  defp platform_url(path) do
    scheme = Application.get_env(:quote_assist, :tenant_url_scheme, "https")
    base = Application.get_env(:quote_assist, :tenant_base_domain, "quoteassist.mytechbytes.in")
    "#{scheme}://#{base}#{path}"
  end
end
