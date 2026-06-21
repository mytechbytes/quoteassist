# Platform Release Plan — QuoteAssist (`services/platform`)

> **Authoritative release plan for the Phoenix platform.** This is the single
> source of truth for the R0–R12 build order, cross-cutting decisions, and the
> design-system contract. `CLAUDE.md` (root and platform) summarises and points
> here; if they ever disagree, this file wins.

Phoenix + LiveView only. AI service slots in later without changing these screens.
Every release is independently deployable to staging.

## One rule: always deployable

Build in thin vertical slices. After each `R#` you can deploy and demo. Tenant
isolation from R2 onward — scope every query through
`QuoteAssist.Tenancy.scope/2`; resolve `tenant_id` from the host / session,
never from params.

**Definition of done — the green gate.** A release is not "done" (and not
deployable) until **all four** pass. This is the contract behind every "Done
when" below; `make check` runs them in order and CI enforces them:

1. **Compiles clean** — `mix compile --warnings-as-errors`. No warnings, ever.
2. **Quality check** — `mix format --check-formatted` + `mix credo --strict`.
   Formatting and linting both clean.
3. **Dialyzer** — `mix dialyzer` passes with no new warnings (typespecs on
   public functions; PLT cached in CI).
4. **Tests + coverage** — `mix test` green **and** coverage **> 95%**
   (`mix coveralls` / ExCoveralls, with a `min_coverage 95` threshold that
   fails the build below it).

A slice that compiles but is unformatted, fails Dialyzer, or dips under 95%
coverage is **not** shippable — fix it before moving to the next `R#`.

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
4. A live but **suspended** tenant → render a branded suspension notice with status
   **403** (the workspace exists; access is forbidden). No match / cancelled /
   deleted → 404.
Tenant assigned to `conn`/socket; cookies scoped to the **exact resolved host**
(never `.quoteassist.mytechbytes.in`) so sessions never leak across tenants or
between a tenant's subdomain and its custom domain.

**Custom domain lifecycle** (tenant-configurable, see R10-domain below):
- Tenant enters their domain → system stores it `pending` + issues a DNS
  verification token (TXT record) and the CNAME target
  (`<slug>.quoteassist.mytechbytes.in`).
- A verification check confirms the TXT record → status `verified`.
- TLS for verified custom domains is issued automatically by **Caddy on-demand
  TLS**, gated by an internal `/tls/check?domain=` endpoint that only authorises
  hostnames matching a `verified` custom domain (prevents cert-issuance abuse).
- A custom domain is unique across all tenants (DB unique constraint).

**Environments:**
- **Dev:** `*.quoteassist.localhost` for subdomains (`acme.quoteassist.localhost:4000`); custom-domain logic
  testable by mapping a hosts-file entry.
- **Prod:** wildcard DNS `*.quoteassist.mytechbytes.in` + Caddy wildcard TLS for
  subdomains; Caddy on-demand TLS for verified custom domains.
- Admin stays on the platform host — never a tenant subdomain or custom domain.

### User ↔ tenant cardinality — **many-to-many via `memberships`**

A `User` is a global identity (unique email); tenant association lives only on
`memberships`. One email can belong to multiple tenants (one membership each).
Invite-by-email (R7-rbac) reuses the existing `User` row if the email already
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
ops, self-registration events, suspend/cancel, user/role changes, quote status
transitions).
Columns: `actor_type` (`admin|user|system`), `actor_subtype`
(`super_admin|admin|owner|member|null` — captures the tier so "which admin/owner
tier did this" is answerable), `actor_id`, `tenant_id` (nullable for platform
actions), `action`, `target_type`, `target_id`, `metadata` (jsonb),
`inserted_at`. Append-only — no update/delete. Never store full message bodies;
store references + masked values.

### Status fields are state machines

Both `tenant.status` (`trial → active → suspended → cancelled`) and
`quote_request.status` (`open → in_progress → quoted → closed`) are modelled as
explicit state machines with a `can_transition?/2` guard (Fsmx or a hand-rolled
transition map). The schema validates transitions; illegal jumps (e.g.
`closed → in_progress`) are rejected at the changeset, never reachable from the
UI. Every transition writes an `audit_logs` row.

### Session revocation on deactivate / suspend

Account state and live sessions must not drift apart. Two rules:

- **Deactivating a user or admin revokes all their active sessions** — delete
  their `*_tokens` rows in the same transaction as flipping `active = false`.
  The `active` flag gates *future* logins; token deletion kills *current* ones.
- **Suspending or cancelling a tenant** revokes all that tenant's member
  sessions the same way.

**Enforcement is at the next request, not via forced socket teardown** (chosen
for simplicity): the `UserAuth` / `TenantResolver` / `AdminAuth` plugs re-check
`active` + tenant status + token validity on every HTTP request, so a revoked
session is rejected the next time the browser hits the server (navigation, live
nav, or socket reconnect). A long-lived LiveView socket already connected may
stay open until its next HTTP touch — acceptable because (a) tokens are gone so
it can't re-establish, and (b) any navigation re-runs the plug. We do **not**
broadcast a kill-signal to live sockets in this phase; if immediate teardown is
needed later, add a PubSub `disconnect` broadcast keyed on user/tenant id.

