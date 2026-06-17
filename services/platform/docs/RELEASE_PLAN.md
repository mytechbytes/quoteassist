# Platform Release Plan — QuoteAssist (`services/platform`)

> **Authoritative release plan for the Phoenix platform.** This is the single
> source of truth for the R0–R8 build order, cross-cutting decisions, and the
> design-system contract. `CLAUDE.md` (root and platform) summarises and points
> here; if they ever disagree, this file wins.

Phoenix + LiveView only. AI service slots in later without changing these screens.
Every release is independently deployable to staging.

## One rule: always deployable

Build in thin vertical slices. After each `R#` you can deploy and demo.
Keep `mix test` green. Tenant isolation from R2 onward — scope every query
through `QuoteAssist.Tenancy.scope/2`; resolve `tenant_id` from the host /
session, never from params.

---

## Cross-cutting decisions (settle before R2)

These shape the data model and routing. Cheap to decide now, expensive to
change once real tenant data and URLs exist.

### Tenant identification — **subdomain + optional custom domain**

**Primary platform domain:** `quoteassist.mytechbytes.in`.
- Platform host (`quoteassist.mytechbytes.in`) serves the public home, tenant
  directory, and admin.
- Tenants live on `*.quoteassist.mytechbytes.in` — e.g.
  `acme.quoteassist.mytechbytes.in`. The `:slug` is the subdomain label.
- A tenant may **also** add their own **custom domain** (e.g. `quotes.acme.com`).
  Both resolve to the same tenant simultaneously — the subdomain never stops
  working, so it's a permanent fallback if the custom domain's DNS/TLS breaks.

Chosen over path-prefix (`/t/acme/…`) and session-only because:
- **Security (decisive):** each tenant gets its own browser **origin**, so the
  same-origin policy isolates cookies, `localStorage`, and XSS blast radius
  per tenant — a second wall behind `Tenancy.scope/2`. Path-prefix shares one
  origin across all tenants.
- **Future-proof:** custom domains are a natural paid-tier extension;
  per-tenant TLS, CSP, and rate limits key off the host.
- **Operable:** URLs are bookmarkable and shareable; "send me the link" works.

**Resolution — `TenantResolver` plug** (reads the request host):
1. Host is the platform domain (`quoteassist.mytechbytes.in` / `www`) →
   platform routes (home, directory, admin). No tenant.
2. Host ends in `.quoteassist.mytechbytes.in` → take the first label as slug,
   load the live tenant by `slug`.
3. Otherwise → treat the full host as a **custom domain**, load the live tenant
   by `custom_domain` (verified only).
4. No match / suspended / deleted → 404.
Tenant assigned to `conn`/socket; cookies scoped to the **exact resolved host**
(never `.quoteassist.mytechbytes.in`) so sessions never leak across tenants or
between a tenant's subdomain and its custom domain.

**Custom domain lifecycle** (tenant-configurable, see R-CD below):
- Tenant enters their domain → system stores it `pending` + issues a DNS
  verification token (TXT record) and the CNAME target
  (`<slug>.quoteassist.mytechbytes.in`).
- A verification check confirms the TXT record → status `verified`.
- TLS for verified custom domains is issued automatically by **Caddy on-demand
  TLS**, gated by an internal `/tls/check?domain=` endpoint that only authorises
  hostnames matching a `verified` custom domain (prevents cert-issuance abuse).
- A custom domain is unique across all tenants (DB unique constraint).

**Environments:**
- **Dev:** `*.lvh.me` for subdomains (`acme.lvh.me:4000`); custom-domain logic
  testable by mapping a hosts-file entry.
- **Prod:** wildcard DNS `*.quoteassist.mytechbytes.in` + Caddy wildcard TLS for
  subdomains; Caddy on-demand TLS for verified custom domains.
- Admin stays on the platform host — never a tenant subdomain or custom domain.

### User ↔ tenant cardinality — **many-to-many via `memberships`**

A `User` is a global identity (unique email); tenant association lives only on
`memberships`. One email can belong to multiple tenants (one membership each).
Invite-by-email (R5) reuses the existing `User` row if the email already
exists and adds a new membership; it never duplicates the user. Login resolves
the active tenant from the subdomain, then loads that user's membership for it
(no membership for this tenant on this host → access denied).

