# CLAUDE.md — QuoteAssist

Guidance for Claude working in this repo. Read before touching any code.

> **Release plan is authoritative.** The full R0–R8 build order, cross-cutting
> decisions, and design-system contract live in
> [`services/platform/docs/RELEASE_PLAN.md`](services/platform/docs/RELEASE_PLAN.md).
> This file is the short version; the release plan wins on any conflict. See also
> [`services/platform/CLAUDE.md`](services/platform/CLAUDE.md) for platform-specific
> rules.

## What this is

A **multi-tenant AI-powered quote assistant**. Each tenant (organisation) gets
their own isolated workspace, reached on its own subdomain (and optionally a
custom domain). A quote request is a lead; the reply (manual now, AI later) is
the quote. Built in thin vertical slices — every release is independently
deployable to staging.

## Locked decisions

1. **Stack:** Elixir/Phoenix (platform) + Python/FastAPI (AI service).
2. **Web UI:** Phoenix LiveView. Use `Phoenix.LiveView.JS` for all client
   interactions — no Alpine, jQuery, or bespoke JS framework.
3. **PKs:** UUID (`binary_id`) everywhere. Timestamps in `utc_datetime`.
4. **Multi-tenancy:** every tenant-owned row has a `tenant_id` column. All
   queries scoped through `QuoteAssist.Tenancy.scope/2`.
5. **Tenant identification:** subdomain (`acme.quoteassist.mytechbytes.in`) +
   optional verified custom domain, resolved by the `TenantResolver` plug from
   the request **host** — never from params. API requests carry `tenant_id` in
   JWT claims; never trust a `tenant_id` supplied by the client.
6. **User ↔ tenant:** many-to-many via `memberships`. A `User` is a global
   identity (unique email); tenant association lives only on `memberships`.
7. **Soft delete everywhere:** every tenant-owned and identity table carries
   `deleted_at`; default queries filter it out. Hard purge is a separate,
   explicit, audited admin action.
8. **Audit log:** an append-only `audit_logs` table records every privileged
   action and status transition, from R2 onward.
9. **Status fields are state machines:** `tenant.status` and
   `quote_request.status` use explicit transitions guarded by `can_transition?/2`;
   illegal jumps are rejected at the changeset. Every transition writes an audit row.
10. **Site admin is a separate identity:** own `admins` table, schema, session,
    and auth pipeline. Created only via `Accounts.register_admin/1` (no HTTP
    surface). Logs in at `/admin/login`.

## Repo layout

```
services/
  platform/        # Elixir/Phoenix app + LiveView UI
    docs/          # RELEASE_PLAN.md (authoritative)
  ai-service/      # Python/FastAPI — prompt, model, response (later)
designs/           # design tokens + reference screens (mc-*/qa-* → mtb-*)
```

## How to run

```sh
cd services/platform
mix deps.get && mix ecto.setup   # deps + DB
mix phx.server                   # Phoenix on :4000
mix test                         # run tests
```

## Rules for every session

- **Tenant isolation is non-negotiable.** Every DB query on a tenant-owned table
  must be scoped via `Tenancy.scope/2`. Resolve `tenant_id` from the resolved
  host / session membership (web) or JWT (API) — never from user-supplied params.
- **Keep the boundary thin.** Phoenix calls the AI service over HTTP; all
  prompt/model logic lives in `ai-service`, not in Phoenix.
- **Design system:** port markup from `designs/quoteassist/`, renaming
  `mc-*`/`qa-*` classes → `mtb-*`. Never invent colours outside the `@theme`
  token set. `mtb-*` component classes live in `assets/css/mtb.css` (Tailwind v4
  `@theme` / `@utility`, no `tailwind.config.js`).
- **Audit privileged actions.** Every admin op, registration decision, role
  change, and status transition writes an `audit_logs` row. Never store full
  message bodies — references + masked values only.
- **Green before done.** `mix format`, `mix compile --warnings-as-errors`,
  `mix test` must all pass.
- **Simple first.** Resist adding complexity not yet asked for. When in doubt,
  leave it out and note it as a future concern.

## Build order (see RELEASE_PLAN.md for detail)

```
R0 → R0a → R1 → R2    foundation: skeleton · home+tenants · auth · tenancy+RBAC
  → R3 → R4            site admin: tenant CRUD+trial · self-registration
  → R5 → R6 → R-CD     tenant basics: users/roles · account flows · custom domain
  → R7 → R8            leads/quotes: request CRUD · AI reply hook
```

## What's intentionally absent (add later)

- Confidence thresholds / auto-send toggles (human-in-the-loop always)
- Versioned config / prompt management
- Activity feed
- Terraform / cloud infra
- Multiple verticals (R1 airline is future scope)

## Git workflow

- **Always confirm before `git commit` and `git push`.** Never commit or push
  without explicit approval.
- **Push directly to `main` only.** No other branch is pushed without being asked.