### Trial expiry is checked at login (not continuously)

`trial_expires_at` is enforced by the `UserAuth` plug **at login** (R3): an
expired trial blocks new logins and flips the tenant to `suspended`. A member
already mid-session when the clock passes expiry keeps that session until it
ends or they re-auth — **this is an accepted limitation** for a 15-day trial,
not a gap. (If continuous expiry is ever required, it rides the same
plug-recheck mechanism as session revocation above.)

### Registration is auto-approve to trial (no proactive gate)

Self-registration (R5-selfreg) creates the tenant directly in `trial` — there is **no
`pending` state and no admin approval queue**. This matches the self-serve
norm: instant access is the point, and the trial sandbox (15-day clock, AI
auto-send disabled) is the safety mechanism, not a human reviewer.

The only signup-time check is **email verification** of the owner. Custom-domain
ownership is verified separately and only when a tenant opts into one (R10-domain).

The admin's role is **reactive, not proactive**: they don't approve signups,
they **suspend** (`trial/active → suspended`) or **cancel** (`→ cancelled`)
tenants after the fact when something is abusive or wrong — using the same
tenant-CRUD controls already built in R3. A suspended tenant's host resolves but
renders a suspension notice; a cancelled tenant 404s. "Rejection" of a bad
self-signup is therefore just an admin suspend/cancel, handled entirely from the
admin tenant list.

### Two parallel RBAC systems + a protected root type

There are **two independent RBAC systems** that mirror each other in shape but
never share rows:

- **Admin RBAC** (platform side, on the `admins` identity) — roles +
  permissions over *platform* resources (tenants, plans, audit, admins).
- **Tenant RBAC** (on `memberships`) — roles + permissions over *tenant*
  resources (quotes, users, roles, settings, domain). Tenant-scoped.

On **each** side a **type sits above the role** and gates authorization before
any role/permission check runs:

| Side   | Protected type | Normal type | Role lives on  |
|--------|----------------|-------------|----------------|
| Admin  | `super_admin`  | `admin`     | the admin      |
| Tenant | `owner`        | `member`    | the membership |

The authorization predicate on both sides is:
```
can?(actor, perm) =
  actor.type in [:super_admin, :owner]   # protected type → always true
  or perm in permissions(actor.role)     # normal type → role-driven
```

**The protected type (`super_admin` / `owner`) is the root pattern.** It holds
**all permissions, computed** — a short-circuit `true`, never an enumerated
list — so any permission added in a future release is held automatically with no
migration and nothing to edit. Both protected types obey the same five
invariants:

1. **Computed all-access.** Protected type bypasses the catalog entirely.
2. **Invisible to lower types — enforced at the query layer, not the view.**
   A `member`/`admin` (even one with `user:list` / `role:list` / `user:update`)
   cannot list or see protected-type holders, nor see the protected type/role
   itself. Lists are scoped to *exclude* them in the query — hiding only in the
   template is a security bug. Same discipline as `Tenancy.scope/2`.
3. **Immutable to lower types.** The protected type/role and its holders cannot
   be edited by a non-protected actor. (There's nothing to edit on the role
   anyway — its power is code, not data.)
4. **Unassignable by lower types.** A `member`/`admin` can never grant the
   protected type or assign a holder to it, by any path. Only an existing
   protected-type actor can see, list, edit, or assign the protected type.
5. **Last-active guard, transactional.** At least one **active** protected-type
   actor must always exist. The system refuses to deactivate/delete the last
   active one. The count + the mutation run in the **same transaction**
   (`SELECT … FOR UPDATE` or a DB constraint) so concurrent deactivations can't
   race past the guard.

Admin: many users may hold `super_admin`; ≥1 active always. Tenant: many
memberships may be `owner`; ≥1 active owner per tenant always.

### Permission catalog convention — CRUD-grained + lifecycle + `self:*`

Every permission is a `resource:action` key. The catalog is code-owned and
seeded; roles are composed from it (the protected types ignore it entirely).

**Base actions** — every *collection* resource gets all five:
`list` (see the collection) · `create` · `read` (see one record) ·
`update` · `delete`. `list` and `read` are deliberately distinct (seeing a
table vs. opening a record).

**Lifecycle actions** — `activate` and `deactivate` are **separate**
permissions (never a single toggle) on every actor-like resource, so a junior
role can be allowed to deactivate but not reactivate. State-machine verbs that
carry judgment (`suspend`, `cancel`, `purge`, `verify`, `status`) are their own
permissions too — separable from plain `update`.

**Meaningful-subset rule** — resources only get actions that can actually fire:
- *Collection* resources (tenant, plan, admin, admin_role, quote, user, role) →
  all five base actions (+ their extras).
- *Singleton* resources (settings, domain, billing) → `read` / `update` only
  (+ extras like `domain:verify`); no `list`/`create`/`delete` no-op keys.
- *Append-only* resources (audit) → `list` / `read` only.

No dead permissions in the role-builder UI.

**`self:*` is a fixed baseline, not role-composable.** Acting on your *own*
record is distinct from acting on the resource collection (`user:update` =
"edit any member"; editing your own profile must not require that). So every
authenticated identity — admin or member, regardless of role — implicitly has:

