.PHONY: up down setup platform ai plugin fmt

up:            ## start the full stack (db, redis, ai-service, platform)
	docker compose up --build

down:
	docker compose down

setup:         ## one-time local setup of the platform
	cd platform && mix setup

platform:      ## run the Phoenix platform (web + API + LiveView) on :4000
	cd platform && mix phx.server

ai:            ## run the Python AI service on :8000
	cd ai-service && uvicorn app.main:app --reload --port 8000

plugin:        ## run the Outlook add-in dev server on :3000 (https)
	cd outlook-plugin && npm run dev

fmt:
	cd platform && mix format
