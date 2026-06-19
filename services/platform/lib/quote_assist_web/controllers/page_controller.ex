defmodule QuoteAssistWeb.PageController do
  use QuoteAssistWeb, :controller

  @doc """
  `/` is host-aware. The platform host shows the build-status home (platform-only
  content + the "Admin login" chrome). A tenant host shows that tenant's own branded
  landing (`tenant_home`) — a public page for everyone: signed-in members get a "Go to
  workspace" CTA, guests a "Sign in" CTA. The platform build-status page is never served
  off a tenant host, and the tenant root (the post-logout redirect target) doesn't 404.
  """
  def home(conn, _params) do
    case conn.assigns[:current_tenant] do
      nil ->
        render(conn, :home)

      tenant ->
        conn
        |> assign(:page_title, tenant.name)
        |> render(:tenant_home)
    end
  end

  @doc """
  Catch-all for any path that matched no earlier route (wired as the last route in the
  router). It runs through the full `:browser` pipeline, so `TenantResolver` has already
  resolved the host before we get here — a known tenant, the platform host, or (for an
  unknown/suspended host) the branded page TenantResolver renders and halts on. Here we
  render the branded, themed 404.

  The root layout is disabled because `error_page.html.heex` is itself a complete
  `<!DOCTYPE html>` document — its `<head>` carries the pre-paint theme script and the
  stylesheet link. Wrapping it in the app root layout (set by the `:browser` pipeline)
  would nest two documents and drop that head, which is what makes the page render
  unstyled / themeless.
  """
  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_root_layout(false)
    |> put_view(html: QuoteAssistWeb.ErrorHTML)
    |> render(:"404")
  end
end