| `self:*` | Meaning |
|----------|---------|
| `self:read`     | View own profile |
| `self:update`   | Edit own profile (name, avatar, timezone) |
| `self:password` | Change own password |
| `self:email`    | Change own email (triggers re-verify) |
| `self:sessions` | View / revoke own active sessions |
| `self:mfa` *(later)* | Manage own 2FA/TOTP |

These never appear as role checkboxes and can't be removed — they're scoped
implicitly to the actor's own row, so they grant no access to anyone else's
data. Protected types have them via all-access; everyone else has them by
baseline. (Raising a leave request is **not** a `self:*` baseline — it's
`request:create` in the tenant catalog; see the requests model above.)

**Leaving is owner-mediated via the request system, not self-service.** There is
no `self:delete` / self-leave button. A member raises a **tenant request** of
type `leave` (baseline `request:create`); the owner (or a member with
`request:manage`) processes it with a status. Approving a `leave` request removes
the membership through the normal `user:delete` path (subject to the last-active-
owner guard). See the `requests` model below — `leave` is one request type; the
table is built to carry other request types (access, plan-change, support, etc.)
without a new schema each time.

### Tenant requests — a generic request inbox

A single `requests` table backs member→owner asks, of which `leave` is the first
type. It's an internal IT-style request queue, owner-processed, with a status:
```
requests
  id            uuid
  tenant_id     uuid           # tenant-scoped
  type          enum           # :leave | (future: :access, :plan_change, :support …)
  requested_by  uuid           # membership id
  status        enum           # :open → :approved | :declined | :cancelled
  note          text           # requester's reason
  resolution    text           # owner's note on approve/decline
  resolved_by   uuid  null     # membership id of processor
  resolved_at   utc_datetime null
  deleted_at    utc_datetime
  inserted_at   utc_datetime
```
- A member may have **at most one open request per type** (DB partial unique on
  `tenant_id, requested_by, type` where `status = :open`).
- `status` is a small state machine (`open → approved|declined|cancelled`); the
  requester can `cancel` their own open request; only `request:manage` holders
  approve/decline. Every transition is audited.
- If the requester's membership is removed by another path while a request is
  open, the request is soft-deleted alongside it.

**Membership-scoped, not identity-scoped.** Tenant-side `user:*` operates on the
**membership** row (this tenant only), never the global `User`. Deactivating
someone in tenant A leaves their tenant-B membership untouched; `Tenancy.scope/2`
enforces this.

### Plans are DB-backed with feature limits

Plans are **not** bare labels — they're rows in a `plans` table (platform-level,
no `tenant_id`), each carrying a set of feature limits that shape tenant usage.
A tenant references its plan by id; limits are read from the plan, never copied
onto the tenant.

`plans` schema (shape adapted from the MangoCMS platform layer):
```
plans
  id            uuid
  name          string         # "Starter" / "Growth" / "Scale"
  slug          string  unique
  price         integer        # smallest currency unit (paise); 0 = free
  interval      enum           # :monthly | :yearly
  limits        jsonb          # feature limits (below)
  active        bool           # offerable to new tenants
  deleted_at    utc_datetime
```

`limits` keys (the entitlement dimensions for a lead-to-quote tool):
- `quotes_per_month` — quote requests creatable per calendar month
- `seats` — max active memberships (users) per tenant
- `ai_generations_per_month` — "Generate with AI" calls per month
- `custom_domain` — boolean, whether the tenant may add a custom domain (R10-domain)

**Seed exactly three plans now** (Starter / Growth / Scale) with ascending
limits; e.g. Starter = {quotes 50, seats 3, ai 50, custom_domain false},
Growth = {quotes 500, seats 10, ai 500, custom_domain true},
Scale = {quotes 5000, seats 50, ai 5000, custom_domain true}.

**Enforcement is deferred but the data exists now.** R4-retrofit ships `plan:*` CRUD over
this table and tenants carry a `plan_id` from R3; *enforcing* the limits
(blocking the 51st quote, gating custom domain on the plan flag) is a later,
post-AI concern. Modelling the table now means no migration when enforcement
lands — the limits are simply read and ignored until then.

---

## Release Index

**Shipped record (R0–R3) — frozen.** R0–R3 are shipped; they're kept verbatim as
the build record and are **not** renumbered or rewritten. Everything after R3 was
resequenced into a clean R4–R12 order (the suffixes are descriptive labels).

