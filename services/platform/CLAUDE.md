# CLAUDE.md — `services/platform`

Phoenix + LiveView platform for QuoteAssist. Read alongside the root
[`../../CLAUDE.md`](../../CLAUDE.md) and the authoritative
[`docs/RELEASE_PLAN.md`](docs/RELEASE_PLAN.md).

## Current status

**R0 complete.** Walking skeleton: `/health` + `/health/ready`, Dockerfile,
`docker-compose`, `.env.example`, `assets/css/mtb.css` (design tokens +
`mtb-*` utilities, DaisyUI removed), base layout wired to mtb.css + Google
Fonts + dark mode, `citext` migration.

**Next: R0a** — platform home `/` (release-status table) + `/tenants` list.

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
