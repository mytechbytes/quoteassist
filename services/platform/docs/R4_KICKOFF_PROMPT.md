# R4 kickoff — Self-registration (trial onboarding)

Proceed with **R4 (Self-registration / trial onboarding)**, per
`services/platform/docs/RELEASE_PLAN.md` (authoritative) and
`services/platform/CLAUDE.md`. R3 (admin identity + tenant CRUD + 15-day trial) is
done; build on it.

## Before writing code

- Read the **R4 section** of `RELEASE_PLAN.md` and the **"Cross-cutting decisions"**
  block (status FSM, audit log, soft delete). Re-read the R3 code you'll reuse:
  `QuoteAssist.Tenants.create_tenant_with_owner/2` (the `Ecto.Multi`),
  `change_tenant_creation/2`, `Tenant.admin_create_changeset/2`, the status FSM
  (`transition_status/3`), `Tenants.list_tenants_for_admin/0` + `get_tenant_for_admin/1`;
  `QuoteAssist.Plans`; `QuoteAssistWeb.AdminAuth` + the `/admin` console
  (`Admin.TenantLive.Index` + `…Show`, the plan/admin/activity LiveViews,
  `Layouts.admin` nav, `Admin.Components` — `status_badge`, `audit_timeline`);
  `Audit.list_for_tenant/1` · `list_recent/1` · `list_for_admin/2`; the owner-invite +
  `OnboardingLive` flow; `LoginThrottle`.
  Read the design screens `designs/quoteassist/register.html` + `verify.html`.
- Then ask, in **ONE `AskUserQuestion` round**, about the scope forks:
  - **Pending status:** R4 introduces tenant status `pending` (self-registered,
    awaiting approval). Confirm adding `:pending` to the `Tenant` status FSM
    (`pending → trial` on approval, `pending → cancelled`/rejected) and that
    `pending` is **not** resolvable (the workspace stays dark until approved).
  - **Registration model:** reuse `tenants` (+ a `registration` audit trail / a
    `rejected_reason`?) vs a dedicated `registrations` table. The plan reuses
    `tenants`/`users`/`memberships` — confirm.
  - **Verify → set password:** the public flow is verify email → set password. Decide
    whether to reuse `OnboardingLive`/the magic-link path from R3 or a dedicated
    registration confirmation.
  - **Admin review UI:** `/admin/registrations` (list pending/approved/rejected;
    approve → `pending → trial` + email; reject → audited with a note). Confirm it's a
    sibling of `Admin.TenantLive.Index` reusing `Layouts.admin`.
  - **Throttle:** reuse the R1 `LoginThrottle` on `/register` (per-IP + per-email).
- **Reuse the detail-page infrastructure (new in R3).** `/admin/registrations` should
  mirror the `Admin.TenantLive.Index` + `…Show` list/detail pattern (and the
  `Layouts.admin` nav); render the per-registration history with
  `Admin.Components.audit_timeline/1`. Approve/reject decisions already surface in
  `/admin/activity` via the audit log — no extra wiring needed.

## Guardrails (carry over from R1–R3)

- **No toolchain in the sandbox** — write code, then hand over the exact `mix`
  commands + `git add` list. Confirm before commit/push; push to `main` only when asked.
- **`Ecto` `nil` gotcha:** never `where: [field: nil]` / `get_by(x, field: nil)` — use
  `is_nil/1`.
- **Don't `phx.gen.*`** anything that rewrites `root.html.heex` / `router.ex`.
- **Tenant isolation** stays non-negotiable: scope via `Tenancy.scope/2`; resolve the
  tenant from host/session, never params.
- **Audit every privileged action** (registration submit, approve, reject) via
  `Audit.log/1`; reuse the `:admin`/`:user`/`:system` actor types.
- **Status FSM:** add `:pending` transitions to `Tenant`; illegal jumps rejected at the
  changeset; every transition audited via `transition_status/3`.
- **Design system:** port `register.html` + `verify.html`, renaming `mc-*`/`qa-*` →
  `mtb-*`; only `@theme` tokens; `Phoenix.LiveView.JS` only; numbers in `font-mono`.
- **Coverage gate 80%** (`ci/check_coverage.exs`); aim 100%. New pure-markup view
  modules go in `coveralls.json` `skip_files`.
- **Green before done:** `mix format`, `mix compile --warnings-as-errors`, `mix test`,
  `mix credo --strict`, and the coverage check must all pass.
- **Housekeeping when done:** flip `R4 → :done` and `R5 → :in_progress` in
  `PageHTML.release_tracks/0`; update the platform `CLAUDE.md` "Current status";
  switch the home `/register` link from a plain `href` to `~p"/register"`; (optionally)
  write `docs/R5_KICKOFF_PROMPT.md`.
- **Finish with an adversarial verification** (a subagent review): a `pending` tenant
  can't be logged into or resolved; only an admin can approve/reject; approval emails
  the owner and is audited; the register form is throttled and can't forge status; no
  `Tenancy.scope/2` bypass and no nil-comparison Ecto pitfalls.

## Done when (from the plan)

A company self-registers at `/register`; the owner verifies their email and sets a
password; an admin approves at `/admin/registrations` (tenant `pending → trial`,
owner emailed); the owner lands in `/app`. Every decision is audited.