| #              | Track         | Outcome                                    |
|----------------|---------------|--------------------------------------------|
| R0             | Foundation    | App deploys; `/health` green  ✅ done       |
| R0a            | Foundation    | Platform home `/` + tenant list `/tenants` ✅ done |
| R1             | Foundation    | Auth — sign in / out  ✅ done               |
| R2             | Foundation    | Tenancy + RBAC (subdomain + custom domain) ✅ done |
| R3             | Site Admin    | Admin identity + Tenant CRUD + 15-day trial ✅ done |
| R4-retrofit    | Site Admin    | Admin RBAC + protected `super_admin` (retrofits R3) ✅ done |
| R5-selfreg     | Site Admin    | Self-registration → auto-approve to trial  ✅ done |
| R6-errors      | Foundation    | Error pages (401/403/404/500/503)          ✅ done |
| R7-rbac        | Tenant Basics | Users, roles, permissions + self:* + requests ✅ done |
| R8-dashboard   | Tenant Basics | `/app` dashboard landing                   ✅ done |
| R9-recovery    | Tenant Basics | Account recovery (forgot/reset, email-change) ✅ done |
| R10-domain     | Tenant Basics | Custom domain (add, verify, auto-TLS)      ✅ done |
| R11-quotes     | Leads/Quotes  | Quote request CRUD (lead capture)          ✅ done |
| R12-quote-reply| Leads/Quotes  | Quote detail + AI reply hook (stub → live) ✅ done |

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
   - Body: build status table — one row per release in the Release Index
     (`R0`…`R12`, including `R0a`, `R4-retrofit`, `R5-selfreg`, `R6-errors`,
     `R8-dashboard`, `R10-domain`), columns:
     release · description · status (`done | in progress | pending`).
     Status badge styled with design-system semantic colours.
     Hard-coded in the template; update the status atom as each release lands.
   - Footer: version string from `Application.spec(:quote_assist, :vsn)` +
     environment tag (`dev | staging | prod` from config).

2. **Tenant list** (`/tenants` on the platform host) — static LiveView, no auth.
   - Simple list/table of all live tenants: name, status badge, "Login →" link.
   - "Login →" points at the tenant's **subdomain** login:
     `https://:slug.quoteassist.mytechbytes.in/login`
     (dev: `http://:slug.quoteassist.localhost:4000/login`).
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
   `deleted_at`), `Membership` (user ↔ tenant, **`type`** (`owner|member`),
   **`role_id`** (null for owners, required for members), `active` bool,
   `deleted_at`), `Role` (tenant-scoped, name, `deleted_at`),
   `RolePermission` (role ↔ permission key). UUID PKs, `utc_datetime`.
   Unique constraints on `slug` and `custom_domain`.
2. **`TenantResolver` plug** — reads the host: platform host → no tenant;
   `*.quoteassist.mytechbytes.in` → load by slug; any other host → load by
   verified `custom_domain`. A live but suspended tenant → branded 403 suspension
   notice (added in R6-errors); unknown / cancelled / deleted → 404. Tenant
   assigned to `conn`/socket; cookies scoped to the exact resolved host.
3. `QuoteAssist.Tenancy.scope/2` — constrains every query to the resolved
   tenant; raises if no tenant in scope (fails loud on cross-tenant reads).
   Default scope also filters `deleted_at`.
4. **Tenant permission catalog + `Policy.can?/3`** (code-owned, seeded here —
   this is its single home; R7-rbac only builds the roles UI on top). Per the
   catalog convention (CRUD-grained + lifecycle + meaningful-subset):

   | Resource | Base | Extras |
   |----------|------|--------|
   | quote    | `quote:list` `quote:create` `quote:read` `quote:update` `quote:delete` | `quote:status`, `quote:reply`, `quote:ai_generate` |
   | user *(membership)* | `user:list` `user:create` `user:read` `user:update` `user:delete` | `user:activate`, `user:deactivate` |
   | role     | `role:list` `role:create` `role:read` `role:update` `role:delete` | — |
   | request  | `request:list` `request:create` `request:read` `request:update` `request:delete` | `request:manage` (approve/decline) |
   | settings *(singleton)* | `settings:read` `settings:update` | — |
   | domain *(singleton)* | `domain:read` `domain:update` | `domain:verify` |
   | billing *(singleton, later)* | `billing:read` `billing:update` | — |

   Plus the fixed `self:*` baseline (`self:read/update/password/email/sessions`)
   held implicitly by every member — not in the catalog, not role-composable.
   `request:create` (raise a leave/other request) is baseline-granted to every
   member too, but lives in the catalog so owners can also compose it into roles.
   `user:*` operates on the **membership**, not the global `User`.

   `Policy.can?/3` implements the protected-type predicate: `owner` →
   short-circuit `true`; `member` → permission must be in its role (or be a
   `self:*` baseline).
5. **Owner protection** (the protected-type pattern, tenant side): owners are
   invisible/immutable/unassignable to members at the **query layer** —
   member-run user/role lists exclude owners and the owner type; members cannot
   grant `owner` or edit an owner; `Tenancy` exposes
   `members_visible_to/1` + `assignable_types_for/1` helpers so this isn't
   re-implemented per LiveView. Last-active-owner guard is transactional.
6. **Seeded system roles** (per tenant, for members): `manager`, `agent`
   (definitions in R7-rbac). Owner needs no role.
7. `on_mount` guard `:require_tenant_member` on all `/app/*` live views;
   verifies the user has a live, active membership **for the resolved tenant**.
8. Empty `/app` workspace shell; after login users land here.
9. **`audit_logs`** table (append-only) + `Audit.log/1` helper, used from
   here on for every privileged action and state transition.

**Data** `tenants` (incl. `custom_domain*`), `memberships` (`type`, `role_id`,
`active`), `roles`, `role_permissions`, `audit_logs`.

**Seeds** One dev tenant (`acme`) + one dev user (password from
`DEV_USER_PASSWORD` env var, dev/staging only).

