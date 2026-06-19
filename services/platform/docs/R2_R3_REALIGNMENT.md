# R2/R3 Realignment — code ↔ rewritten RELEASE_PLAN

The rewritten `RELEASE_PLAN.md` describes a more advanced R2/R3 design than the
shipped code (which was built against an earlier plan). This pass realigns the
**R2 (Tenancy + RBAC)** and **R3 (Plans)** code to the rewritten plan. R0/R0a/R1
were already conformant; only stale release-numbering was refreshed there.

> ⚠️ **Not compiled/tested here.** The realignment was done in an environment with
> no Elixir/OTP toolchain (hex blocked, macOS-built `_build`/NIFs). Run the green
> gate on your machine before relying on it:
>
> ```sh
> cd services/platform
> mix deps.get
> mix compile --warnings-as-errors
> mix format
> mix credo --strict           # or: mix check
> mix test
> ```

## What changed

### Permissions + Policy (R2)
- `Authz.Permissions` — catalog rewritten from dot-style (`quotes.view`,
  `pricing.*`, `team.*`) to colon-style CRUD per the plan: `quote:* user:* role:*
  request:* settings:* domain:* billing:*` (33 keys) + lifecycle verbs
  (`activate/deactivate/status/reply/ai_generate/verify/manage`). Added the fixed
  `self:*` baseline (`baseline/0`, `baseline?/1`) — not role-composable.
- `Authz.Policy.can?/3` — now the protected-type predicate: `owner` short-circuits
  to `true` (computed all-access, future-proof); members get `self:*` baseline +
  their role's keys. `permissions_for_membership/1` returns `[]` for owners.

### Memberships — owner as a protected type (R2)
- `Tenants.Membership` gained `type` (`:owner | :member`) and `active`; `role_id`
  is now nullable (owners carry no role). New `member_changeset/2` +
  `owner_changeset/2`; `role_label/1` for safe display.
- `Tenants`: `create_owner_membership/2`, `active_owner_count/1` (last-active-owner
  guard helper), `owner_email/1` resolves by `type == :owner`,
  `create_tenant_with_owner/2` creates the owner as a type (no role).
- Seeded member roles are now `manager` + `agent` (owner is a type, not a role).
- `Tenancy` gained query-layer owner protection: `members_visible_to/1` (excludes
  owners for non-owner actors) + `assignable_types_for/1`.
- Migration: `20260618000001_add_membership_type_and_active`.

### Plans — DB-backed feature limits (R3)
- `Plans.Plan`: `monthly_price`/`seat_limit` → `price` (paise), `interval`,
  `limits` (jsonb: `quotes_per_month`, `seats`, `ai_generations_per_month`,
  `custom_domain`), `active`. Robust limit coercion in the changeset.
- `Plans.seed_plans/0` seeds **three** (Starter/Growth/Scale) with ascending limits.
- Admin plan LiveViews (index + show) updated to the new fields + a limits editor.
- Migration: `20260618000003_add_plan_features`.

### Audit (R2 cross-cutting)
- `audit_logs` gained `actor_subtype` (`super_admin|admin|owner|member|null`).
  Column + schema field + cast added; population is incremental (nil where the
  tier isn't yet known — admin tiers land in R4-retrofit).
- Migration: `20260618000002_add_actor_subtype_to_audit_logs`.

### Docs / numbering
- Home-page build board (`PageHTML.release_tracks/0`) and stale comments updated to
  the new R0–R12 index (R4-retrofit, R5-selfreg, R6-errors, R7-rbac, R8-dashboard,
  R9-recovery, R10-domain, R11-quotes, R12-quote-reply).

### Tests
- Fixtures (`tenants`, `plans`), `policy_test`, `tenants_test`, `tenancy_test`,
  `plans_test`, `plans_admin_test`, `plan_live_test`, `user_auth_test`,
  `app_home_live_test`, `tenants_admin_test` updated to the new model; added
  coverage for owner-type membership, owner-protection helpers, and limit coercion.

## Deliberate deviations (flag for review)
- **`role_permissions` table not introduced.** Roles store `permissions` as a
  validated string array (the shipped approach), which is functionally equivalent
  to the plan's join-table sketch for a fixed code-owned catalog. Splitting into a
  join table is deferrable to R7-rbac if desired.
- **`actor_subtype` not yet populated** for existing audit calls (admin tiers are
  R4-retrofit; owner/member actions are R7-rbac). The column exists now so no
  migration is needed when population lands.
- New migrations are **additive** (R0–R3's original migrations stay frozen, per the
  plan's "shipped record" note).
