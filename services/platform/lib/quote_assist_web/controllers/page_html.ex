defmodule QuoteAssistWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use QuoteAssistWeb, :html

  embed_templates "page_html/*"

  @doc """
  The release train shown on `/release-build-status`, grouped by track.

  Hard-coded per the release plan (see `docs/RELEASE_PLAN.md`). Bump a release's
  status atom as each slice lands; this is the single place the table reads.
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
           status: :done
         },
         %{id: "R8-dashboard", desc: "/app dashboard landing", status: :done},
         %{
           id: "R9-recovery",
           desc: "Account recovery (forgot / reset / email change)",
           status: :done
         },
         %{id: "R10-domain", desc: "Custom domain (add, verify, auto-TLS)", status: :done}
       ]},
      {"Leads / Quotes",
       [
         %{id: "R11-quotes", desc: "Quote request CRUD (lead capture)", status: :done},
         %{
           id: "R12-quote-reply",
           desc: "Quote detail + AI reply hook (stub → live)",
           status: :done
         }
       ]}
    ]
  end

  @doc """
  The six "how it works" pipeline steps for the marketing landing (ported from
  `designs/index.html`). The last step is the highlighted (brand-filled) one.
  """
  def how_it_works_steps do
    [
      %{
        num: "01",
        icon: "hero-envelope",
        title: "Paste email",
        last: false,
        body: "Agent drops the raw customer email into the form."
      },
      %{
        num: "02",
        icon: "hero-document-text",
        title: "Extract",
        last: false,
        body: "Routes, dates, pax, cabin and preferences are parsed out."
      },
      %{
        num: "03",
        icon: "hero-exclamation-triangle",
        title: "Detect gaps",
        last: false,
        body: "Missing info is flagged — or sensible defaults are assumed."
      },
      %{
        num: "04",
        icon: "hero-chart-bar",
        title: "Fetch pricing",
        last: false,
        body: "Live fares via pricing adapters (Amadeus, Hotelbeds…)."
      },
      %{
        num: "05",
        icon: "hero-shield-check",
        title: "Apply policy",
        last: false,
        body: "Markup, fare rules and hold windows applied automatically."
      },
      %{
        num: "06",
        icon: "hero-sparkles",
        title: "Draft reply",
        last: true,
        body: "A polished, ready-to-send quotation — agent approves."
      }
    ]
  end

  @doc "Inline style for a how-it-works step icon (brand-filled for the final step)."
  def step_icon_style(true), do: "background:var(--mc-brand);color:#fff"

  def step_icon_style(_last),
    do: "background:var(--mc-surface);border:1px solid var(--mc-border);color:var(--mc-brand)"

  @doc "The capability cards for the marketing landing."
  def capabilities do
    [
      %{
        icon: "hero-document-text",
        title: "Requirement extraction",
        body:
          "Origins, destinations, dates, passenger mix, cabin class and special requests parsed straight from free-text email — no forms for the customer to fill."
      },
      %{
        icon: "hero-exclamation-triangle",
        title: "Missing-info detection",
        body:
          "Spots what the customer forgot — return date, room count, budget tier — and either flags it for the agent or applies a safe default, transparently."
      },
      %{
        icon: "hero-circle-stack",
        title: "Live pricing adapters",
        body:
          "A mock adapter returns realistic fixtures in development; real providers — Amadeus, Hotelbeds and more — plug in for production with no UI change."
      },
      %{
        icon: "hero-shield-check",
        title: "Policy engine",
        body:
          "Markup rules, supplier preferences, fare hold windows and compliance text applied to every quote — so juniors and seniors price the same way."
      },
      %{
        icon: "hero-pencil-square",
        title: "Professional drafts",
        body:
          "On-brand, itemised quotations in your house tone and currency — review, then send. The agent always approves first."
      },
      %{
        icon: "hero-clock",
        title: "History & audit",
        body:
          "Every quote is stored with its source email, extracted fields, pricing snapshot and the agent who approved it — searchable and re-openable."
      }
    ]
  end

  @doc "The email-input roadmap phases for the marketing landing."
  def roadmap do
    [
      %{
        tag: "Phase 2 · MVP",
        state: "Available now",
        current: true,
        title: "Web form",
        body:
          "The agent copies the customer email and pastes it into QuoteAssist. Zero setup, works in any browser — the fastest path to value."
      },
      %{
        tag: "Phase 2b",
        state: "In design",
        current: false,
        title: "Outlook add-in",
        body:
          "An Office.js button inside Outlook. The agent clicks it on any open email — no copy-paste, the quote drafts right beside the message."
      },
      %{
        tag: "Phase 11",
        state: "Planned",
        current: false,
        title: "Mailbox automation",
        body:
          "A Microsoft Graph listener watches the shared mailbox and drafts quotes for incoming enquiries automatically — agents only review and send."
      }
    ]
  end

  # The marketing landing's pricing is driven by the seeded `plans` table (passed in as
  # `@plans`), so admin plan CRUD updates it. These helpers format a `%Plan{}` for a card.

  @doc "Price label for a plan: `Free` for a ₹0 plan, else the grouped amount (paise → ₹)."
  def plan_price(%{price: 0}), do: "Free"
  def plan_price(%{price: price}) when is_integer(price), do: "₹" <> group_digits(div(price, 100))

  @doc "Billing-interval suffix for a paid plan (`/mo` · `/yr`); empty for a free plan."
  def plan_unit(%{price: 0}), do: ""
  def plan_unit(%{interval: :yearly}), do: " /yr"
  def plan_unit(%{interval: _monthly}), do: " /mo"

  @doc "The call-to-action label for a plan card."
  def plan_cta(%{price: 0}), do: "Start free"
  def plan_cta(_plan), do: "Start 14-day trial"

  @doc "Feature bullet list for a plan, derived from its `limits` map."
  def plan_features(%{limits: limits}) when is_map(limits) do
    [
      feature(limits, "quotes_per_month", &"#{group_digits(&1)} quotes / month"),
      feature(limits, "seats", &"#{&1} team seats"),
      feature(limits, "ai_generations_per_month", &"#{group_digits(&1)} AI drafts / month"),
      if(truthy?(Map.get(limits, "custom_domain")),
        do: "Custom domain",
        else: "QuoteAssist subdomain"
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  def plan_features(_plan), do: []

  @doc "Whether the plan at `index` is the highlighted (\"most popular\") one — the middle of 3+."
  def plan_featured?(index, plans), do: length(plans) >= 3 and index == div(length(plans) - 1, 2)

  defp feature(limits, key, formatter) do
    case Map.get(limits, key) do
      n when is_integer(n) -> formatter.(n)
      _ -> nil
    end
  end

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  # Group an integer with thousands separators (e.g. 1499 → "1,499").
  defp group_digits(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
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
