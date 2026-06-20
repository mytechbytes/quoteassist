# CLAUDE.md — `services/platform`

Phoenix + LiveView platform for QuoteAssist. Read alongside the root
[`../../CLAUDE.md`](../../CLAUDE.md) and the authoritative
[`docs/RELEASE_PLAN.md`](docs/RELEASE_PLAN.md).

## Current status

**R9-recovery complete.** The logged-out / email-changing token flows. **Forgot password**
(`/forgot`, platform host) → `Accounts.deliver_user_reset_password_instructions/2` issues a
short-lived (60 min) single-use `reset_password` `UserToken` and emails a link built on the
*platform* host (so it survives a tenant suspension); the response is always neutral and the
send is throttled (`LoginThrottle.reset_password_throttled?/1`). **Reset** (`/reset/:token`,
platform host) → `ResetPasswordLive` validates via `Accounts.get_user_by_reset_password_token/1`,
and `reset_user_password/2` sets the password through `update_user_and_delete_all_tokens` (so
every session is revoked + the link is consumed), then links the user to their newest tenant's
own-host login (`Tenants.newest_tenant_for_user/1` → `tenant_login_url/1`, falling back to
`/tenants`). **Email change** now completes: `deliver_user_update_email_instructions/3` sends the
confirm link to the *new* address **and** an alert to the *old* one
(`UserNotifier.deliver_email_change_alert/2`); the R7 initiation in `App.AccountLive` is
unchanged, and the new `App.EmailConfirmationLive` (`/account/confirm-email/:token`, tenant host,
authenticated) calls `Accounts.update_user_email/2` to swap it. The login page's "Forgot?" link
now points at `Tenants.platform_url("/forgot")` (made public) rather than a tenant-host path that
RequirePlatform would 404. No new migrations (`users_tokens` carries the `reset_password` +
`change:*` contexts).