### Soft delete everywhere — **`deleted_at`**

Every tenant-owned and identity table carries `deleted_at :utc_datetime` (null
= live) from its first migration. "Delete" sets `deleted_at`; queries filter it
out by default via a shared `Tenancy`/`Repo` helper. Hard purge is a separate,
explicit, audited admin action with a grace window. Never destroy quote history
or audit trails on a normal delete.

### Audit log — **immutable, from R2**

An append-only `audit_logs` table records every privileged action (admin tenant
ops, registration approvals, user/role changes, quote status transitions).
Columns: `actor_type` (`admin|user|system`), `actor_id`, `tenant_id` (nullable
for platform actions), `action`, `target_type`, `target_id`, `metadata` (jsonb),
`inserted_at`. Append-only — no update/delete. Never store full message bodies;
store references + masked values.

### Status fields are state machines

Both `tenant.status` (`trial → active → suspended → cancelled`) and
`quote_request.status` (`open → in_progress → quoted → closed`) are modelled as
explicit state machines with a `can_transition?/2` guard (Fsmx or a hand-rolled
transition map). The schema validates transitions; illegal jumps (e.g.
`closed → in_progress`) are rejected at the changeset, never reachable from the
UI. Every transition writes an `audit_logs` row.

---

## Release Index

| #    | Track         | Outcome                                    |
|------|---------------|--------------------------------------------|
| R0   | Foundation    | App deploys; `/health` green               |
| R0a  | Foundation    | Platform home `/` + tenant list `/tenants` |
| R1   | Foundation    | Auth — sign in / out                       |
| R2   | Foundation    | Tenancy + RBAC (subdomain + custom domain) |
| R3   | Site Admin    | Tenant CRUD with owner + 15-day trial      |
| R4   | Site Admin    | Self-registration (trial onboarding)       |
| R5   | Tenant Basics | Users, roles, permissions                  |
| R6   | Tenant Basics | Account flows (forgot / reset / profile)   |
| R-CD | Tenant Basics | Custom domain (add, verify, auto-TLS)      |
| R7   | Leads/Quotes  | Quote request CRUD (lead capture)          |
| R8   | Leads/Quotes  | Quote detail + AI reply hook (stub → live) |

---

## Design system

All screens live in `designs/quoteassist/`. Built with the QuoteAssist design
system (teal accent, mist neutrals, Inter + Familjen Grotesk + JetBrains Mono).
Reference HTML files are the authoritative source for layout, tokens, and
component shapes.

### Class prefix convention

The design files use `mc-*` (MangoCMS origin) and `qa-*` (QuoteAssist) prefixes.
**All of these are ported and renamed to `mtb-*`** (mytechbytes) in this project.

The rename is mechanical — one-to-one, prefix only:

| Design file class | This project     |
|-------------------|------------------|
| `mc-sidebar`      | `mtb-sidebar`    |
| `mc-btn`          | `mtb-btn`        |
| `qa-shell`        | `mtb-shell`      |
| `qa-stat-card`    | `mtb-stat-card`  |
| `qa-badge`        | `mtb-badge`      |
| … and so on       |                  |

### CSS architecture (Tailwind v4)

Tailwind v4 uses `@theme` and `@utility` in plain CSS — no `tailwind.config.js`.
All `mtb-*` component classes live in `assets/css/mtb.css` and are authored as
`@utility` blocks so Tailwind's engine scans and tree-shakes them correctly.

```css
/* assets/css/mtb.css */
@import "tailwindcss";

@theme {
  /* design tokens — map from designs/quoteassist/qa.css */
  --color-teal-500: #0d9488;
  --color-mist-100: #f0f4f8;
  /* … full token set */
  --font-sans: "Inter", sans-serif;
  --font-display: "Familjen Grotesk", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
}

@utility mtb-btn {
  @apply inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium
         transition-colors;
}

@utility mtb-btn-primary {
  @apply mtb-btn bg-teal-500 text-white hover:bg-teal-600;
}

@utility mtb-sidebar {
  @apply flex h-screen w-64 flex-col bg-mist-100 border-r border-mist-200;
}
/* … one @utility block per component */
```

