defmodule QuoteAssistWeb.ErrorHTML do
  @moduledoc """
  Branded HTML error pages (R6-errors). Invoked by the endpoint's `render_errors`
  config on any HTML error response, and by the plugs / fallback controller that
  render a status directly.

  Phoenix renders an error by calling `render("<status>.html", assigns)`. Each branded
  status maps to the one shared `error_page/1` document (ported from
  `designs/quoteassist/error-*.html`, `mc-*` → `mtb-*`) with its own copy; every other
  status falls back to the plain status text. The page is a complete HTML document —
  error rendering runs with `layout: false`, before the app layout is in play.
  """
  use QuoteAssistWeb, :html

  embed_templates "error_html/*"

  def render("401.html", assigns), do: error_page(assign_page(assigns, "401"))
  def render("403.html", assigns), do: error_page(assign_page(assigns, "403"))
  def render("404.html", assigns), do: error_page(assign_page(assigns, "404"))
  def render("500.html", assigns), do: error_page(assign_page(assigns, "500"))
  def render("503.html", assigns), do: error_page(assign_page(assigns, "503"))

  # Any other status renders the plain Phoenix status message (e.g. "Not Acceptable").
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  # Merge the per-status page metadata into the assigns the error renderer passed.
  # `__changed__` is forced present so the function component renders standalone even
  # when a caller hands us a bare map (e.g. a unit test).
  defp assign_page(assigns, code) do
    assigns
    |> Map.put_new(:__changed__, nil)
    |> Map.put(:page, page_meta(code, on_tenant_host?(assigns)))
  end

  # The tenant directory (`/tenants`) lives only on the platform host, so error pages
  # served on a tenant host must not link to it. A tenant host is one TenantResolver
  # resolved to a live tenant (assigns `:current_tenant`); the platform host leaves it
  # nil. When the error renders before resolution (rare 500s), we default to platform.
  defp on_tenant_host?(assigns), do: not is_nil(assigns[:current_tenant])

  defp page_meta("401", _tenant?) do
    %{
      code: "401",
      tag: "HTTP · UNAUTHORIZED",
      reference: "QA-401",
      title: "Your session has ended.",
      message:
        "You need to sign in to view this page. For your security, sessions end after a period of inactivity — sign in again to pick up where you left off.",
      primary: %{label: "Sign in", href: "/login"},
      secondary: %{label: "Go home", href: "/"}
    }
  end

  defp page_meta("403", _tenant?) do
    %{
      code: "403",
      tag: "HTTP · FORBIDDEN",
      reference: "QA-403",
      title: "You don't have access to this.",
      message:
        "This area is restricted to certain roles. If you think you should have access, ask your workspace owner to update your role.",
      primary: %{label: "Back to workspace", href: "/app"},
      secondary: %{label: "Go home", href: "/"}
    }
  end

  defp page_meta("404", tenant?) do
    %{
      code: "404",
      tag: "HTTP · NOT_FOUND",
      reference: "QA-404",
      title: "This page took a different route.",
      message:
        "The link doesn't match any page here. It may have been moved, archived, or never existed.",
      primary: %{label: "Go home", href: "/"},
      # "Browse workspaces" → /tenants is platform-only; on a tenant host the primary
      # "Go home" (the tenant landing) is the only offered route.
      secondary: if(tenant?, do: nil, else: %{label: "Browse workspaces", href: "/tenants"})
    }
  end

  defp page_meta("500", _tenant?) do
    %{
      code: "500",
      tag: "HTTP · INTERNAL_ERROR",
      reference: "QA-500",
      title: "Something went sideways on our end.",
      message:
        "An unexpected error stopped this request. Our team has been notified — please try again in a moment.",
      primary: %{label: "Go home", href: "/"},
      secondary: nil
    }
  end

  defp page_meta("503", _tenant?) do
    %{
      code: "503",
      tag: "HTTP · SERVICE_UNAVAILABLE",
      reference: "QA-503",
      title: "QuoteAssist is having a quick tune-up.",
      message:
        "We're carrying out scheduled maintenance and will be back shortly. Anything you've already saved is safe. Thanks for your patience.",
      primary: %{label: "Try again", href: "/"},
      secondary: nil
    }
  end
end