**R8-dashboard complete.** `/app` (`AppHomeLive`) is the post-login dashboard, filling the R2
shell: a greeting, three permission-gated stat cards (open requests + quoted-this-month, gated
`quote:list`; team size from `Tenants.active_member_count/1`, gated `user:list`), a tenant-scoped
recent-activity feed (`Audit.list_for_tenant/2` → `App.Components.audit_timeline`), and quick
links (Team/Roles gated, Requests/Account always). Owners see everything (computed all-access);
an empty-role member sees only the activity feed + Account. Reads only, no new tables. **Quote
counts are `0` placeholders until R11-quotes** (`dashboard_quote_stats/1` — the `quote_requests`
table doesn't exist yet), which is exactly the brand-new-tenant empty state; R11 swaps the body
with the real aggregate, no UI change. The un-onboarded-owner setup banner from R2 is kept.

**Cross-cutting UI conventions (post-R7).** Three rules now apply to every resource, admin
and tenant: (1) **forms with >3 fields live on dedicated pages**, not modals — Plan
(`/admin/plans/new` · `/admin/plans/:id/edit` → `Admin.PlanLive.Form`), Tenant
(`/admin/tenants/{new,:id/edit}` → `Admin.TenantLive.Form`), and the role editors already
moved; smaller forms (admin create, member-invite, request-raise) stay as modals. (2) **slug
auto-fills from the name on create**, live, via `QuoteAssist.Slug.{slugify/1,auto/4}` wired into
each create form's `phx-change` (tenant + admin role, plan, tenant) — it stops the moment the
user edits the slug. (3) **every collection resource has a detail route with an activity feed**,
gated by `*:read`: tenant `App.{RoleLive,TeamLive,RequestLive}.Show` at `/app/{roles,team,requests}/:id`
(member detail is owner-protected via `get_member_visible_to/2`), and the admin detail pages all
carry one (added to plan + admin_role shows). Activity is `Audit.list_for_target(target_type,
target_id)`, rendered by `App.Components.audit_timeline` (tenant) / `Admin.Components.audit_timeline`.

**R7-rbac complete.** Tenant users, roles, the `self:*` baseline, and the generic requests
inbox. The owner protected type mirrors admin `super_admin`, enforced at the **query layer**
(`Tenancy.members_visible_to/1`): `Tenants.list_members_visible_to/1` + `get_member_visible_to/2`
exclude owners from a member, so even a member with `user:update` can't see or act on one. New
`Tenants` member/role ops (scope-actor, audited, `actor_subtype: owner|member`): `invite_member/2`
(reuse-or-register user → `member` membership + onboarding/magic-link invite), `update_member_role/3`,
`activate_member`/`deactivate_member`/`remove_member` (session-revoking — delete the user's
`session` tokens), `promote_member`/`demote_owner`, and audited `create_role`/`update_role`/
`soft_delete_role` over the R2 catalog. The last-active-owner guard runs under `SELECT … FOR
UPDATE`; `member?/2` + `get_active_membership/2` now also require `active = true`, so a deactivated
member is bounced at the next request. A new `QuoteAssist.Requests` context + `Tenants.Request`
schema back the `requests` table (`leave` first type; `open → approved|declined|cancelled` FSM,
partial-unique one-open-per-type) — `request:create` is a member baseline in `Authz.Policy`, and
approving a leave removes the membership via `remove_member`. `Accounts` gained the self-service
surface: `update_user_profile` (display_name/avatar_url/timezone), `list_user_sessions` +
`revoke_user_session` + `session_token_id`, `valid_user_password?`. New LiveViews under
`/app/{team,roles,account,requests}` (page gates raise → branded 403 via `UserAuth.permit!`; per-
action gates hide/deny) with `App.Components`; the workspace sidebar gates Team/Roles by permission
and always shows Requests/Account. Role **create/edit** lives on dedicated pages
(`/app/roles/new`, `/app/roles/:id/edit` → `App.RoleLive.Form`), not a modal: permissions are
composed in a resource × action **matrix**: five CRUD columns (`Permissions.base_action_columns/0`,
ragged — a cell only where `resource:action` is real) plus a single **Special permissions** column
that renders each resource's non-CRUD permissions (`special_permissions/1`) as chips, with select-all,
per-column (action), per-row (resource) and per-special toggles; the selection is held server-side in
a `MapSet`. The index keeps the list + delete confirm. The **admin console** mirrors this exactly —
`/admin/roles/new`, `/admin/roles/:id/edit` → `Admin.AdminRoleLive.Form` over `AdminPermissions`
(its specials being `tenant:suspend/cancel/purge`, `*:activate/deactivate`). Email-change is **initiation-only** here (sends a verification
link to the new address) — the confirm/alert token mechanics land in R9-recovery. Migrations:
`users.avatar_url`/`timezone`, `requests`.

**R6-errors complete.** Branded error pages (401/403/404/500/503) wired to real Phoenix
error handling. `ErrorHTML` renders one parametric `error_page` document (ported from
`designs/quoteassist/error-*.html`, `mc-*`/`qa-*` → `mtb-*`) per status, with a plain-text
fallback for any other status; `ErrorJSON` stays generic. A `Plugs.Maintenance` plug (first
in the `:browser` pipeline, gated by `:maintenance_mode` / the `MAINTENANCE_MODE` env) serves
the 503 to all browser traffic while the `/health` probes on the `:api` pipeline stay up.
`QuoteAssistWeb.Errors` adds `UnauthorizedError` (403) + `UnauthenticatedError` (401);
`FallbackController` maps `{:error, :unauthorized|:unauthenticated|:not_found}` for controller
actions, and `UserAuth.permit!/2` is the LiveView "raise → branded 403" primitive (the tenant
guards that call it land in R7-rbac). 401 stays a host-aware redirect (tenant `/login` vs
`/admin/login`); `RequirePlatform` now renders the branded 404 on tenant hosts. **Suspended
tenants** are distinguished at the resolver: `Tenants.resolve_host/1` returns `{:suspended,
tenant}` (vs `{:ok, _}` / `:not_found`), and `TenantResolver` renders a dedicated branded
"workspace suspended" notice (`TenantErrorHTML.tenant_suspended`) with status **403** — the
workspace exists but access is forbidden (admin pause or lapsed trial). Unknown / cancelled /
deleted hosts still 404. `fetch_live_tenant/1` is unchanged (trial/active only), so a member
on a tenant suspended mid-session is bounced at the next mount and meets the 403 notice.

**R5-selfreg complete.** Public `/register` (platform host, behind `RequirePlatform`) →
`Tenants.register_self_service/1` creates the tenant directly in `trial` (now + 15 days,
seeded **Starter** plan, `source: :self_signup`) + owner `User` (reused if the email already
exists, else registered with the form's display name) + owner `Membership`, all in one
`Ecto.Multi` audited as `actor_type: :system` (`tenant.self_registered`). The owner gets a
platform-host `quoteassist.../onboarding/:token` link (a 7-day `onboarding` `UserToken`);
`OnboardingSetupLive` sets the initial password **and** confirms the email in one transaction
(single-use token), then links to the tenant's own-host login. Expired/used links resend
neutrally (no enumeration via `Tenants.resend_onboarding/1`); the tenant login page carries an
un-onboarded-owner safety net. Self-signups show a `Self-registered` badge in `/admin/tenants`
— admins handle bad actors reactively with the R3 suspend/cancel controls (no approval queue).
A `tenants.source` column (`admin | self_signup`) was added for triage. This is a *new*
platform-host, token-based flow distinct from the R3 `/app/welcome` invited-owner onboarding,
which is unchanged.

**R4-retrofit complete.** Admin RBAC + protected `super_admin`. The R3
`admins` identity gained the protected-type pattern via migration: `type`
(`super_admin | admin`), `role_id`, `active`, with the bootstrap admin promoted to
`super_admin` in the same transaction. A code-owned admin catalog
(`Authz.AdminPermissions`: `tenant`/`plan`/`admin`/`admin_role`/`audit` + the `self:*`
baseline) is consumed by `Authz.AdminPolicy.can?/3`, mirroring the tenant side; platform
`admin_roles` (a `permissions` array like tenant `roles`, two built-ins seeded —
Operations/Support) back normal admins, while `super_admin` carries no role (computed
all-access). The protected type is enforced at the **query layer**:
`Accounts.list_admins_visible_to/1` + `get_admin_visible_to/2` exclude super_admins from a
normal admin, the last-active-super_admin guard runs under `SELECT … FOR UPDATE` in the
mutation's transaction, and deactivate/remove revoke the target's sessions. New console
screens: `/admin/admins` (create scoped admins, reassign roles, activate/deactivate/remove)
and `/admin/roles` (compose roles from the catalog); the R3 tenant/plan/audit screens are
retro-gated behind `tenant:*` / `plan:*` / `audit:*` via `AdminAuth.authorize/2`, and admin
actions audit with `actor_subtype`. `mix qa.create_admin` now bootstraps a `super_admin`.

**R3 complete.** Site admin. A separate `admins` identity (own table +
`admins_tokens`, `Accounts.Admin`/`AdminToken`, `Accounts.register_admin/1`) with its
own auth pipeline (`QuoteAssistWeb.AdminAuth`: `admin_token` session, `current_admin`
assign, `on_mount :require_admin`) — independent of `UserAuth`/`Scope`. `/admin/*` is
platform-host only via `RequirePlatform` (the inverse of `RequireTenant`); login at
`/admin/login` reuses the R1 throttle and is audited. Admins are created only via
`mix qa.create_admin` (all environments — no HTTP/seed/env path). Tenant CRUD at
`/admin/tenants`: create runs an `Ecto.Multi` (tenant on a 15-day trial + owner `User`
reused-or-registered + owner `Membership` + audit, then a magic-link invite built on
the tenant's host); edit name/plan; suspend/reactivate/cancel via the status FSM;
soft-delete — each audited (actor = admin). A `plans` table (Starter + Growth, seeded
in every env) backs `tenant.plan_id`. Expired trials are blocked at tenant login and
auto-transition `trial → suspended` (audited), after which `TenantResolver` shows the
branded suspension notice (403; was 404 pre-R6) on the host. Owner onboarding
(`/app/welcome`) sets a display name + password (reuses the
magic-link invite); `users.display_name` was pulled forward from R6.

**R2 complete.** Tenancy + RBAC. Tenants resolve from the request
**host** via the `TenantResolver` plug (platform host → no tenant; `*.<base>` →
`slug`; any other host → verified `custom_domain`; unknown/suspended/deleted →
404), and the resolved tenant id is written to the host-scoped session. The
LiveView learns the tenant from that session and reloads it from the DB on every
mount (`on_mount :require_tenant_member`), so suspended/deleted tenants are caught.
`QuoteAssist.Tenancy.scope/2` constrains every tenant-owned query and raises
without a tenant. RBAC: a code-owned permission catalog (`Authz.Permissions`, keys
mirroring the design) consumed by `Authz.Policy.can?/3`; tenant-scoped `roles`
(five built-ins seeded per tenant) referenced by `memberships.role_id`.
`tenant.status` is a hand-rolled state machine (`Tenant.can_transition?/2`, audited
via `Tenants.transition_status/3`). Append-only `audit_logs` + `Audit.log/1`, wired
into the login path. `/app` is the workspace shell (`Layouts.workspace`, ported
`mtb-shell`/`mtb-side` chrome) behind the membership guard. `/tenants` now lists
live tenants; `priv/repo/seeds.exs` seeds the `acme` tenant + roles + owner/agent/
newbie members (dev/staging, `DEV_USER_PASSWORD`). Reach it at
`http://acme.quoteassist.localhost:4000`.

**R1 complete.** Auth — tenant users sign in and out. `phx.gen.auth`
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
`:tenant_url_scheme` (per-tenant subdomain login links; dev → `quoteassist.localhost:4000`).
`/admin/login` is a plain `href` (route lands in R3).

**R0 complete.** Walking skeleton: `/health` + `/health/ready`, Dockerfile,
`docker-compose`, `.env.example`, `assets/css/mtb.css` (design tokens +
`mtb-*` utilities, DaisyUI removed), base layout wired to mtb.css + Google
Fonts + dark mode, `citext` migration.

**Next: R10-domain** — custom domain: a tenant owner adds their own domain
(`/app/settings/domain`, gated `domain:read`/`domain:update`), verifies ownership via a DNS TXT
lookup (`domain:verify`), and the app serves on it with Caddy on-demand TLS gated by an internal
`/tls/check?domain=` endpoint. The `TenantResolver` already handles the verified custom-domain
path (R2); this release populates + verifies the data it reads. The subdomain stays a permanent
fallback.

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
  4. a live but **suspended** tenant → branded "workspace suspended" notice, **403**;
  5. unknown / cancelled / deleted → branded "workspace not found", **404**.
- **Platform-host-only pages.** The tenant directory (`/tenants`) and `/admin/*` are
  gated by `RequirePlatform` — they 404 on any tenant subdomain / custom domain. The
  build-status home (`/`) is host-aware: it renders only on the primary domain; on a
  tenant host the controller redirects to `/app` (signed in) or `/login` rather than
  showing platform chrome (and rather than 404-ing the tenant root, which is the
  post-logout redirect target). Net effect: the build-status page and the "Admin
  login" link in the shared `Layouts.app` chrome appear on the primary domain only.
- Cookies scoped to the **exact resolved host** (never `.quoteassist...`), so
  sessions never leak across tenants or between a subdomain and its custom domain.
- Dev: `*.quoteassist.localhost:4000` for subdomains (`acme.quoteassist.localhost:4000`).
- `on_mount :require_tenant_member` guards all `/app/*` LiveViews; verifies a
  live membership for the resolved tenant.
- **Login is tenant-scoped.** The `RequireTenant` plug keeps `/login`, `/login/:token`,
  and the credential POST on tenant hosts only — the platform host redirects to the
  directory (admins use `/admin/login`, R3). Login also requires a live membership for
  the host's tenant (`Tenants.member?/2`): a user of one tenant can't sign in to
  another (password + magic link both reject non-members with the generic error, no
  enumeration). Magic links are built on the request host so the flow stays on the
  tenant (cookies are host-scoped).

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
R0            walking skeleton (/health, Dockerfile, base layout + mtb.css)        ✅
R0a           platform home (/) + tenant list (/tenants)                           ✅
R1            auth — tenant users sign in/out (phx.gen.auth, mailer, throttle)     ✅
R2            tenancy + RBAC (TenantResolver, Tenancy.scope, Policy, audit_logs)   ✅
R3            admin identity + tenant CRUD + 15-day trial                          ✅
R4-retrofit   admin RBAC + protected super_admin (retrofits R3)                    ✅
R5-selfreg    self-registration → auto-approve to trial                            ✅
R6-errors     branded error pages (401/403/404/500/503)                            ✅
R7-rbac       tenant users, roles, permissions + self:* + requests               ✅
R8-dashboard  /app dashboard landing                                              ✅
R9-recovery   account recovery (forgot/reset, email-change)                       ✅
R10-domain    custom domain (add, verify, auto-TLS via Caddy on-demand)
R11-quotes    quote request CRUD (lead capture)
R12-quote-reply  quote reply + AI hook (stub → live)
```

Each arrow is a staging deploy. See [`docs/RELEASE_PLAN.md`](docs/RELEASE_PLAN.md)
for the per-release Build / Data / Done-when detail.

## Git workflow

Always confirm before `git commit` / `git push`. Push directly to `main` only.


# Elixir Project Rules
## Development Workflow
- When you are done editing files, the project's `Stop` hook will automatically execute formatting, testing, and coverage checks.
- If the `Stop` hook fails (exits with code 2), read the stderr output stream carefully, refactor the code to fix the failing tests or styling rules, and let the loop run again.

## Commands
- Format code: `mix format`
- Run credo: `credo --strict`
- Run tests: `mix test`
- Test coverage: `mix test —cover`
- Test coverage: `mix coveralls.json && mix run --no-start ci/check_coverage.exs`
