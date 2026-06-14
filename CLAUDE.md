# CLAUDE.md — QuoteAssist (root)

Guidance for Claude (and humans) working in this monorepo. Read this first, then
the per-project `CLAUDE.md` in `projects/platform` and `projects/ai-service`.

## What this is

A multi-tenant, multi-vertical **lead-to-quote platform** (see
`docs/QuoteAssist-Unified-Requirements-and-Solution-Design-v1.md`). R1 = Airline/
Travel, end-to-end, human-in-the-loop (auto-send disabled).

## Locked decisions (don't relitigate without the user)

1. **Stack:** Elixir/Phoenix platform plane + Python/FastAPI AI service. Azure cloud.
2. **Web UI = Phoenix LiveView**, not React. Use **`Phoenix.LiveView.JS`** for
   client-side interactions (no Alpine/jQuery/bespoke JS framework). This
   supersedes the "React web app" named in the solution-design doc — the doc
   predates this decision; the code is the source of truth.
3. **Design system:** the screens/tokens in `designs/` are authoritative. The
   QuoteAssist design system (teal accent, mist neutrals, Inter + Familjen
   Grotesk + JetBrains Mono) lives in `projects/platform/assets/css/qa.css`
   (ported from `designs/quoteassist/qa.css`). Build UI from `mc-*` / `qa-*`
   classes + Tailwind utilities. Dark mode is keyed off `[data-theme="dark"]`.
4. **Toolchain:** Erlang/OTP 29, Elixir 1.18+ line. (The user said "1.8"; that
   release predates OTP 29 and is impossible here — 1.18 is the intended line.
   In practice **Elixir 1.19.x** is installed/used because 1.18 predates OTP 29
   support; `mix.exs` requires `~> 1.18` and CI runs OTP 29 + Elixir 1.19.)
5. **Repo layout:** apps live under `projects/` (the user moved them there).
   `infrastructure/`, `designs/`, `docs/` stay at the repo root.
6. **Data model:** UUID (`binary_id`) PKs everywhere, `utc_datetime` timestamps,
   every tenant-owned row carries `tenant_id`, referenced by stable id never label.
7. **R1 safety:** `confidence_configs.auto_send_enabled = false` everywhere.

## Where things are

- Requirements/design: `docs/…-v1.md` (§8 architecture, §13 phases, §20 layout).
- Phase progress + next steps: `docs/PHASE_PROGRESS.md`.
- Service-boundary contracts: `projects/shared/contracts/` (JSON Schema).
- Design screens/tokens: `designs/` (see `designs/quoteassist/`).

## How to run

```sh
make db        # Postgres (pgvector) + Redis
make setup     # deps + create/migrate/seed + assets
make platform  # Phoenix on :4000
make check     # format + compile(--warnings-as-errors) + credo + test
```

## Points to consider for EACH session

- **Confirm the phase.** Check `docs/PHASE_PROGRESS.md`; only build what the
  current phase covers. Later-phase tables exist (Phase 0 authored them) but their
  domain code is intentionally absent until their phase.
- **Tenant isolation is non-negotiable.** Any tenant-owned query goes through
  `QuoteAssist.Tenancy.scope/2`. Resolve `tenant_id` from JWT claims (API) or the
  current membership (LiveView) — never from request params.
- **Use the design system.** New UI = `mc-*`/`qa-*` classes + Tailwind utilities,
  `Phoenix.LiveView.JS` for interactions. Don't introduce a JS framework or invent
  colors outside the tokens. No emoji in product UI. Numbers in JetBrains Mono.
- **Config is versioned, not edited.** Changing prompts/schemas/templates/
  thresholds = insert a new active version (PF-10) and `ConfigService.reload()`;
  never destructively update.
- **Keep the boundary thin.** The Elixir `extraction/` context only calls the
  Python AI service via `projects/shared/contracts`. Model/prompt/RAG changes stay
  inside `ai-service`.
- **Audit everything.** State transitions append to `audit_logs` (immutable) and
  the activity feed; never persist full message bodies (mask in audit).
- **Green before done.** `make check` (platform) must pass: `mix format`,
  `mix compile --warnings-as-errors`, `mix credo`, `mix test`.
- **Infra is authored, not applied** until Phase 13. Don't run `terraform apply`.
- **Update progress.** When you finish meaningful work, update
  `docs/PHASE_PROGRESS.md` so the next session has continuity.
