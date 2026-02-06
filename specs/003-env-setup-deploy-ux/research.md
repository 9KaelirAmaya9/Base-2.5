# Phase 0 Research — End-to-End Environment Setup + Deploy UX

**Branch**: 003-env-setup-deploy-ux  
**Date**: 2026-02-05

## Unknowns & Decisions

### 1) Where should the new CLIs live?

- Decision: Implement `setup.js`, `complete-setup.js`, `doctor.js`, and `envRules.js` as Node scripts under `scripts/`.
- Rationale: The repo already centralizes operational helpers under `scripts/` (Bash + PowerShell). Node provides cross-platform behavior by default (Windows/macOS/Linux), while existing shell wrappers can remain for Docker lifecycle.
- Alternatives considered:
  - New `tools/` or `cli/` folder at repo root — rejected to avoid introducing a parallel convention and to keep ops tooling discoverable.

### 2) How to parse and write `.env` without losing documentation?

- Decision: Treat `.env.example` as the authoritative template, and generate `.env` by merging:
  1. user prompts,
  2. derived identifiers from `PROJECT_NAME`, and
  3. any existing non-placeholder values from the current `.env`.
- Rationale: `.env.example` contains extensive inline documentation and key ordering; using it as the writer template preserves comments and structure.
- Alternatives considered:
  - `dotenv` parse + reserialize — rejected because it drops comments/order.
  - In-place editing of `.env` lines — rejected due to complexity with missing keys and comment blocks.

### 3) How to represent “cloud deploy mode” in config?

- Decision: Add `DEPLOY_MODE=local|digitalocean` to `.env` and use it for validation requirements and recommendations.
- Rationale: It’s explicit, stable, and doesn’t require inferring intent from partially-filled DigitalOcean variables.
- Alternatives considered:
  - Infer deploy intent from `DO_*` variables — rejected because partial configs are common during onboarding.
  - Boolean `CLOUD_DEPLOY=true|false` — acceptable, but `DEPLOY_MODE` is more extensible if additional targets are added later.

### 4) How to generate and store basic-auth credentials safely?

- Decision: Generate bcrypt-compatible hashes using a portable Node dependency (`bcryptjs`) and escape `$` as `$$` when writing to `.env`.
- Rationale: Bcrypt is the desired modern hash format and is already an accepted pattern in repo tooling (`scripts/generate-traefik-auth.ps1`). `bcryptjs` avoids native build issues across platforms.
- Alternatives considered:
  - Use `docker run httpd htpasswd -nbB` — rejected as the default because it adds a hard Docker dependency for credential generation (though it may remain as an optional fallback).
  - Use apr1/MD5 htpasswd — rejected for default due to weaker hashing.

### 5) Public IPv4 detection strategy

- Decision: Query multiple endpoints and accept the first valid IPv4 result, with strict IPv4 validation.
- Rationale: Endpoints can fail intermittently; multi-source improves reliability.
- Alternatives considered:
  - Single endpoint only — rejected due to flakiness.
  - IPv6 support — deferred; feature explicitly requires public IPv4.

### 6) Placeholder detection rules

- Decision: Shared placeholder predicate treats values as unfinished if:
  - empty/whitespace
  - contain well-known placeholder tokens (case-insensitive), e.g. `change_me`, `your_`, `_here`, `example`, `placeholder`, `bcrypt_hash_here`, `generated_password_here`
  - contain allowlist placeholders like `your_ip_address_here/32` or invalid CIDR forms
- Rationale: `.env.example` and docs use consistent placeholder wording; codifying it enables consistent validation and “doctor” reporting.
- Alternatives considered:
  - Only treat empty values as placeholder — rejected; would allow obviously unsafe defaults to pass.

### 7) Testing strategy for new tooling

- Decision: Use Node’s built-in `node:test` for unit tests of the env tooling modules.
- Rationale: Keeps root tooling lightweight and avoids bringing Jest into the repo root (Jest remains in `react-app/`).
- Alternatives considered:
  - Jest at repo root — rejected to avoid duplicated test stacks and config drift.

### 8) Repo-wide legacy identifier cleanup approach

- Decision: Replace hardcoded legacy-name strings with values derived from `.env` (`PROJECT_NAME`, `COMPOSE_PROJECT_NAME`, `NETWORK_NAME`, display-name variables) and/or generic wording in docs.
- Rationale: The feature requires zero hardcoded legacy identifiers in committed content while still supporting a named project.
- Alternatives considered:
  - Keep the legacy branding in docs/UI — rejected by FR-001/SC-003.

## Consolidated Decisions

- Decision: Node CLIs under `scripts/` with shared `envRules` and helper modules.
- Rationale: Matches existing ops conventions and supports Windows/macOS/Linux.

- Decision: `.env.example` is the writer template; `.env` is generated/merged into that structure.
- Rationale: Preserves documentation/comments while making setup deterministic.

- Decision: `DEPLOY_MODE=local|digitalocean` controls deploy UX and category requirements.
- Rationale: Explicit, avoids inference errors.

- Decision: Use bcrypt-compatible hashes with `$` escaping (`$$`) in `.env`.
- Rationale: Compose safety + modern hashing.
