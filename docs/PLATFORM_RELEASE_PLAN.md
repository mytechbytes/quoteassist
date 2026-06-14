# Platform Release Plan (Phoenix only) — fresh, step-wise & deployable

A build plan for the **platform plane** (`projects/platform`, Elixir/Phoenix +
LiveView) treated as **fresh work**. It excludes the Python AI service and the
Outlook add-in. The quote flow here is fully platform-managed (manual capture →
pricing → discount → approval → send); AI extraction slots in later without
changing these screens.

## The one rule: every step is deployable

Build a **walking skeleton first** (something that deploys to staging on day one),
then add **thin vertical slices**. After each release `R#` you can deploy and demo.

Each release follows the same shape:

- **Ships** — the one user-visible outcome that goes live.
- **Build** — the steps.
- **Data** — migrations it adds.
- **Deploy & verify** — how you prove it in staging.
- **Done when** — acceptance.

Principles, every release:
- Keep `make check` green (format · compile --warnings-as-errors · credo · test).
- **Tenant isolation from R2 onward** — every tenant-owned query is scoped; tenant
  comes from the session/JWT, never from params.
- Hide unfinished work behind a flag rather than blocking a deploy.
- Add at least one test per slice; update `PHASE_PROGRESS.md` when a release lands.

## Release index

| #   | Track          | Release                          | Deployable outcome                         |
| --- | -------------- | -------------------------------- | ------------------------------------------ |
| R0 ✅ | Foundation   | Walking skeleton                 | App + DB deploy; `/health` is green        |
| R1  | Foundation     | Auth & accounts                  | Users can sign in / out                    |
| R2  | Foundation     | Tenancy + RBAC + launcher        | Personas resolve; tenant-scoped shells     |
| R3  | Site Admin     | Vertical catalog                 | Admin manages verticals/categories         |
| R4  | Site Admin     | Plans                            | Plans are data; tenants reference them     |
| R5  | Site Admin     | Tenant CRUD                      | Admin creates/edits/suspends tenants       |
| R6  | Site Admin     | Tenant configuration             | Per-tenant versioned config                |
| R7  | Site Admin     | Signup / registration flow       | Companies self-register + verify           |
| R8  | Tenant Admin   | Tenant settings                  | Owner edits org settings/branding          |
| R9  | Tenant Admin   | Users / Roles / Permissions      | Owner invites users, builds roles          |
| R10 | Tenant Admin   | Approval hierarchy + quotas      | Multi-level discount approval chain        |
| R11 | Tenant Admin   | Pricing method                   | Pricing via API **or** managed CRUD        |
| R12 | Tenant Users   | Quote CRUD                       | Sellers create/edit quotes                 |
| R13 | Tenant Users   | Pricing the quote                | Quotes price against the active source     |
| R14 | Tenant Users   | Discount + approval flow         | Over-limit discounts route for approval    |
| R15 | Tenant Users   | Draft + send                     | Manual, audited send (auto-send off)       |
| R16 | Tenant Users   | Quote dashboard                  | Seller day-at-a-glance                     |

---

# Foundation

### R0 · Walking skeleton  `deployable`  — ✅ done

> **Implemented & verified.** `mix check` green (7 tests); `/health` → 200 and
> `/health/ready` → `{"status":"ready","checks":{"database":"ok"}}`; extensions
> migration applied; branded landing renders the design tokens; prod release
> assembles (`bin/quote_assist`). Files: health controller + routes, extensions
> migration, `assets/css/qa.css` + layout fonts/dark mode, `projects/platform/
> Dockerfile` + `ci/Dockerfile` + `.tool-versions` + `lib/quote_assist/release.ex`,
> `Jenkinsfile`, `.github/workflows/platform.yml` (format/compile/credo/test).

**Ships** A running app that deploys to staging with a green health check — no
features yet, but the whole pipeline works.
**Build**
1. `mix phx.new` platform (LiveView, binary_id, utc_datetime), Postgres + pgvector.
2. `/health` (liveness) + `/health/ready` (DB check) endpoints.
3. Dockerfile + `docker-compose` (db, redis, platform); `.env.example`.
4. CI (format/compile/credo/test) + a deploy workflow to staging.
5. Base layout wired to the design tokens (`qa.css`, fonts, dark mode).
**Data** initial migration + extensions (`citext`, `vector`).
**Deploy & verify** `curl https://staging/health` → 200; CI green on a PR.
**Done when** a no-op change ships to staging through CI and `/health/ready` passes.

### R1 · Auth & accounts  `deployable`