**Done when** `acme.quoteassist.localhost:4000` resolves the Acme tenant; its user reaches
`/app`; an unknown subdomain 404s; `Tenancy.scope/2` raises without a tenant;
a user from tenant A cannot see tenant B data; the login writes an audit row.
*(Custom-domain entry + verification ships in R10-domain; the resolver already
supports the verified path.)*

---

# Site Administrator

Admin is a **completely separate identity** from tenant users — own table,
own schema, own session, own auth pipeline. No shared context with `users`
or `memberships`.

Admin logs in via `/admin/login` only. Created by calling
`Accounts.register_admin/1` directly (iex or a one-off script) on first setup —
no HTTP surface, no self-registration.

### Why a separate `admins` table

- `users` is tenant-scoped by design; mixing site-admin in requires nullable
  `tenant_id` and guards on every user query. Separate table = clean boundary.
- Admin auth can diverge freely: stricter password policy, MFA, IP allowlist,
  session timeout — all on `admins` without touching `users`.
- Multiple admins with scoped platform permissions and a protected
  `super_admin` root type live on the `admins` side (R4-retrofit), entirely separate
  from tenant RBAC.
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
     (now + 15 days), `plan_id` (FK → `plans`; see the Plans cross-cutting
     decision — seed **three**: Starter / Growth / Scale), `deleted_at`.
   - On create: `Ecto.Multi` — create tenant + owner `User` + owner
     `Membership` (**`type: :owner`**, no role); send onboarding email; write
     audit row. **Owner email must be unused** — if a `User` with that email
     already exists, the create fails with a clear "email already in use" error
     (admin path does *not* silently reuse; that reuse rule is R5-selfreg-only, where
     the person is self-asserting their own email).
   - Edit name / plan / status (status changes go through `can_transition?/2`).
   - Suspend / reactivate / **soft delete** (`deleted_at`, confirm modal).
     Hard purge is a separate, explicit, audited action — not the default.
   - Every action writes an `audit_logs` row (actor = admin).

6. **Trial expiry**: `trial_expires_at` shown in list; `UserAuth` plug
   blocks tenant user login when expired (status → `suspended` via the
   state machine, audited).

**Data** `admins`, `plans` (seed three — Starter/Growth/Scale, per the Plans
cross-cutting decision), `tenants` (`status`, `trial_expires_at`, `plan_id`,
`deleted_at`), `audit_logs`.

**Done when** `Accounts.register_admin/1` writes a row to `admins`; admin
logs in at `/admin/login`; tenant CRUD works; expired trial blocks tenant
login.
*Design: `admin-tenants.html`, `admin-dashboard.html`.*

---

### R4-retrofit · Admin RBAC + protected `super_admin`

**Ships** Platform admins have roles and per-resource permissions (admin-side
catalog). `super_admin` is a protected root type holding all admin permissions,
invisible and unassignable to ordinary admins, with a last-active guard.