Tailwind utility classes (spacing, flex, grid, typography) are used directly
alongside `mtb-*` — no wrapping them in new component classes unless the
combination repeats 3+ times.

**Rules for every UI slice:**
- Port the relevant design-file markup, renaming `mc-*`/`qa-*` → `mtb-*`.
- Never invent colours outside the `@theme` token set.
- Use `Phoenix.LiveView.JS` for all client-side interactions (no Alpine, no
  jQuery, no bespoke JS framework).
- Numbers in `font-mono` (`JetBrains Mono`). No emoji in product UI.
- Dark mode via `[data-theme="dark"]` on `<html>`; tokens provide both
  light and dark values via CSS custom properties.

---

# Foundation

### R0 · Walking skeleton

**Ships** App deploys; `/health` returns 200.

**Build**
1. `mix phx.new` (LiveView, `binary_id`, `utc_datetime`). Postgres.
2. `/health` (liveness) + `/health/ready` (DB check).
3. Dockerfile + `docker-compose` (db + platform) + `.env.example`.
4. Base layout wired to `assets/css/mtb.css` (Tailwind v4 `@theme` tokens
   ported from `designs/quoteassist/qa.css`) + fonts + dark mode.

**Data** Initial migration + `citext` extension.

**Done when** `curl /health/ready` → `{"status":"ready"}` on staging.

---

### R0a · Platform home + tenant list

**Ships** A public home page at `/` with a development status overview and a
public tenant directory at `/tenants` where each entry links to that tenant's
login page.

**Build**
1. **Home page** (`/` on the platform host) — static LiveView, no auth.
   - Header: QuoteAssist wordmark (left) + "Admin login" link → `/admin/login`
     (right). Minimal; uses `mtb.css` tokens.
   - Body: build status table — one row per release (`R0`…`R8`), columns:
     release · description · status (`done | in progress | pending`).
     Status badge styled with design-system semantic colours.
     Hard-coded in the template; update the status atom as each release lands.
   - Footer: version string from `Application.spec(:quote_assist, :vsn)` +
     environment tag (`dev | staging | prod` from config).

2. **Tenant list** (`/tenants` on the platform host) — static LiveView, no auth.
   - Simple list/table of all live tenants: name, status badge, "Login →" link.
   - "Login →" points at the tenant's **subdomain** login:
     `https://:slug.quoteassist.mytechbytes.in/login`
     (dev: `http://:slug.lvh.me:4000/login`).
   - Query: `Repo.all(Tenant)` (live only, `deleted_at` is null) ordered by
     name — public directory; shows name + status only, no sensitive data.

3. No new migrations. Both pages use the base layout from R0 (`mtb.css`,
   fonts, dark mode toggle via `Phoenix.LiveView.JS`).
   Component classes: `mtb-badge` for status, `mtb-btn` for the login link,
   standard Tailwind v4 utilities for layout.

**Routes** (platform host)
```elixir
get  "/",         PageController, :home   # or a LiveView
live "/tenants",  TenantListLive          # links out to tenant subdomains
```
Tenant subdomains aren't resolved yet — the directory just links to
`:slug.quoteassist.mytechbytes.in/login`, which 404s gracefully until R2 wires
the `TenantResolver` plug.

**Done when** `/` shows the release table with R0 marked `done`; `/tenants`
lists the seeded tenant; the "Login →" link points at the tenant subdomain.

---

### R1 · Auth — tenant users

**Ships** Tenant users can sign in and out via `/login`.

**Build**
1. `phx.gen.auth` base — `User` (email citext, hashed_password, confirmed_at,
   `deleted_at`), `UserToken`, `UserAuth` plug + `on_mount`. Tenant users only.
2. Session login/logout. Magic-link confirm for registrations/invites.
3. Login screen from `designs/quoteassist/login.html`.
   Password reveal + theme toggle via `Phoenix.LiveView.JS` only.
4. **Mailer**: Swoosh adapter + `/dev/mailbox` preview in dev. All later
   invite/verify/reset emails depend on this — wire it here.
5. **Rate limiting**: a throttle plug on `/login` (and later `/admin/login`,
   `/register`) — per-IP + per-email. Cheap now, essential on a public URL.

**Data** `users`, `users_tokens`.