**Ships** People can sign in and out.
**Build**
1. `User` (email citext, hashed_password, confirmed_at); register + authenticate.
2. Session login/logout (signed cookie) + `on_mount` current-user; login/register
   screens from `designs/quoteassist/login.html`.
3. Password reveal / theme toggle via `Phoenix.LiveView.JS` only.
**Data** `users`.
**Deploy & verify** Register a user on staging, sign in, sign out.
**Done when** auth works end-to-end and protected routes redirect to `/login`.

### R2 · Tenancy + RBAC + launcher  `deployable`

**Ships** A signed-in user sees a persona launcher and lands in a tenant-scoped
workspace shell.
**Build**
1. `Tenant`, `Membership` (user↔tenant + persona + seller level), `Role` (bundle of
   **system-defined** permissions), `Policy.can?/3`.
2. `Tenancy.scope/2` query helper; persona resolution; `on_mount` persona guards.
3. Persona launcher (CC-01) + empty `/admin`, `/agency`, `/app` shells.
**Data** `tenants`, `memberships`, `roles`.
**Deploy & verify** Seed one user per persona; each reaches only their workspace;
a salesperson is bounced from `/admin`.
**Done when** persona routing + tenant scoping hold (covered by tests).

---

# 1 · Site Administrator

Platform operator. Owns the catalog tenants are built from, the tenants, and
onboarding. Exempt from tenant scoping; **every action is audited**.

### R3 · Vertical catalog  `deployable`

**Ships** Admin manages the tenant **types** (Travel, Medical, Media,
Manufacturing, …) with their categories and discount ceiling.
**Build**
1. CRUD for `verticals` (name, slug, deal noun/plural, money unit).
2. Nested CRUD for `categories` (ordered) per vertical.
3. Per-vertical **guardrail** (max discount %) — the platform ceiling.
4. Seed the standard verticals.
**Data** `verticals`, `categories`, `guardrails`.
**Deploy & verify** Create "Manufacturing" + categories + guardrail on staging.
**Done when** a vertical with categories + guardrail is selectable as a tenant type.

### R4 · Plans  `deployable`

**Ships** Subscription plans are data an admin manages.
**Build**
1. `plans` (name, seat limit, monthly price, feature flags, is_active).
2. Plans CRUD; retire (never hard-delete a plan in use).
3. `Tenant` references a plan by id; `seat_limit/price` resolved from the plan.
**Data** `plans`; `tenants.plan_id`.
**Deploy & verify** Add a "Scale" plan; it appears in the tenant create form.
**Done when** plans drive seat limits/pricing instead of hard-coded values.

### R5 · Tenant CRUD  `deployable`

**Ships** Admin creates, edits, suspends and removes tenants.
**Build**
1. Create tenant: name, owner, region, **vertical** (R3), **plan** (R4), status.
2. Edit / suspend (status + MRR) / reactivate / delete (cascade) with confirm.
3. On create, **seed the quota matrix** from the vertical's categories.
**Data** `tenants` (+ cascades), `quota_matrix` seeded.
**Deploy & verify** Onboard a tenant on staging; suspend and reactivate it.
**Done when** full tenant lifecycle works and a new tenant is immediately usable.
*(Screen reference: `designs/quoteassist/admin-tenants.html`.)*

### R6 · Tenant configuration  `deployable`

**Ships** Admin sets per-tenant config (region, flags, confidence config —
`auto_send_enabled` stays **false** in R1).
**Build**
1. Per-tenant config written as **versioned config** (new active version, never
   destructive) + `ConfigService.reload/0`.
2. `ConfigService` ETS cache for zero-DB request reads.
**Data** `confidence_configs` + tenant-scoped config rows; config service.
**Deploy & verify** Change a tenant's config; confirm a new active version + live
effect without redeploy.
**Done when** config is versioned, hot-reloadable, and tenant-scoped.

### R7 · Signup / registration flow  `deployable`

**Ships** A company can self-register, verify email, and the owner reaches their
workspace.
**Build**
1. Public `/signup`: company, vertical, plan, owner name + email.
2. One `Ecto.Multi`: create tenant (`trial`) + owner `User` + owner `Membership`
   (`agency_admin`).
3. Email verification token → confirm → set password → land in `/agency`.
4. Admin `/admin/signups`: review / approve / reject; handle duplicates + expiry.
**Data** `users_tokens` (confirm/reset); reuse `tenants`/`users`/`memberships`.
**Deploy & verify** Self-register on staging; verify via the mailbox; sign in.
**Done when** a brand-new company onboards itself and the admin can moderate.

