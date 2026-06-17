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
         %{id: "R3", desc: "Admin identity + tenant CRUD + 15-day trial", status: :in_progress},
         %{id: "R4", desc: "Self-registration (trial onboarding)", status: :pending}
       ]},
      {"Tenant Basics",
       [
         %{id: "R5", desc: "Users, roles, permissions", status: :pending},
         %{id: "R6", desc: "Account flows (forgot / reset / profile)", status: :pending},
         %{id: "R-CD", desc: "Custom domain (add, verify, auto-TLS)", status: :pending}
       ]},
      {"Leads / Quotes",
       [
         %{id: "R7", desc: "Quote request CRUD (lead capture)", status: :pending},
         %{id: "R8", desc: "Quote reply + AI hook (stub → live)", status: :pending}
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