**Done when** sign in → sign out works for tenant users; protected `/app`
routes redirect to `/login`; a dev email lands in `/dev/mailbox`; repeated
failed logins are throttled.
*Design: `login.html`, `verify.html`.*

---

### R2 · Tenancy + RBAC

**Ships** A request to a tenant subdomain (or verified custom domain) resolves
that tenant; signed-in users are scoped to it; cross-tenant access is impossible.

**Build**
1. `Tenant` (slug, `custom_domain`, `custom_domain_status`
   (`none|pending|verified`), `custom_domain_token`, status state-machine,
   `deleted_at`), `Membership` (user ↔ tenant + role, `deleted_at`), `Role`.
   UUID PKs, `utc_datetime`. Unique constraints on `slug` and `custom_domain`.
2. **`TenantResolver` plug** — reads the host: platform host → no tenant;
   `*.quoteassist.mytechbytes.in` → load by slug; any other host → load by
   verified `custom_domain`. Unknown / suspended / deleted → 404. Tenant
   assigned to `conn`/socket; cookies scoped to the exact resolved host.
3. `QuoteAssist.Tenancy.scope/2` — constrains every query to the resolved
   tenant; raises if no tenant in scope (fails loud on cross-tenant reads).
   Default scope also filters `deleted_at`.
4. `Policy.can?/3` + the **system permission catalog** (code-owned, seeded
   here — this is its single home; R5 only builds the roles UI on top).
5. `on_mount` guard `:require_tenant_member` on all `/app/*` live views;
   verifies the user has a live membership **for the resolved tenant**.
6. Empty `/app` workspace shell; after login users land here.
7. **`audit_logs`** table (append-only) + `Audit.log/1` helper, used from
   here on for every privileged action and state transition.

**Data** `tenants` (incl. `custom_domain*` fields), `memberships`, `roles`,
`audit_logs`.

**Seeds** One dev tenant (`acme`) + one dev user (password from
`DEV_USER_PASSWORD` env var, dev/staging only).

**Done when** `acme.lvh.me:4000` resolves the Acme tenant; its user reaches
`/app`; an unknown subdomain 404s; `Tenancy.scope/2` raises without a tenant;
a user from tenant A cannot see tenant B data; the login writes an audit row.
*(Custom-domain entry + verification ships in R-CD; the resolver already
supports the verified path.)*

---

# Site Administrator

Admin is a **completely separate identity** from tenant users — own table,
own schema, own session, own auth pipeline. No shared context with `users`
or `memberships`.

Admin logs in via `/admin/login` only. Created via a Mix task
(`mix qa.create_admin`) — no HTTP surface, no self-registration.

### Why a separate `admins` table

- `users` is tenant-scoped by design; mixing site-admin in requires nullable
  `tenant_id` and guards on every user query. Separate table = clean boundary.
- Admin auth can diverge freely: stricter password policy, MFA, IP allowlist,
  session timeout — all on `admins` without touching `users`.
- Future: multiple admins with scoped platform permissions
  (`tenant:manage`, `plan:manage`) live naturally as columns on `admins`,
  not bolted onto RBAC.
- `Accounts.register_admin/1` has a different contract to
  `Accounts.register_user/1` and should never be callable over HTTP.

### R3 · Admin identity + Tenant CRUD + 15-day trial

**Ships** Admin can log in at `/admin/login`. Admin creates, edits, suspends,
and removes tenants. New tenants start on a 15-day trial.

**Build**
1. **`admins` table + schema**
   - Columns: `id` (uuid), `email` (citext, unique), `hashed_password`,
     `last_sign_in_at`, `deleted_at`, `inserted_at`, `updated_at`.
   - No `tenant_id`. No membership. Standalone.
   - `Accounts.Admin` schema + `Accounts.register_admin/1` changeset
     (email + password validation, bcrypt hash). No HTTP route calls this.

2. **`Accounts.register_admin/1`** — the only way to create an admin.
   Called manually (iex, Mix task, or direct) on first setup. No HTTP
   route, no seed script, no env vars. Credentials exist only as a bcrypt
   hash in the `admins` row.