### Points — Site Administrator

- Audit every action (who/what/tenant/before-after); platform activity feed.
- Prefer **suspend** over delete; deletion is explicit, confirmed, audited, with a
  grace window before purge.
- Plan changes: enforce seat over-limit (block new users until resolved).
- Guardrail is law — re-validate tenant quotas if a guardrail is lowered.
- Optional **"view as tenant"** impersonation: heavily audited + time-boxed.
- Scoped site-admin permissions (`tenant:manage`, `vertical:manage`, `plan:manage`)
  so read-only platform staff can exist later.
- Cross-tenant reads live **only** in admin screens — keep them out of tenant
  contexts.

---

# 2 · Tenant Administrator (Owner)

Configures their org: people, roles, the approval hierarchy, pricing. Everything is
**tenant-scoped**.

### R8 · Tenant settings  `deployable`

**Ships** Owner edits their org: display name, branding/logo, currency, business
hours, reply signature, email templates.
**Build**
1. Owner-editable tenant profile; templates saved as **versioned config**.
2. Guard: only `agency_admin` with `tenant:manage`.
**Data** `email_templates` + tenant config rows.
**Deploy & verify** Change the signature on staging; it shows on a draft.
**Done when** owner settings apply immediately and are versioned.

### R9 · Users / Roles / Permissions  `deployable`

> Permissions are **system-defined only** — admins compose them into roles and
> assign roles; they cannot invent new permission strings.

**Ships** Owner invites users and builds roles from a fixed permission catalog.
**Build**
1. Seeded, code-owned **permission catalog** (read-only in UI).
2. **Roles CRUD** = name + checkboxes of system permissions.
3. **Users**: invite by email (seat-limit aware), assign role + persona + (sellers)
   level + category eligibility; deactivate/remove.
4. Invite acceptance (token → set password → join tenant).
**Data** `roles`, `memberships`, `users`, `users_tokens`.
**Deploy & verify** Create a "Approver" role, invite a user, they sign in with
exactly those permissions; seat limit enforced.
**Done when** role→permission→user wiring is correct and seat-limited.
*(Screen reference: `designs/quoteassist/team.html`.)*

### R10 · Approval hierarchy + quotas  `deployable`

> An **ordered chain** of approval levels, each with a max discount eligibility. A
> requested discount routes **up the chain** through every level until one whose
> limit covers it. Example: Salesperson 20% · Manager 30% · VP 40% · President 60%.
> A **55%** discount routes Manager → VP → President (each approves); **25%** →
> Manager only; **15%** → self-serve.

**Ships** Owner defines the chain + per-level %, and discounts route correctly.
**Build**
1. `approval_levels` (tenant_id, name, rank, max_discount_pct, role/user). Direction
   configurable (**bottom-up** default; allow top-down).
2. Editor to add/reorder levels + set % (validated monotonic and `≤` guardrail).
3. **Routing engine**: requested % → ordered approver list (everyone above the
   requester up to the first level whose limit ≥ request); none covers → blocked.
4. Quota matrix (level × category `{self, cap}`) clamps per-category limits.
**Data** `approval_levels`; `quota_matrix`; `guardrails`.
**Deploy & verify** On staging, set the 20/30/40/60 chain; a 55% request returns
Manager→VP→President.
**Done when** the routing engine matches the worked example (unit-tested).
*(Screen references: `agency-quotas.html`, `agency-approvals.html`.)*

### R11 · Pricing method  `deployable`

> Two interchangeable adapters, chosen per tenant (and optionally per category).

**Ships** Owner picks **API** or **managed (CRUD)** pricing.
**Build**
1. **API**: endpoint + auth (secret by reference, never plaintext), test-connection,
   response mapping; timeout/retry/circuit-breaker; fall back to acknowledgement.
2. **Managed**: in-app price book — upload JSON/Excel **or** edit rows; effective-
   dated versions; upload validation.
3. Bind a `pricing_source` to the tenant (and per category if needed); pick active.
**Data** `pricing_sources` (type `api|json|excel|book`) + price-book rows.
**Deploy & verify** Configure managed pricing on staging; a test quote prices.
**Done when** either method validates and the quote flow (R13) prices against it.

### Points — Tenant Administrator

- Every read/write is `Tenancy.scope/2`'d; resolve tenant from membership, not
  params.
- Permissions are immutable input — the role editor only composes the seeded
  catalog; new permissions = code + migration.
- Owner safety — never let the last owner lock the tenant out; protect the final
  `agency_admin`.
