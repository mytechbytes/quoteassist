# QuoteAssist

A **multi-tenant AI-powered quote assistant**. Each tenant (organisation) gets
an isolated workspace on its own subdomain (and, optionally, a custom domain).
A quote request is a lead; the reply — manual now, AI-generated later — is the
quote. Built in thin vertical slices, every release independently deployable.

The authoritative build plan is
[`services/platform/docs/RELEASE_PLAN.md`](services/platform/docs/RELEASE_PLAN.md).
Working guidance for contributors (and Claude) lives in
[`CLAUDE.md`](CLAUDE.md) and [`services/platform/CLAUDE.md`](services/platform/CLAUDE.md).

## Architecture

Two cooperating runtimes:

- **Platform plane — Elixir / Phoenix** (`services/platform`): tenancy, RBAC,
  quoting, and the **Phoenix LiveView** web UI. This is the focus of the current
  releases.
- **AI plane — Python / FastAPI** (`services/ai-service`): prompt, model, and
  response generation behind a thin HTTP contract. Slots in at R8 without
  changing any screens; stubbed until then.

The web UI is **Phoenix LiveView** (server-rendered, `Phoenix.LiveView.JS` for
client interactions) using the design system in `designs/`.

## Repository layout

```
quote-assist/
├── services/
│   ├── platform/        # Elixir/Phoenix — tenancy, RBAC, quoting + LiveView UI
│   │   └── docs/        # RELEASE_PLAN.md (authoritative build plan)
│   └── ai-service/      # Python/FastAPI — prompt/model/response (later)
├── designs/             # design tokens + reference screens (mc-*/qa-* → mtb-*)
├── docker-compose.yml   # db (Postgres/pgvector) · redis · ai-service · platform
└── Jenkinsfile          # CI pipeline
```

## Tenancy model

- Platform host: `quoteassist.mytechbytes.in` — public home, tenant directory,
  and admin.
- Tenants live on `*.quoteassist.mytechbytes.in` (e.g.
  `acme.quoteassist.mytechbytes.in`); the subdomain label is the tenant `slug`.
- A tenant may also add a verified **custom domain** (e.g. `quotes.acme.com`);
  the subdomain keeps working as a permanent fallback.
- Resolution is by request **host** via the `TenantResolver` plug — never from
  params. Dev uses `*.lvh.me:4000` for subdomains.

## Prerequisites

- **Elixir 1.15+** / recent Erlang/OTP, **Phoenix 1.8**, **Phoenix LiveView 1.2**.
- **Docker** (for Postgres + Redis), or a local Postgres with the `citext`
  (and, for the AI plane later, `pgvector`) extensions.
- **Python 3.12** — only needed once the AI service is implemented.

## Quick start (local)

Run the platform on the host with hot reload:

```sh
# 1. Start datastores
docker compose up -d db redis

# 2. Set up the platform: deps, create DB, migrate, seed
cd services/platform
mix deps.get && mix ecto.setup

# 3. Run Phoenix (web UI + LiveView) on http://localhost:4000
mix phx.server
```

Or run the production-like stack in containers (the platform image is a
production release, not `mix phx.server`):

```sh
docker compose up        # db, redis, ai-service, platform
```

Health probes: `GET /health` (liveness), `GET /health/ready` (readiness) — land
in R0.

## Common commands (from `services/platform`)

| Command                                | What it does                          |
| -------------------------------------- | ------------------------------------- |
| `mix deps.get`                         | fetch dependencies                    |
| `mix ecto.setup`                       | create + migrate + seed the DB        |
| `mix phx.server`                       | run Phoenix on :4000                  |
| `mix test`                             | run the test suite                    |
| `mix format`                           | format code                           |
| `mix compile --warnings-as-errors`    | compile clean (part of the gate)      |

"Green before done": `mix format`, `mix compile --warnings-as-errors`, and
`mix test` must all pass.

## CI

Continuous integration runs through the [`Jenkinsfile`](Jenkinsfile) pipeline.

## Status

Phoenix scaffold in place; **R0 (walking skeleton) is the next release**. See
[`services/platform/docs/RELEASE_PLAN.md`](services/platform/docs/RELEASE_PLAN.md)
for the R0–R8 build order and per-release detail.