3. **Admin auth pipeline** — separate from user auth:
   - `AdminAuth` plug + `admin_on_mount` (reads from `admin_token` session
     key, not `user_token`).
   - `/admin/login` LiveView — email + password form; on success writes
     `admin_token` to session, sets `last_sign_in_at`, audits; redirects to
     `/admin`. Reuse the R1 throttle plug here.
   - `/admin/logout` clears `admin_token` only.
   - `admin_token` session is independent — an admin can be logged in
     alongside a tenant user session without collision.

4. **`/admin` shell + guard** — `:require_admin` on all `/admin/*` live
   views; bounces to `/admin/login`.

5. **Tenant CRUD** (`/admin/tenants`):
   - Fields: name, slug, owner email, status (state machine:
     `trial → active → suspended → cancelled`), `trial_expires_at`
     (now + 15 days), plan (Starter / Growth — seed two), `deleted_at`.
   - On create: `Ecto.Multi` — create tenant + owner `User` + owner
     `Membership` (role: `owner`); send invite email; write audit row.
   - Edit name / plan / status (status changes go through `can_transition?/2`).
   - Suspend / reactivate / **soft delete** (`deleted_at`, confirm modal).
     Hard purge is a separate, explicit, audited action — not the default.
   - Every action writes an `audit_logs` row (actor = admin).

6. **Trial expiry**: `trial_expires_at` shown in list; `UserAuth` plug
   blocks tenant user login when expired (status → `suspended` via the
   state machine, audited).

**Data** `admins`, `tenants` (`status`, `trial_expires_at`, `deleted_at`),
`plans`, `audit_logs`.

**Done when** `Accounts.register_admin/1` writes a row to `admins`; admin
logs in at `/admin/login`; tenant CRUD works; expired trial blocks tenant
login.
*Design: `admin-tenants.html`, `admin-dashboard.html`.*

---

### R4 · Self-registration (trial onboarding)

**Ships** A company self-registers and the owner lands in their workspace on
a 15-day trial. Admin can review and approve registrations.

**Build**
1. Public `/register` (platform host): company name, owner name + email.
   Defaults to Starter plan; no vertical picker yet. Throttled (R1 plug).
2. `Ecto.Multi`: create `Tenant` (status `pending`, 15-day expiry) + owner
   `User` (reuse existing row if email already known) + owner `Membership`
   (role: `owner`). Audited.
3. Email verify → set password → wait for admin approval.
4. `/admin/registrations`: list pending / approved / rejected; admin
   approves (tenant `pending → trial`, emails owner) or rejects (with note).
   Every decision is audited.

**Data** Reuses `tenants`, `users`, `memberships`, `users_tokens`.

**Done when** company self-registers, verifies email, admin approves, owner
lands in `/app`.
*Design: `register.html`, `verify.html`.*

---

# Tenant Basics

Everything below is tenant-scoped. Resolve `tenant_id` from the session
membership — never from params.

### R5 · Users, roles, permissions

**Ships** Tenant owner invites users and composes roles from a fixed
permission catalog.

**Build**
1. **Roles UI** over the permission catalog defined in R2 (catalog is
   code-owned and read-only in the UI — admins compose, never invent).
2. **Roles CRUD** — name + permission checkboxes; tenant-scoped; `deleted_at`.
3. **Users** — invite by email (reuse existing `User` if email known; token →
   set password → join tenant via new membership); assign role;
   deactivate / soft-remove. All actions audited.