- Approval chain must be monotonic and `≤` guardrail; re-validate quotas on change.
- Pricing secrets via Key Vault / secret-ref — never in config rows or logs.
- Versioned config for templates/thresholds/pricing; never destructive update.
- Tenant-scoped audit + activity feed for every config/role/approval change.

---

# 3 · Tenant Users (Salesperson)

Creates quotes, applies discounts within quota, requests approval when over, sends —
**human-in-the-loop, auto-send disabled in R1**.

### R12 · Quote CRUD  `deployable`

**Ships** Sellers create/edit/clone/delete quotes.
**Build**
1. Quote with customer, category, line items (qty + attrs), notes; owner/tenant
   scoped.
2. Lifecycle: `draft → priced → pending_approval → approved → sent` (+ `expired`,
   `rejected`).
3. Validation per vertical/category; currency from tenant.
**Data** `deals`, `quotes`.
**Deploy & verify** Create and edit a quote on staging; status is visible.
**Done when** quote CRUD + status work end-to-end.
*(Screen references: `get-quote.html`, `quote-detail.html`.)*

### R13 · Pricing the quote  `deployable`

**Ships** A quote prices against the tenant's active method (R11).
**Build**
1. "Price quote" calls the active pricing adapter; map to line items + total.
2. Status `priced | partial | unavailable`; partial/unavailable suppresses send.
3. Cache per request; show source + `valid_until`.
**Data** `quotes.pricing_status`, `quotes.quotes`.
**Deploy & verify** Price a quote on staging; unavailable pricing degrades safely.
**Done when** pricing works for the configured method and fails gracefully.

### R14 · Discount + approval flow  `deployable`

**Ships** Over-limit discounts route through the approval chain (R10).
**Build**
1. Discount slider + **live quota meter** (self / approval / over-cap bands) from the
   seller's quota.
2. Within self-limit → apply; over → create `approval_request` routed via the chain.
3. Approver inbox (pending/decided, approve/reject + note); levels act in order;
   rejection stops the chain; send blocked while pending.
4. "My requests" panel with live status.
**Data** `approval_requests`, `approval_levels`, `quota_matrix`, `activity_logs`.
**Deploy & verify** On staging, a 55% discount routes Manager→VP→President and only
sends after all approve.
**Done when** the governed discount path matches the worked example.
*(Screen reference: `apply-discount.html`.)*

### R15 · Draft + send  `deployable`

**Ships** Seller reviews a generated draft and sends manually (audited).
**Build**
1. Generate draft from the tenant template (R8) + priced quote.
2. Review + explicit **Send** (auto-send guard confirms `false`).
3. Record `sent_at`; append to audit + activity; quote → `sent`; idempotent.
**Data** `drafts`, `quotes`, `audit_logs`, `activity_logs`.
**Deploy & verify** Send a quote on staging; confirm audit entry; no double-send.
**Done when** manual send works and is fully audited; auto-send impossible.

### R16 · Quote dashboard  `deployable`

**Ships** A seller's day-at-a-glance over real quote data.
**Build**
1. KPIs (new / in-progress / awaiting-approval / sent) + recent activity + quick
   links, built on `kpi` + `DataList` + `confidence_badge`.
2. Filters by status/category/date via the shared list engine.
**Data** `deals`, `quotes`, `approval_requests`, `activity_logs`.
**Deploy & verify** Dashboard reflects real quotes on staging.
**Done when** the overview is live and accurate.
*(Screen reference: `dashboard.html`.)*

### Points — Tenant Users

- Quota enforced **server-side** (slider is a hint); re-check on apply and on send.
- Optimistic concurrency on approvals + quota writes (no double-approve / double-
  apply).
- Send is the point of no return — confirm, audit, idempotent.
- The quote **state machine** is the source of truth; UI only reflects it.
- No full message bodies persisted (mask in audit) — store refs + masked values.
- Priced quotes carry `valid_until`; block sending an expired price.
- Confidence badge wires to real extraction once the AI service lands (later) —
  placeholder until then.

---

## Build order (one linear, always-deployable path)

R0 → R1 → R2  (skeleton · auth · tenancy+RBAC)
→ R3 → R4 → R5 → R6 → R7   (site admin: verticals · plans · tenants · config · signup)
→ R8 → R9 → R10 → R11      (tenant admin: settings · users/roles · approvals · pricing)
→ R12 → R13 → R14 → R15 → R16  (tenant users: quote · price · discount/approval · send · dashboard)

Each arrow ships to staging. Keep `make check` green and update
`PHASE_PROGRESS.md` as each `R#` lands.
