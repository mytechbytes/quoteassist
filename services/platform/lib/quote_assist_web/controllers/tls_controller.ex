defmodule QuoteAssistWeb.TlsController do
  @moduledoc """
  On-demand TLS gate (R10-domain). Caddy's `on_demand_tls` `ask` points here before it
  issues a certificate for an arbitrary hostname: we return **200** only when `domain`
  is a live tenant's *verified* custom domain, and **403** otherwise. That stops
  certificate-issuance abuse — Caddy will only ever mint certs for domains a tenant has
  actually proven they own.

  Lives on the `:api` pipeline (no session, no tenant resolution): it's an
  infrastructure callback, not a user-facing route.
  """
  use QuoteAssistWeb, :controller

  alias QuoteAssist.Tenants

  def check(conn, %{"domain" => domain}) when is_binary(domain) do
    if Tenants.verified_custom_domain?(domain) do
      send_resp(conn, 200, "ok")
    else
      send_resp(conn, 403, "forbidden")
    end
  end

  def check(conn, _params), do: send_resp(conn, 403, "forbidden")
end
