# Phase progress

> ⚠️ **The `platform` app was rebuilt from scratch via `mix phx.new`.** Everything
> described under Phases 0–2 below is from the **pre-rebuild** platform and is kept
> only for historical context — that code (Tenancy/RBAC/JWT/config service/32 tests)
> is **not** in the current tree. For the platform plane, the **live tracker is
> [`platform_release_plan.md`](platform_release_plan.md)** (releases R0–R16).
>
> **Current platform state:** R0 ✅ (walking skeleton) · R1 ✅ (auth & accounts:
> email+password + magic-link via `phx.gen.auth`, design-system styled, SSO seams).
> Next up: **R2 — Tenancy + RBAC + launcher.** The AI service / add-in / infra
> phases below remain the reference for those tracks.

Living tracker of the original §13 phased plan (solution-design doc). Update this
at the end of each working session so the next one has continuity.

Legend: ✅ done · 🟡 partial · ⬜ not started

## Phase 0 — Project setup & local dev environment ✅

- ✅ Monorepo under `projects/` (`platform`, `ai-service`, `outlook-plugin` stub,
  `shared/contracts`) + root `infrastructure/`, `designs/`, `docs/`.
- ✅ `docker-compose.yml` (pgvector, redis, ai-service, platform) + override; paths
  point at `projects/`.
- ✅ `.env.example` (no secrets), `Makefile`, `.tool-versions` (OTP 29 / Elixir 1.18).
- ✅ CI per package: `platform` (format/credo/dialyzer/test), `ai-service`
  (ruff/mypy/pytest), `outlook-plugin` (typecheck), `infra-plan` (fmt/validate).
- ✅ Ecto migrations for **all** core tables + pgvector/citext/pgcrypto extensions.
- ✅ Seeds: 6 verticals + categories + guardrails, RBAC roles, demo Airline tenant
  + users/memberships, quota matrix, config v1 (schema/prompt/templates),
  `confidence_configs.auto_send_enabled = false`.
- ✅ Terraform **authored** (modules + dev/staging/prod envs) — not applied.
- ✅ Root `README.md`, `CLAUDE.md` (root + per-project), `shared/contracts` schemas.

## Phase 1 — Platform foundation (tenancy, RBAC, data model, config) ✅

- ✅ Tenancy + RBAC: `Tenancy` + `Accounts` contexts, `Policy` (permissions),
  personas, memberships, seller levels.
- ✅ Tenant-scoped data-access layer (`Tenancy.scope/2`).
- ✅ JWT validation plug (`JwtAuth`) — RS256+JWKS (ETS-cached) or HS256 secret.
- ✅ Correlation-id plug; rate-limiting plug (ETS, per-user/tenant); tenant-scope plug.
- ✅ Config service: ETS-backed active config + hot-reload endpoint
  (`POST /api/v1/config/reload`).
- ✅ Structured JSON logging (prod) via `LogFormatter`; correlation id in metadata.
- ✅ Health endpoints: `/health` (liveness), `/health/ready` (readiness).
- ✅ Entities PF-01..PF-12 (foundation tables + schemas; later-phase tables created
  by migration, domain code deferred to their phase).
- ✅ Design system + LiveView UI: tokens ported to `assets/css/qa.css`, app shell +
  auth screens + error pages, **`Phoenix.LiveView.JS`** only.

### Verified

- `mix compile --warnings-as-errors`, `mix format --check`, `mix credo`, `mix test`
  (24 tests) all green. Migrations + seeds run idempotently. Server boots; health,
  JWT 401, auth redirects and the design-system login page render.

## Phase 2 — Web app + add-in foundation 🟡 (mostly done)

LiveView persona web app:

- ✅ Persona-aware navigation (SA / AG / SW) in the `qa_app` shell; persona
  authorization via `on_mount` (`:require_site_admin/agency_admin/salesperson`).
- ✅ Persona launcher (CC-01) routes to the right workspace; only shows personas
  the user holds. Post-login lands on `/launcher`.
- ✅ Workspace shells + overviews: `/admin`, `/agency`, `/app`. Admin **Agencies**
  and **Verticals** render real seeded data; agency **Salespeople** from
  memberships; sales **Quotes** (sample) — table + card views.
- ✅ Shared **list engine** (`DataList` LiveComponent): search, sortable headers,
  table/card toggle, pagination — in-memory, slot-based, reusable.
- ✅ **Confidence badge** + `page_header` + `kpi` design components (QAComponents).
- ✅ Outlook add-in **foundation** (`projects/outlook-plugin`): boundary types,
  typed API client (correlation id + bearer + typed errors), MSAL config skeleton,
  email reader (subject/sender/conversationId/itemId/attachments + forwarded
  detection), taskpane wired to the SW-02 state machine. `tsc` passes.
- ✅ Tests (32 total): persona authorization, list-engine search/sort, confidence
  badge. End-to-end login → launcher → workspace verified.

Remaining for Phase 2 completion:

- ⬜ Forgot/reset/verify **token-email flow** (CC-05/06) — still stubbed.
- ⬜ Live **MSAL** token acquisition + Microsoft Graph + Vite build for the add-in
  (foundation/types are in place; needs `@azure/msal-browser` + `@types/office-js`).
- ⬜ Remaining nav sections per workspace (pricing sources, settings, approvals,
  discount policy) and the advanced filter/sort popover.

## Phases 3–13 ⬜

Intake (3) · capture/assignment (4) · AI extraction service (5) · validation/
confidence (6) · pricing (7) · draft generation (8) · quotas/approvals (9) ·
delivery/send (10) · observability (11) · UAT/hardening (12) · prod pilot (13).

## Known follow-ups / caveats

- Auth: forgot/reset/verify screens are built but the **token-email flow** is
  stubbed → wire during Phase 2 completion (with Entra ID, CC-05/06).
- Terraform was authored without a local toolchain — run `terraform fmt` +
  `validate` and commit a provider lockfile before the first infra PR.
- `outlook-plugin` has a typechecking Phase-2 foundation (API client, email
  reader, state machine); live MSAL/Graph + Vite build still to come.
