defmodule QuoteAssistWeb.TenantErrorHTML do
  @moduledoc """
  Standalone branded page shown when a request host doesn't resolve to a live tenant
  (rendered by `QuoteAssistWeb.Plugs.TenantResolver`). It can't use the app layout —
  the resolver runs before the root layout is set, and the host has no tenant — so
  the template is a complete HTML document. Ported from
  `designs/quoteassist/error-404.html`.
  """
  use QuoteAssistWeb, :html

  embed_templates "tenant_error_html/*"
end
