# R5 kickoff — Users, roles, permissions

Proceed with **R5 (Users, roles, permissions)**, per
`services/platform/docs/RELEASE_PLAN.md` (authoritative) and
`services/platform/CLAUDE.md`. R3 (admin identity + tenant CRUD + trial) and the
admin detail pages are done; R4 (self-registration) may or may not be done yet —
check `PageHTML.release_tracks/0`. R5 is **tenant-scoped** (inside the `/app`
workspace), not the admin console.

**Ships:** a tenant owner/manager invites users, assigns them roles composed from the
fixed permission catalog, and can deactivate / soft-remove members — without being
able to lock the tenant out of its own admin.

## Before writing code

- Read the **R5 section** of `RELEASE_PLAN.md` and the **"Cross-cutting decisions"**
  block (soft delete, audit log, status FSMs). Re-read what you'll build on:
  - **RBAC (R2):** `QuoteAssist.Authz.Permissions` (the code-owned catalog —
    `catalog/0`, `keys/0`, `valid?/1`, `label/1`, grouped for display),
    `QuoteAssist.Authz.Policy` (`can?/3`, `permissions_for_membership/1`),
    `QuoteAssist.Tenants.Role` (`changeset/2` already validates permissions against
    the catalog; `builtin` flag), `Tenants.seed_default_roles/1` +
    `default_role_specs/0` (owner/lead/senior/agent/viewer), `Tenants.create_role/2`,
    `get_role_by_slug/2`, `Tenants.Membership` + `create_membership/3`,
    `get_active_membership/2`, `member?/2`.
  - **Scoping (R2):** `QuoteAssist.Tenancy.scope/2` — every role/membership query is
    tenant-scoped through this. `Accounts.Scope` carries `tenant`, `membership`, and
    `permissions`; `on_mount :require_tenant_member` populates it.
  - **Invite/onboarding (R3):** the `Tenants.create_tenant_with_owner/2` `Ecto.Multi`
    pattern, the `ensure_owner_user/1` reuse-or-register helper, the magic-link invite
    built on the **tenant host**, and `QuoteAssistWeb.OnboardingLive` (set
    display_name + password).
  - **UI:** `QuoteAssistWeb.Layouts.workspace` shell + the already-stubbed **Team**
    nav item (`/app/team`, currently a plain `href`); `Admin.Components.audit_timeline`
    and the assign-driven modal pattern from `Admin.TenantLive.Index`/`Show`;
    `Audit.log/1` + `Audit.list_for_tenant/1`.
  - Design screen `designs/quoteassist/team.html` (+ `qa-team.js` for the catalog
    grouping the design uses).
- Then ask, in **ONE `AskUserQuestion` round**, about the scope forks below.

## Scope forks (decide before building)

- **Lockout-guard permission.** The plan says the "last membership with `user:manage`
  can't be removed or demoted". Our catalog has no `user:manage` — it has
  `team.view / team.invite / team.roles / team.remove`. Confirm which key is the
  "tenant admin" capability the guard protects (recommend **`team.roles`** — manage
  roles & permissions). The guard: refuse to soft-remove or role-change the **last
  live membership whose role grants that key**.
- **Built-in roles.** `Role.builtin` is already seeded `true` for the five defaults.
  Confirm built-ins are **locked** (not editable/deletable in the UI) and only
  custom roles can be edited/deleted — built-ins are the safety net.
- **Invite mechanism.** Reuse the R3 magic-link + `OnboardingLive` (member created
  unconfirmed, emailed a link on the tenant host, sets password via onboarding) vs a
  dedicated invite-token context. Recommend **reuse** (consistent with R3; no new
  token type).
- **Member states.** "deactivate" vs "soft-remove": is *deactivate* a distinct
  reversible state (needs a `memberships.status`/`active` column + migration) or do we
  ship **soft-remove only** (`deleted_at`, re-invitable) for R5 and defer a separate
  deactivated state? Recommend soft-remove only unless you want the extra state.
- **UI shape.** One `/app/team` with Members | Roles tabs, vs `/app/team` +
  `/app/team/roles`. Confirm (recommend two routes for clean deep-links + per-tab
  permission gating).

## Guardrails (carry-over)

- **No toolchain in the sandbox** — write code, then hand over exact `mix` commands +
  a `git add` list. Confirm before commit/push; push to `main` only when asked.
- **Tenant isolation is the whole point of R5.** Every roles/memberships query goes
  through `Tenancy.scope/2`; resolve the tenant from `current_scope` (session
  membership), **never** params. (Contrast with the admin console, which is
  deliberately cross-tenant — R5 is the opposite.)
- **Permission-gate every action** with `Policy.can?(scope, key)` — in the LiveView
  (hide/disable controls) **and** in the context/handler (authorize server-side; the
  UI is not a security boundary). Roles only ever compose catalog keys — never invent
  permissions; `Role.changeset` already rejects unknown keys.
- **Audit every privileged action** (invite, role assign/change, role create/edit/
  delete, member remove) via `Audit.log/1` — `actor_type: :user`, `actor_id`,
  `tenant_id` set, emails masked. Surface it with the existing `audit_timeline`.
- **Design system:** port `team.html`, renaming `mc-*`/`qa-*` → `mtb-*`; only `@theme`
  tokens; `Phoenix.LiveView.JS` only; numbers in `font-mono`; no emoji.
