.PHONY: up down restart logs logs-api logs-web ps build test lint fmt migrate seed reset

# Prefer the repo virtual environment when running Python-based tooling.
VENV_PY := $(shell if [ -x .venv/Scripts/python.exe ]; then printf '.venv/Scripts/python.exe'; elif [ -x .venv/bin/python ]; then printf '.venv/bin/python'; else printf 'python'; fi)

COMPOSE = docker compose -f local.docker.yml

up:
	./scripts/start.sh

down:
	./scripts/stop.sh

restart:
	./scripts/restart.sh

ps:
	$(COMPOSE) ps

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f --tail=200

logs-api:
	$(COMPOSE) logs -f --tail=200 api

logs-web:
	$(COMPOSE) logs -f --tail=200 react-app nginx nginx-static

test:
	$(COMPOSE) exec -T api pytest
	$(COMPOSE) exec -T django pytest
	cd react-app && npm run test:ci

lint:
	cd react-app && npm run lint
	$(VENV_PY) -m ruff check .

fmt:
	cd react-app && npm run format
	$(VENV_PY) -m ruff format .

migrate:
	$(COMPOSE) exec -T django python manage.py migrate

seed:
	$(COMPOSE) exec -T api python -m api.scripts.seed

reset:
	@if [ "$(CONFIRM)" != "1" ]; then echo "Refusing to reset without CONFIRM=1"; exit 1; fi
	$(COMPOSE) down -v
