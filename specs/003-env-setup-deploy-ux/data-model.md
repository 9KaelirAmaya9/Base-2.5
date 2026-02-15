# Phase 1 Data Model — End-to-End Environment Setup + Deploy UX

**Branch**: 003-env-setup-deploy-ux
**Date**: 2026-02-05

This feature does not introduce database schema changes. Its “data model” is primarily file-based configuration plus derived identifiers.

## Entities

### 1) Environment Configuration (`.env`)

- Description: The user-editable set of key/value pairs used by Docker Compose, application services, and deployment tooling.
- Source of truth: `.env` (generated/updated from `.env.example` via setup tooling).
- Key fields (representative):
  - Core: `PROJECT_NAME`, `PROJECT_DISPLAY_NAME` (planned), `ENV`, `WEBSITE_DOMAIN`, `DEPLOY_MODE`
  - Derived identifiers: `COMPOSE_PROJECT_NAME`, `NETWORK_NAME`, cookie names, JWT issuer/audience
  - Secrets: `DJANGO_SECRET_KEY`, `JWT_SECRET`, `TOKEN_PEPPER`
  - Admin/Access controls: `TRAEFIK_DASH_BASIC_USERS`, `*_ALLOWLIST`
  - TLS/SMTP: `TRAEFIK_CERT_EMAIL`, SMTP settings
  - DigitalOcean: `DO_*` variables (required only when `DEPLOY_MODE=digitalocean`)

### 2) Example Configuration (`.env.example`)

- Description: A commented template that documents all supported configuration keys.
- Role in this feature: Treated as the authoritative template for writing `.env` so comments/order are preserved.

### 3) Placeholder

- Description: A value considered unfinished and therefore invalid for required categories.
- Validation rule: `isPlaceholder(value, key)` treats values as placeholder when empty or matching known placeholder patterns.
- Examples:
  - `change_me_long_random_string`
  - `your_google_client_id`
  - `your_ip_address_here/32`

### 4) Category

- Description: A labeled grouping of configuration keys used for validation and user guidance.
- Categories:
  - Core (always required)
  - Secrets (always required)
  - Admin (always required)
  - Access (always required)
  - TLS (required when `ENV=production` or `DEPLOY_MODE=digitalocean`)
  - SMTP (required when `ENV=production` or `DEPLOY_MODE=digitalocean`)
  - OAuth (optional unless explicitly enabled)

### 5) Backup (`.env.bak.*`)

- Description: A timestamped snapshot created before overwriting `.env`.
- Lifecycle:
  - Created by `setup` and `setup:complete` before they write.
  - Must be ignored by git.

### 6) Doctor Report

- Description: A structured report of readiness findings.
- Forms:
  - Human-readable console output.
  - Stable JSON output when `doctor --json` is used.
- Contract: JSON schema in `specs/003-env-setup-deploy-ux/contracts/doctor-output.schema.json`.

## State Transitions

- Fresh clone → `setup` creates `.env` from `.env.example`.
- Partial config → `setup:complete` validates required categories and generates missing credentials.
- Ready config → `doctor` reports success and recommends next action (start locally or deploy).

## Validation Rules (high level)

- Required categories depend on `ENV` and `DEPLOY_MODE`.
- Placeholders are invalid in required categories.
- Allowlists must be valid CIDR(s) and not placeholder.
- Hashed credentials must be safe for `.env`/Compose (`$` escaped as `$$`).