4. Guard: the last live membership with `user:manage` cannot be removed or
   demoted (tenant can't lock itself out).

**Data** `roles`, `memberships`, `users_tokens` (invite type).

**Done when** owner invites a user, assigns a role, user signs in with
correct permissions; removing the last manager is blocked.
*Design: `team.html`.*

---

### R6 · Account flows

**Ships** Users can recover access and manage their profile.

**Build**
1. Forgot password → email token → reset password
   (`/forgot`, `/reset/:token`).
2. Change password in settings (requires current password).
3. Profile page: display name, avatar upload (local for now), timezone.

**Data** `users_tokens` (reset type); `users.display_name`,
`users.avatar_url`, `users.timezone`.

**Done when** a user can recover a lost password and update their profile
without admin involvement.
*Design: `forgot.html`, `reset.html`, `profile.html`, `settings.html`.*

---

### R-CD · Custom domain

**Ships** A tenant owner adds their own domain (e.g. `quotes.acme.com`),
verifies ownership, and the app serves on it with automatic TLS. The platform
subdomain keeps working as a permanent fallback.

**Build**
1. **Settings UI** (`/app/settings/domain`, owner-only via `tenant:manage`):
   - Show current platform subdomain (always active).
   - Field to enter a custom domain → saves `custom_domain` as `pending`,
     generates a `custom_domain_token`.
   - Display the required DNS records: a `CNAME` →
     `<slug>.quoteassist.mytechbytes.in` and a `TXT` record carrying the
     verification token. Copy-to-clipboard via `Phoenix.LiveView.JS`.
2. **Verification** — "Verify" button performs a DNS lookup (`:inet_res`) for
   the TXT token; on match sets `custom_domain_status = verified`. Re-checkable;
   a background job can also re-verify periodically and flag drift.
3. **On-demand TLS gate** — internal endpoint
   `GET /tls/check?domain=<host>` returns 200 only if `<host>` matches a
   `verified` custom domain (else 403). Caddy's `on_demand_tls` `ask` points
   here, so certs are only issued for domains a tenant actually owns —
   prevents cert-issuance abuse.
4. **Resolver** already handles the verified custom-domain path (R2); this
   release just populates and verifies the data it reads.
5. **Remove / change** — owner can clear or replace the domain (back to
   `none`/`pending`); audited.

**Data** `tenants.custom_domain*` (added in R2 — no new migration needed
unless adding a verification-attempts log).

**Deploy & verify** On staging, point a test domain's CNAME + TXT at the
platform, verify, and load the app over `https://<test-domain>` with a valid
cert. Subdomain still works.

**Done when** a verified custom domain serves the tenant with auto-TLS, the
subdomain remains a working fallback, and unverified/unowned hosts get neither
a tenant nor a certificate.
*Design: extends `settings.html` (domain section).*

---

# Leads / Quotes

A **quote request = a lead**. Every inbound request is captured as a lead;
the reply (manual now, AI later) is the quote.

### R7 · Quote request CRUD

**Ships** Tenant users create, view, edit, and close quote requests.

**Build**
1. `QuoteRequest`: tenant_id, submitted_by, customer_name, customer_email,
   subject, body (free text), status (state machine:
   `open → in_progress → quoted → closed`), `deleted_at`, timestamps.
2. List view — status filter + search; card and table toggle. Live rows only.
3. Create form — customer details + request body.
4. Detail view — status badge + activity timeline (from `audit_logs`).
5. Edit / close / reopen — transitions via `can_transition?/2`, audited.

**Data** `quote_requests` (`status`, `deleted_at`).

**Done when** a user creates a request, sees it in the list, and updates
its status.
*Design: `quotes.html`, `get-quote.html`, `quote-detail.html`.*

---

### R8 · Quote reply + AI hook

**Ships** Users send a reply to a quote request. The reply is generated by
the AI service (stub now; real service swaps in later — no screen changes).

**Build**
1. Reply thread on quote detail — ordered messages (`quote_messages`:
   quote_request_id, author_type `human|ai`, body, inserted_at).
2. **Manual reply** — textarea + Send; appends a `human` message.
3. **AI reply stub** — "Generate with AI" button calls
   `AIService.generate_reply/1` which returns a placeholder string.
   When the real Python service is ready, only this function changes.
4. Generated reply lands in the textarea for review before sending
   (human-in-the-loop; no auto-send ever).
5. Sent message appended to thread; status `in_progress → quoted` via the
   state machine; send is audited.

**Data** `quote_messages`.

**Done when** user generates (stub) and sends a reply; thread shows both
sides; status updates correctly. Swapping stub for real AI needs no UI
changes.
*Design: `quote-detail.html`, `requirements.html`.*

---

## Build order

```
R0 → R0a → R1 → R2    foundation: skeleton · home+tenants · auth · tenancy+RBAC
  → R3 → R4            site admin: tenant CRUD+trial · self-registration
  → R5 → R6 → R-CD     tenant basics: users/roles · account flows · custom domain
  → R7 → R8            leads/quotes: request CRUD · AI reply hook
```

Each arrow = a staging deploy. Keep `mix test` green throughout.
