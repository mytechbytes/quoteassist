.PHONY: up down setup platform ai plugin fmt test migrate seed check

up:            ## start the full stack (db, redis, ai-service, platform)
	docker compose up --build

down:          ## stop the stack
	docker compose down

db:            ## start just Postgres (pgvector) + Redis
	docker compose up -d db redis

setup:         ## one-time local setup of the platform (deps, db, assets, seeds)
	cd projects/platform && mix setup

migrate:       ## run Ecto migrations
	cd projects/platform && mix ecto.migrate

seed:          ## (re)run seed data — idempotent
	cd projects/platform && mix run priv/repo/seeds.exs

platform:      ## run the Phoenix platform (web + API + LiveView) on :4000
	cd projects/platform && mix phx.server

ai:            ## run the Python AI service on :8000
	cd projects/ai-service && uvicorn app.main:app --reload --port 8000

plugin:        ## run the Outlook add-in dev server on :3000 (https)
	cd projects/outlook-plugin && npm run dev

check:         ## full platform quality gate (format, compile, credo, test)
	cd projects/platform && mix check

test:          ## run platform tests
	cd projects/platform && mix test

fmt:           ## format Elixir code
	cd projects/platform && mix format
