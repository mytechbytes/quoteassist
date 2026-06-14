# QuoteAssist

AI-assisted, multi-tenant, multi-vertical **lead-to-quote platform**. Omni-channel
lead intake → auto-assignment → AI requirement capture → pricing → drafted reply →
salesperson approval → send. R1 targets Airline/Travel end-to-end with
multi-tenancy baked in from day one; auto-send is disabled (human-in-the-loop).

Full requirements & solution design:
[`docs/QuoteAssist-Unified-Requirements-and-Solution-Design-v1.md`](docs/QuoteAssist-Unified-Requirements-and-Solution-Design-v1.md).

## Architecture at a glance (§8)

Two cooperating runtimes plus an embeddable add-in:

- **Platform plane — Elixir / Phoenix** (`projects/platform`): orchestration,
  tenancy, RBAC, pricing/approval/quoting, **and the LiveView web UI**.
- **AI plane — Python / FastAPI** (`projects/ai-service`): extraction, model
  routing, RAG, confidence — behind a versioned `extract / embed / classify`
  contract.
- **Outlook add-in — Office.js** (`projects/outlook-plugin`): same flow against a
  selected email (Phase 2).

> The web UI is **Phoenix LiveView** (server-rendered, `Phoenix.LiveView.JS` for
> client interactions) using the design system in `designs/`. This supersedes the
> React web app named in the original design doc; see
> [`CLAUDE.md`](CLAUDE.md) for the rationale.

## Repository layout

```
quote-assist/
├── projects/
│   ├── platform/        # Elixir/Phoenix — orchestration + LiveView UI + API
│   ├── ai-service/      # Python/FastAPI — extraction/embed/classify
│   ├── outlook-plugin/  # Office.js add-in (Phase 2 stub)
│   └── shared/contracts # JSON-schema service-boundary contracts
├── designs/             # design tokens + screens (Claude design output)
├── infrastructure/      # Terraform (authored Phase 0, applied Phase 13)
├── docs/                # requirements & solution design, phase progress
├── docker-compose.yml   # db (pgvector) · redis · ai-service · platform
└── Makefile             # one-command dev helpers
```

## Prerequisites

- **Erlang/OTP 29** and **Elixir 1.18+** (1.19.x is installed/used because 1.18
  predates OTP 29; `mix.exs` requires `~> 1.18`). See `.tool-versions`; `asdf install`.
- **Docker** (for Postgres + Redis), or a local Postgres 16 with the `pgvector`
  and `citext` extensions available.
- **Python 3.12** (for the AI service).

## Quick start (local)

```sh
# 1. Start datastores (Postgres w/ pgvector + Redis)
make db

# 2. Set up the platform: deps, create DB, migrate, seed, build assets
make setup

# 3. Run the platform (web UI + API + LiveView) on http://localhost:4000
make platform
```

Or run the whole stack in containers:

```sh
cp .env.example .env     # no real secrets needed for local
make up                  # db, redis, ai-service, platform
```

### Demo logins (seeded; dev password `quoteassist-dev-pw`)

| Email                    | Persona              |
| ------------------------ | -------------------- |
| `admin@quoteassist.dev`  | Site admin           |
| `daniel@skyline.dev`     | Agency admin         |
| `rana@skyline.dev`       | Salesperson (senior) |

Health probes: `GET /health` (liveness), `GET /health/ready` (readiness).

## Common commands

| Command        | What it does                                            |
| -------------- | ------------------------------------------------------- |
| `make db`      | start Postgres (pgvector) + Redis                       |
| `make setup`   | deps + create/migrate/seed DB + build assets            |
| `make platform`| run Phoenix on :4000                                    |
| `make ai`      | run the FastAPI AI service on :8000                     |
| `make migrate` | run Ecto migrations                                     |
| `make seed`    | (re)run seed data (idempotent)                          |
| `make check`   | platform quality gate (format, compile, credo, test)   |
| `make test`    | platform tests                                          |

## CI

Per-package GitHub Actions (`.github/workflows/`): `platform` (format/credo/
dialyzer/test), `ai-service` (ruff/mypy/pytest), `outlook-plugin` (lint/typecheck/
build), `infra-plan` (terraform fmt/validate — **no apply**).

## Status

Phases **0 (setup) and 1 (platform foundation)** are complete. See
[`docs/PHASE_PROGRESS.md`](docs/PHASE_PROGRESS.md) for the per-phase checklist and
what's next.
