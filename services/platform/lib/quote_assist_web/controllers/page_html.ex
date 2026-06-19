defmodule QuoteAssistWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use QuoteAssistWeb, :html

  embed_templates "page_html/*"

  @doc """
  The release train shown on the platform home page, grouped by track.

  Hard-coded per the release plan (see `docs/RELEASE_PLAN.md`). Bump a release's
  status atom as each slice lands; this is the single place the home table reads.
  Statuses: `:done | :in_progress | :pending`.
  """
  def release_tracks do
    [
      {"Foundation",
       [
         %{id: "R0", desc: "Walking skeleton — app deploys, /health green", status: :done},
         %{id: "R0a", desc: "Platform home + tenant directory (/tenants)", status: :done},
         %{id: "R1", desc: "Auth — tenant users sign in / out", status: :done},
         %{id: "R2", desc: "Tenancy + RBAC (subdomain + custom domain)", status: :done}
       ]},
      {"Site Admin",
       [
         %{id: "R3", desc: "Admin identity + tenant CRUD + 15-day trial", status: :done},
         %{id: "R4-retrofit", desc: "Admin RBAC + protected super_admin", status: :done},
         %{id: "R5-selfreg", desc: "Self-registration → auto-approve to trial", status: :done},
         %{id: "R6-errors", desc: "Branded error pages (401/403/404/500/503)", status: :done}
       ]},
      {"Tenant Basics",
       [
         %{
           id: "R7-rbac",
           desc: "Users, roles, permissions + self:* + requests",
           status: :pending
         },
         %{id: "R8-dashboard", desc: "/app dashboard landing", status: :pending},
         %{
           id: "R9-recovery",
           desc: "Account recovery (forgot / reset / email change)",
           status: :pending
         },
         %{id: "R10-domain", desc: "Custom domain (add, verify, auto-TLS)", status: :pending}
       ]},
      {"Leads / Quotes",
       [
         %{id: "R11-quotes", desc: "Quote request CRUD (lead capture)", status: :pending},
         %{
           id: "R12-quote-reply",
           desc: "Quote detail + AI reply hook (stub → live)",
           status: :pending
         }
       ]}
    ]
  end

  @doc "Maps a release status to its `mtb-badge-*` modifier class."
  def status_badge_class(:done), do: "mtb-badge-success"
  def status_badge_class(:in_progress), do: "mtb-badge-warning"
  def status_badge_class(:pending), do: "mtb-badge-neutral"

  @doc "Human label for a release status."
  def status_label(:done), do: "Done"
  def status_label(:in_progress), do: "In progress"
  def status_label(:pending), do: "Pending"
end
