defmodule QuoteAssistWeb.TenantErrorHTML do
  @moduledoc """
  Standalone branded pages the `QuoteAssistWeb.Plugs.TenantResolver` renders for a
  tenant host that can't serve the app:

    * `tenant_not_found` — no live tenant (unknown / cancelled / deleted host), 404.
    * `tenant_suspended` — a live but suspended tenant (admin pause or lapsed trial), 403.

  These can't use the app layout — the resolver runs before the root layout is set and
  the host has no usable tenant — so each template is a complete HTML document. Ported
  from `designs/quoteassist/error-404.html` / `error-403.html`.
  """
  use QuoteAssistWeb, :html

  embed_templates "tenant_error_html/*"
end