> **Retrofits completed R3.** R3 shipped `admins` with no `type`/`role_id`/
> `active` and a single `:require_admin` guard. This release **migrates the
> existing table** and **promotes the already-created bootstrap admin to
> `super_admin`** in the same migration transaction (so the "≥1 active
> super_admin" invariant holds the instant the column exists). It also
> retro-gates the R3 tenant-CRUD actions behind the new `tenant:*` permissions.
> Treat the R3 steps below as amended, not rebuilt.

**Build**
1. **Migration over the R3 `admins` table**: add `type`
   (`super_admin | admin`, default for existing row → `super_admin`), `role_id`
   (null for super_admin, required for normal admin), `active` bool
   (default true). Backfill the existing bootstrap admin as
   `type: :super_admin, active: true` in the same transaction.
   Add `AdminRole` + `AdminRolePermission` (admin-side, separate tables from the
   tenant `roles`/`role_permissions`).
2. **Admin permission catalog** (code-owned, seeded — single home here). Per
   the catalog convention (CRUD-grained + lifecycle + meaningful-subset):

   | Resource | Base | Extras |
   |----------|------|--------|
   | tenant   | `tenant:list` `tenant:create` `tenant:read` `tenant:update` `tenant:delete` | `tenant:activate`, `tenant:deactivate`, `tenant:suspend`, `tenant:cancel`, `tenant:purge` |
   | plan     | `plan:list` `plan:create` `plan:read` `plan:update` `plan:delete` | — |
   | admin    | `admin:list` `admin:create` `admin:read` `admin:update` `admin:delete` | `admin:activate`, `admin:deactivate` |
   | admin_role | `admin_role:list` `admin_role:create` `admin_role:read` `admin_role:update` `admin_role:delete` | — |
   | audit *(append-only)* | `audit:list` `audit:read` | — |

   Plus the same fixed `self:*` baseline held implicitly by every admin.

3. **`AdminPolicy.can?/3`** — protected-type predicate: `super_admin` →
   short-circuit `true` (all permissions, computed; future permissions included
   automatically); `admin` → permission must be in its role.
4. **`super_admin` protection** (the five invariants from cross-cutting,
   enforced at the **query layer**):
   - A non-super-admin's admin/role lists **exclude** super_admin users and the
     `super_admin` type/role — scoped in the query, not hidden in the template.
   - A non-super-admin cannot edit a super_admin, the super_admin role, or grant
     `super_admin` by any path.
   - Only a super_admin can list / view / edit / assign super_admins.
   - **Last-active super_admin** cannot be deactivated or deleted; the count +
     mutation run in one transaction (`SELECT … FOR UPDATE`).
   - `super_admin` is a fixed system type — not deletable, not editable; its
     all-access is code, not a stored permission set.
5. **Admin management UI** (`/admin/admins`, gated by `admin:list` /
   `admin:create` / `admin:update` / `admin:activate` / `admin:deactivate` as
   appropriate): normal admins manage only normal admins and admin roles;
   super_admins additionally see and manage super_admins. Tenant-CRUD actions
   are wired to the matching `tenant:*` permissions (e.g. suspend →
   `tenant:suspend`, purge → `tenant:purge`).
6. The bootstrap admin created by `Accounts.register_admin/1` is a
   **`super_admin`** (so there's always ≥1 from first setup).

**Data** `admins` (`type`, `role_id`, `active`), `admin_roles`,
`admin_role_permissions`, admin permission catalog (seeded).

**Done when** a super_admin can create a scoped normal admin; that normal admin
cannot see, edit, or create any super_admin (verified at the query layer, not
just UI); the last active super_admin cannot be deactivated; every admin action
is permission-checked and audited.
*Design: extends `admin-*.html` (admins + roles sections).*

---

### R5-selfreg · Self-registration → auto-approve to trial

**Ships** A company self-registers on the platform host and the owner lands in
their workspace on a 15-day trial **immediately** — no admin approval. Email
verification is the only signup-time check. The admin manages bad actors
reactively via the R3 tenant controls (suspend / cancel).

**Why no approval queue** — see "Registration is auto-approve to trial" in
cross-cutting. Instant access is the whole point of a self-serve trial; the
sandbox + 15-day clock + AI auto-send-disabled is the safety net, and a human
gate scales poorly while killing trial conversion. Rejection = an admin suspend,
not a pre-entry gate.

**Build**
1. Public `/register` (platform host): company name, desired slug, owner name +
   email. Defaults to Starter plan; no vertical picker yet. Throttled (R1 plug).
   - Slug validated for format + uniqueness + a reserved-word blocklist
     (`www`, `admin`, `app`, `api`, `mail`, … and brand-safety terms).
2. **`Ecto.Multi`** (audited as `actor_type: :system`):
   - Create `Tenant` directly in **`trial`** (`trial_expires_at` = now + 15d,
     `plan_id` = the seeded Starter plan).
   - Create owner `User` (unconfirmed; reuse existing row if email already
     known — this is the self-asserting path where reuse is correct, unlike the
     admin path in R3) + owner `Membership` (**`type: :owner`**, no role).
   - Issue an onboarding token with an explicit TTL (e.g. 7 days).
3. **Onboarding on the platform host** (the tenant subdomain already resolves
   because the tenant is `trial`, but onboarding stays on the platform host so
   the same flow serves invited users in R7-rbac and works regardless of host state):
   - Owner gets a `quoteassist.mytechbytes.in/onboarding/:token` link.
   - `OnboardingLive` — set password + confirm email in one transaction
     (`hashed_password` **and** `confirmed_at` set together; that pair is the
     single "ready to log in" predicate).
   - On success → redirect to the tenant host
     `<slug>.quoteassist.mytechbytes.in/login`; owner logs in, lands in `/app`.
   - **Expired token** → the resend-onboarding action (step 4) issues a fresh
     one; expiry never strands the owner.
4. **Unconfirmed-owner safety net** — if an owner reaches the tenant-host login
   before finishing onboarding, show "finish setting up your account" with a
   resend-onboarding action, never a dead password form.
5. **Email verification policy** — owner must confirm before first tenant-host
   login (onboarding does both at once, so this is automatic). No separate
   approval step exists.
6. **No `/admin/registrations` queue.** Self-signups appear in the existing
   `/admin/tenants` list like any other tenant; the admin suspends or cancels
   abusive ones there (reactive). Optionally surface a "self-registered" filter
   + a `source: :self_signup | :admin` column on `tenants` for triage.

**Data** Reuses `tenants`, `users`, `memberships`, `users_tokens`; optional
`tenants.source` column for triage.

**Done when** a company self-registers, sets its password on the platform-host
onboarding link, and logs in on its already-resolving `trial` subdomain landing
in `/app` — with no admin action in the loop. An admin can later suspend or
cancel that tenant from `/admin/tenants`, and a suspended tenant sees the
suspension notice while a cancelled one 404s.
*Design: `register.html`, `verify.html`.*

---

### R6-errors · Error pages

**Ships** Branded error pages for the states the app can return — wired to real
Phoenix error handling, not just static HTML. 403 matters most now that every
route is permission-gated (R4-retrofit + R7-rbac).

**Build**
1. Map each status to its design file and a Phoenix render path:
   - `401` unauthenticated → redirect to the right login (tenant vs admin host).
   - `403` forbidden → permission/owner-protection denial (a member hitting an
     owner-only route, an admin lacking a `*:` permission), **and a suspended
     tenant host** (live but paused — its own branded "workspace suspended" notice).
   - `404` not found → unknown route, unknown/cancelled/deleted tenant host,
     missing record.
   - `500` server error → `ErrorHTML`/`ErrorJSON` fallback.
   - `503` maintenance → behind a config flag for deploys.
2. Wire via `Phoenix.Router` error handling + a `FallbackController` for
   controller actions and an `on_mount` denial path for LiveViews (raise
   `:unauthorized` → 403 page rather than a crash).
3. Host-aware: a 401 on a tenant host goes to that tenant's `/login`; on the
   platform/admin host to `/admin/login`.
4. Use the design files; `mtb-*` classes; no emoji.

**Data** None.

**Done when** an unauthenticated request, a permission denial, an unknown path,
and a forced 500 each render the correct branded page; a member hitting an
owner-only route gets the 403 page (not a crash or a blank redirect).
*Design: `error-401.html`, `error-403.html`, `error-404.html`,
`error-500.html`, `error-503.html`.*

---

# Tenant Basics

Everything below is tenant-scoped. Resolve `tenant_id` from the session
membership — never from params.

### R7-rbac · Users, roles, permissions

**Ships** Owners (and members with the right permission) invite members,
compose roles from the fixed catalog, and assign them. Owners are protected the
same way `super_admin` is on the platform side.

**Build**
1. **Seeded system roles** (created per tenant; for `member` memberships),
   composed from the R2 CRUD-grained catalog:
   - **`manager`** — `quote:*` (all, incl. `status`/`reply`/`ai_generate`);
     `user:list/create/read/update/activate/deactivate`; `role:list/read`;
     `settings:read/update`. *(No `role:create/update/delete` — only owners
     shape the permission structure. No `user:delete`, `domain:*`, `billing:*`.)*
   - **`agent`** — `quote:list/create/read/update/status/reply/ai_generate`;
     `user:list/read`. *(No `quote:delete`, no user mutation, no settings.)*
   Owners need no role (computed all-access). Every member also has the fixed
   `self:*` baseline automatically.
2. **Roles UI** over the R2 catalog (catalog is code-owned, read-only;
   tenants compose custom roles from it — never invent permissions). Checkboxes
   are grouped by resource; `self:*` is not shown (baseline, non-composable).
3. **Roles CRUD** — name + permission checkboxes; tenant-scoped; `deleted_at`.
   Gated by `role:create` / `role:update` / `role:delete` (owner-only by
   default, since `manager` only has `role:list/read`).
4. **Users / members** — invite (`user:create`) by email (reuse existing `User`
   if known; token → platform-host `/onboarding/:token` → join tenant via a new
   `member` membership); assign/replace role (`user:update`);
   activate/deactivate (`user:activate` / `user:deactivate`); remove
   (`user:delete`, soft). **Deactivate/remove revokes the member's sessions** in
   the same transaction (cross-cutting session-revocation rule). All audited.
5. **Self-service surface (`self:*` baseline — lives here, not R9-recovery)** — every
   member manages their own account regardless of role:
   - profile: display name, avatar (local store for now), timezone
     (`self:read` / `self:update`)
   - change password, requires current (`self:password`)
   - change email → verify new + alert old address (`self:email`; see R9-recovery for the
     shared token mechanics)
   - sessions: list + revoke own (`self:sessions`)
   A member with an empty role can still do all of the above.
6. **Requests inbox** (the generic `requests` table; `leave` is the first type):
   - A member raises a request (`request:create`, baseline) — `leave` for now;
     status `open`, with a note.
   - Owners / `request:manage` holders process it: approve / decline with a
     resolution note (`request:manage`); requester can cancel their own open one.
   - Approving a `leave` removes the membership via `user:delete` (last-active-
     owner guard applies). At most one open request per type per member.
   - Status transitions audited.
7. **Owner protection** (tenant-side protected type, enforced at the **query
   layer** via the R2 `members_visible_to/1` + `assignable_types_for/1`
   helpers):
   - A member's user/role lists **exclude** owners and the `owner` type.
   - A member cannot edit an owner, grant `owner`, or escalate themselves —
     `owner` is never in a member's assignable types.
   - Only an owner can see / list / edit / assign owners.
   - **Last-active-owner** cannot be removed, deactivated, or demoted to
     `member`; the count + mutation run in one transaction.
   - Promoting a member to `owner` / demoting an owner to `member` is an
     owner-only action.

**Data** `roles`, `role_permissions`, `memberships` (`type`, `role_id`,
`active`), `users_tokens` (invite type), `requests` (tenant-scoped; `leave`
type now), `users.display_name`/`avatar_url`/`timezone`.

**Done when** an owner invites a member, assigns `agent`, the member signs in
with exactly those permissions, can edit their **own** profile/password/email
and revoke their own sessions without any user permission, **cannot see or
create an owner** (verified at the query layer), and can raise a `leave` request
the owner must approve; deactivating a member kills their live session at the
next request; a member with `user:update` still can't touch owners; the last
active owner can't be removed or demoted.
*Design: `team.html`, `profile.html`, `settings.html`.*

---

### R8-dashboard · `/app` dashboard landing

**Ships** The post-login `/app` home — fills the empty shell from R2 with a real
landing page so users don't arrive at a blank screen.

**Build**
1. `/app` (default after login) renders a dashboard: a few stat cards (open
   quote requests, quoted this month, team size) + a recent-activity list from
   `audit_logs` (tenant-scoped) + quick links to Quotes / Team / Settings.
2. Cards/links respect permissions — a member without `quote:list` doesn't see
   the quotes card or link; owner sees everything.
3. Stat numbers in `font-mono`; cards use `mtb-stat-card`. Empty states for a
   brand-new tenant ("no quote requests yet").

**Data** Reads only (`quote_requests`, `memberships`, `audit_logs`). No new
tables.

**Done when** a user landing on `/app` sees their dashboard with live counts and
recent activity, gated by their permissions; a new tenant sees friendly empty
states.
*Design: `dashboard.html`, `agency-dashboard.html`.*

---

### R9-recovery · Account recovery + token mechanics

**Ships** The token-based flows a logged-**out** or email-changing user needs:
password reset and the email-change confirm/alert. (Profile, password-change,
and session management already shipped in R7-rbac as the `self:*` surface — R9-recovery is the
recovery + token machinery they rely on.)

**Build**
1. **Forgot password** (`/forgot`, no auth): email a reset token; reset link
   points at the **platform host** `/reset/:token` so it works even if the
   tenant is suspended. `self:password` on completion.
2. **Email-change tokens** (the mechanics R7-rbac's `self:email` calls): on request,
   - send a confirm link to the **new** address, and
   - send an alert to the **old** address ("your email is being changed — if
     this wasn't you…") so a hijacked session can't silently move the account.
   - email only changes once the new-address link is confirmed.
3. Token TTLs are explicit (reset + email-change: short, e.g. 1 hour) and
   single-use; expired/used tokens show a "request a new link" page.

**Data** `users_tokens` (reset + email-change types).

**Done when** a logged-out user can reset a lost password via a platform-host
link that survives tenant suspension; an email change confirms on the new
address **and** alerts the old; expired tokens fail gracefully.
*Design: `forgot.html`, `reset.html`.*

---

### R10-domain · Custom domain

**Ships** A tenant owner adds their own domain (e.g. `quotes.acme.com`),
verifies ownership, and the app serves on it with automatic TLS. The platform
subdomain keeps working as a permanent fallback.

**Build**
1. **Settings UI** (`/app/settings/domain`, gated by `domain:read` /
   `domain:update` — owner or a role granted them):
   - Show current platform subdomain (always active).
   - Field to enter a custom domain → saves `custom_domain` as `pending`,
     generates a `custom_domain_token`.
   - Display the required DNS records: a `CNAME` →
     `<slug>.quoteassist.mytechbytes.in` and a `TXT` record carrying the
     verification token. Copy-to-clipboard via `Phoenix.LiveView.JS`.
2. **Verification** (`domain:verify`) — "Verify" button performs a DNS lookup
   (`:inet_res`) for the TXT token; on match sets
   `custom_domain_status = verified`. Re-checkable; a background job can also
   re-verify periodically and flag drift.
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

### R11-quotes · Quote request CRUD

**Ships** Tenant users create, view, edit, and close quote requests.

**Build**
1. `QuoteRequest`: tenant_id, submitted_by, customer_name, customer_email,
   subject, body (free text), status (state machine:
   `open → in_progress → quoted → closed`), `deleted_at`, timestamps.
2. List view (`quote:list`) — status filter + search; card/table toggle.
   Live rows only.
3. Create form (`quote:create`) — customer details + request body.
4. Detail view (`quote:read`) — status badge + activity timeline (from
   `audit_logs`).
5. Edit (`quote:update`) / close / reopen — status transitions
   (`quote:status`) via `can_transition?/2`, audited. Delete = `quote:delete`
   (soft).

**Data** `quote_requests` (`status`, `deleted_at`).

**Done when** a user creates a request, sees it in the list, and updates
its status.
*Design: `quotes.html`, `get-quote.html`, `quote-detail.html`.*

---

### R12-quote-reply · Quote reply + AI hook

**Ships** Users send a reply to a quote request. The reply is generated by
the AI service (stub now; real service swaps in later — no screen changes).

**Build**
1. Reply thread on quote detail — ordered messages (`quote_messages`:
   quote_request_id, author_type `human|ai`, body, inserted_at).
2. **Manual reply** (`quote:reply`) — textarea + Send; appends a `human`
   message.
3. **AI reply stub** (`quote:ai_generate`) — "Generate with AI" button calls
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
[shipped, frozen]
R0 → R0a → R1 → R2 → R3   foundation + site admin: skeleton · home+tenants · auth · tenancy+RBAC · admin/tenant CRUD ✅

[resequenced, shipped]
R4-retrofit → R5-selfreg → R6-errors    admin RBAC (retrofits R3) · self-reg (auto-trial) · error pages ✅
R7-rbac → R8-dashboard → R9-recovery    tenant users/roles/self/requests · dashboard · account recovery ✅
R10-domain → R11-quotes → R12-quote-reply  custom domain · quote CRUD · AI reply hook ✅

[complete] All R0–R12 shipped.
```

Each arrow = a staging deploy. The four-check green gate (compile · quality ·
Dialyzer · tests >95%) must pass at every arrow.