- **Coverage gate 80%** (`ci/check_coverage.exs`); aim high. Pure-markup view modules
  go in `coveralls.json` `skip_files`.
- **Green before done:** `mix format`, `mix compile --warnings-as-errors`, `mix test`,
  `mix credo --strict`, and the coverage check all pass (`mix ecto.check` runs the
  lot).

## Learnings from R3–R4 + the detail pages (apply these — they cost us a cycle each)

- **`mix credo --strict` catches that bit us:**
  - *Nesting max depth 2* (`Refactor.Nesting`). Adding a `case`/`if` inside an existing
    one trips it — extract a helper (we split `consume_magic_link/4` out of the login
    controller). Keep handler bodies flat; prefer a `cond` of guard-clauses + helpers.
  - *Grouping* — clauses of the same `name/arity` must be adjacent. Don't insert a
    different `defp` between two `defp create/3` clauses.
  - *String literals with >3 quotes* → use a sigil or rephrase (an audit-label
    doc-string flagged this). Avoid `\"`-heavy docs.
  - *Alias order* is enforced (alphabetical; `Ecto.*` before `QuoteAssist.*`).
    `MaxLineLength`, `ModuleDoc`, `AliasUsage` are **disabled** in `.credo.exs`.
- **Seeds vs the test DB.** `seeds.exs` runs during `mix ecto.setup`/`reset`, **and
  `mix ecto.check` resets under `MIX_ENV=test`** — anything seeded unconditionally
  lands in the test DB and collides with fixtures (our plans seed broke 3 tests).
  Guard env-specific seed data (`unless deploy_env == "test"`); let the suite own a
  clean table and build its own fixtures.
- **Ecto pitfalls.** Never `where: [field: nil]` / `get_by(.., nil)` — use `is_nil/1`.
  And a route `:id` is untrusted: `where: x.id == ^id` raises `Ecto.Query.CastError`
  (→ 500) on a non-UUID. Guard every params-sourced id with `Ecto.UUID.cast/1` and
  return nil → redirect (see `Tenants.get_tenant_for_admin/1`, `Plans.get_plan/1`,
  `Accounts.get_admin/1`).
- **Narrow your changesets.** A rendered form is not a security boundary — a crafted
  submit can send any field. Lock edit changesets to exactly the editable fields
  (`Tenant.admin_update_changeset` = name+plan; `Plan.update_changeset` drops slug).
  For R5: role edits must never let a member grant a permission not in the catalog
  (covered) and must not edit a `builtin` role if you lock those.
- **LiveView patterns that worked:**
  - Assign-driven modals (`@modal = :new | {:edit, x} | {:delete, x}`) with `:if`-gated
    function components; `:if` short-circuits attribute evaluation, so `elem(@modal, 1)`
    is safe.
  - Map untrusted event strings via a `parse_*/1` whitelist — **never**
    `String.to_existing_atom/1` on `phx-value-*`.
  - `attr` declarations work on private function components.
  - **Don't break the passwordless model.** Tenant users can be magic-link-only (no
    password); `update_user_password` deletes all tokens (logs them out), so onboarding
    uses a non-token-deleting `onboard_user`. Don't force flows via a global redirect
    keyed on `is_nil(hashed_password)` — it breaks magic-link members and existing
    tests; use a prompt/banner instead.
- **Test patterns that worked:**
  - Assert redirects as `{:error, {kind, %{to: path}}}` with
    `assert kind in [:redirect, :live_redirect]` (robust to dead- vs connected-mount).
  - Give a control a stable `id` when its text isn't unique (`#new-agency`,
    `#tenant-form`); scope row actions with `element("#row-#{id} button", "Label")`.
  - A redirect-causing action returns the redirect tuple from `render_click`/
    `render_submit` — match it directly.
  - The test base domain is `example.com`, so `www.example.com` is the platform host
    and `acme.example.com` is a tenant subdomain — set `conn.host`/`put_tenant_host`
    accordingly (R5 lives on the tenant host).
- **Reuse the audit timeline + context-level auditing** rather than logging from the
  LiveView; mirror the R3 `Ecto.Multi` (entity + membership + audit, side-effect email
  after commit) for the invite flow.

## Done when (from the plan)

A tenant owner/manager invites a user (email → set password → joins the tenant via a
new membership), assigns a role, and that user signs in with exactly the role's
permissions; a manager can create/edit a custom role from the catalog and
deactivate/soft-remove members; and the system blocks removing or demoting the last
member who can manage the team. Every action is audited and visible in the activity
timeline.

## Housekeeping when done

Flip `R5 → :done` and `R6 → :in_progress` in `PageHTML.release_tracks/0`; update the
platform `CLAUDE.md` "Current status"; switch the workspace **Team** nav item from a
plain `href` to `~p"/app/team"`; (optionally) write `docs/R6_KICKOFF_PROMPT.md`. Finish
with an adversarial review focused on: no cross-tenant role/membership read (every
query scoped); server-side permission checks on every mutation (not just hidden UI);
the last-manager lockout guard holds under soft-remove **and** role-change; invites
can't escalate (catalog-only permissions, no `builtin` tampering); audited; no
nil/UUID Ecto pitfalls.
