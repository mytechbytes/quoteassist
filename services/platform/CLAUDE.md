# CLAUDE.md — `services/platform`

Phoenix + LiveView platform for QuoteAssist. Read alongside the root
[`../../CLAUDE.md`](../../CLAUDE.md) and the authoritative
[`docs/RELEASE_PLAN.md`](docs/RELEASE_PLAN.md).

## Current status

**R1 complete / next R2.** Auth — tenant users sign in and out. `phx.gen.auth`
(scope-based; magic-link + opt-in password) adapted to the design system: login
at `/login` (split-screen ported from `login.html`, password reveal + magic-link
request, theme toggle — all via `Phoenix.LiveView.JS`), magic-link confirm at
`/login/:token` (`verify.html` chrome, link-based — no OTP), `/logout`, and a
protected `/app` placeholder (`AppHomeLive`, `on_mount :require_authenticated`)
that bounces to `/login` when signed out. `users`/`users_tokens` land with a
`deleted_at` column and the auth lookups filter soft-deleted identities. Swoosh
mailer + `/dev/mailbox` are wired (the magic-link email lands there in dev). A
per-IP + per-email login throttle (`QuoteAssist.RateLimiter` +
`QuoteAssistWeb.Plugs.LoginThrottle`) guards the login POST and the magic-link
send, and is reused for `/admin/login` + `/register` later. `mix qa.create_user`
(dev/staging only) creates a confirmed sign-in user without touching
`seeds.exs` (R2 owns the real dev tenant/user seed). Registration (R4) and the
settings/password-change screens (R6) were intentionally deferred — their
generated routes, LiveViews, and tests were removed to keep R1 to sign in / out.

**R0a complete.** Platform home `/` renders the release-status table inside the
public chrome (`Layouts.app`: wordmark · Tenants · Admin login · theme toggle,
with a `version · env` footer); `/tenants` is a static `TenantListLive` directory
that shows an empty state until the `Tenant` schema lands in R2 — the
live-tenants `Repo.all` query is the only wiring left (`mount/3` has the hook;
the row markup is already in place). Config adds `:deploy_env` (footer tag,
overridden at runtime by `DEPLOY_ENV`) and `:tenant_base_domain` /
`:tenant_url_scheme` (per-tenant subdomain login links; dev → `lvh.me:4000`).
`/admin/login` is a plain `href` (route lands in R3).

**R0 complete.** Walking skeleton: `/health` + `/health/ready`, Dockerfile,
`docker-compose`, `.env.example`, `assets/css/mtb.css` (design tokens +
`mtb-*` utilities, DaisyUI removed), base layout wired to mtb.css + Google
Fonts + dark mode, `citext` migration.

**Next: R2** — tenancy + RBAC: `TenantResolver` (host → tenant), `Tenancy.scope/2`,
`Policy.can?/3` + the permission catalog, `audit_logs` + `Audit.log/1`, and the
real `/app/*` workspace behind `:require_tenant_member`.

## How to run

```sh
mix deps.get && mix ecto.setup   # deps + DB (incl. citext extension)
mix phx.server                   # Phoenix on :4000
mix test
mix format && mix compile --warnings-as-errors   # part of "green before done"
```

## Conventions

- **PKs:** UUID (`binary_id`). **Timestamps:** `utc_datetime`. Set these as
  schema/migration defaults so every new table inherits them.
- **Soft delete:** every tenant-owned and identity table gets
  `deleted_at :utc_datetime` from its first migration. Default queries filter
  `deleted_at` via the shared `Tenancy`/`Repo` helper.
- **Tenant scoping:** every query on a tenant-owned table goes through
  `QuoteAssist.Tenancy.scope/2`, which raises if no tenant is in scope (fails
  loud on cross-tenant reads).
- **Client JS:** `Phoenix.LiveView.JS` only. No Alpine / jQuery / SPA framework.
- **Numbers** render in `font-mono` (JetBrains Mono). No emoji in product UI.

## Tenancy & routing

- `TenantResolver` plug reads the request **host**:
  1. platform host (`quoteassist.mytechbytes.in` / `www`) → no tenant (home,
     directory, admin);
  2. `*.quoteassist.mytechbytes.in` → load tenant by `slug`;
  3. any other host → load tenant by **verified** `custom_domain`;
  4. unknown / suspended / deleted → 404.
- Cookies scoped to the **exact resolved host** (never `.quoteassist...`), so
  sessions never leak across tenants or between a subdomain and its custom domain.
- Dev: `*.lvh.me:4000` for subdomains (`acme.lvh.me:4000`).
- `on_mount :require_tenant_member` guards all `/app/*` LiveViews; verifies a
  live membership for the resolved tenant.

## RBAC & audit

- Permission **catalog is code-owned**, seeded in R2 — its single home. R5 only
  builds the roles UI on top; the UI never invents permissions.
- `Policy.can?/3` for authorization checks.
- `audit_logs` is append-only (no update/delete). Use `Audit.log/1` for every
  privileged action and state transition. Columns: `actor_type`
  (`admin|user|system`), `actor_id`, `tenant_id` (nullable), `action`,
  `target_type`, `target_id`, `metadata` (jsonb), `inserted_at`. Store
  references + masked values, never full message bodies.

## State machines

`tenant.status` (`trial → active → suspended → cancelled`) and
`quote_request.status` (`open → in_progress → quoted → closed`) are explicit
state machines guarded by `can_transition?/2` (Fsmx or a hand-rolled transition
map). Validate transitions at the changeset; illegal jumps are unreachable from
the UI. Every transition writes an `audit_logs` row.

## Site admin (separate identity)

Own `admins` table, schema, session (`admin_token`), and auth pipeline —
no shared context with `users`/`memberships`. Created only via
`Accounts.register_admin/1` (no HTTP route, no seed, no env vars). Logs in at
`/admin/login`; `:require_admin` guards `/admin/*`.

## Design system

Reference screens live in `../../designs/quoteassist/` (authoritative for layout,
tokens, component shapes). Port markup per slice, renaming `mc-*`/`qa-*`
classes → `mtb-*` (mechanical, prefix-only).

**CSS (Tailwind v4, no `tailwind.config.js`):** all `mtb-*` component classes
live in `assets/css/mtb.css`, authored as `@utility` blocks so Tailwind scans and
tree-shakes them. Design tokens (teal accent, mist neutrals; Inter / Familjen
Grotesk / JetBrains Mono) map into `@theme` from `designs/quoteassist/qa.css`.
Never invent colours outside the token set. Dark mode via `[data-theme="dark"]`
on `<html>`.

## Release order

```
R0  walking skeleton (/health, Dockerfile, base layout + mtb.css)
R0a platform home (/) + tenant list (/tenants)
R1  auth — tenant users sign in/out (phx.gen.auth, Swoosh mailer, login throttle)
R2  tenancy + RBAC (TenantResolver, Tenancy.scope, Policy, audit_logs)
R3  admin identity + tenant CRUD + 15-day trial
R4  self-registration (trial onboarding)
R5  users, roles, permissions
R6  account flows (forgot/reset/profile)
R-CD custom domain (add, verify, auto-TLS via Caddy on-demand)
R7  quote request CRUD (lead capture)
R8  quote reply + AI hook (stub → live)
```

Each arrow is a staging deploy. See [`docs/RELEASE_PLAN.md`](docs/RELEASE_PLAN.md)
for the per-release Build / Data / Done-when detail.

## Git workflow

Always confirm before `git commit` / `git push`. Push directly to `main` only.
