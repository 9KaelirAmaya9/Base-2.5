.PHONY: up down restart logs logs-api logs-web ps build test test-integration test-perf lint fmt migrate seed reset dev-install dev-install-api dev-install-django dev-install-do

# Prefer the repo virtual environment when running Python-based tooling.
VENV_PY := $(shell if [ -x .venv/Scripts/python.exe ]; then printf '.venv/Scripts/python.exe'; elif [ -x .venv/bin/python ]; then printf '.venv/bin/python'; else printf 'python'; fi)

COMPOSE_FILE ?= development.docker.yml
ENV_FILE ?= .env
COMPOSE = docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE)

up:
	./scripts/start.sh --compose-file $(COMPOSE_FILE) --env-file $(ENV_FILE)

down:
	./scripts/stop.sh --compose-file $(COMPOSE_FILE) --env-file $(ENV_FILE)

restart:
	./scripts/restart.sh --compose-file $(COMPOSE_FILE) --env-file $(ENV_FILE)

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
	./scripts/test.sh --compose-file $(COMPOSE_FILE) --env-file $(ENV_FILE)

test-integration:
	$(COMPOSE) exec -T api pytest -m integration -o addopts=
	$(COMPOSE) exec -T django pytest -m integration -o addopts=

test-perf:
	$(COMPOSE) exec -T api pytest -m perf -o addopts=

dev-install:
	@echo "Choose a service-specific target: dev-install-api, dev-install-django, or dev-install-do"; exit 1

dev-install-api:
	$(VENV_PY) -m pip install -r requirements-dev-api.txt

dev-install-django:
	$(VENV_PY) -m pip install -r requirements-dev-django.txt

dev-install-do:
	$(VENV_PY) -m pip install -r digital_ocean/requirements.txt

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

