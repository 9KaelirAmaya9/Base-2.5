# Implementation Plan: End-to-End Environment Setup + Deploy UX

**Branch**: `[003-env-setup-deploy-ux]` | **Date**: 2026-02-05 | **Spec**: [specs/003-env-setup-deploy-ux/spec.md](spec.md)
**Input**: Feature specification from `/specs/003-env-setup-deploy-ux/spec.md`

## Summary

Deliver a cross-platform, guided environment setup flow powered by Node.js scripts:

- Repo-wide removal of hardcoded legacy identifiers, replaced by values derived from a user-provided `PROJECT_NAME`.
- A shared `envRules` module that defines placeholder detection, category requirements, and deploy-mode gating.
- Three CLIs: `setup` (interactive, creates/updates `.env`), `setup:complete` (validates, generates credentials, applies safe dev defaults, supports dry-run/no-print), and `doctor` (read-only readiness report with `--json/--strict`).

Design prioritizes:

- Constitution compliance (compose-first, single deploy entrypoint, observability, staging TLS policy).
- Safety (backups, no secret logging, idempotence).
- Windows/macOS/Linux support (Node scripts; existing Bash/PowerShell wrappers remain supported).

Phase 0/1 outputs for this plan:

- Research: [specs/003-env-setup-deploy-ux/research.md](research.md)
- Data model: [specs/003-env-setup-deploy-ux/data-model.md](data-model.md)
- Contracts: [specs/003-env-setup-deploy-ux/contracts/](contracts/)
- Quickstart: [specs/003-env-setup-deploy-ux/quickstart.md](quickstart.md)

## Technical Context

Language: JavaScript (Node.js tooling) + shell scripts (Bash/PowerShell)
Language/Version: JavaScript (Node.js >= 24.13.1), Bash, PowerShell 5.1+, Python (existing services/tools)

**Language**: JavaScript (Node.js tooling)  
**Language/Version**:

- Node.js >= 24.13.1 (root `package.json` engines)
- Bash (existing `scripts/*.sh` utilities)
- PowerShell 5.1+ (existing `scripts/*.ps1` wrappers + deploy entrypoint)
- Python (already used for API/Django/DigitalOcean automation)

**Primary Dependencies**:

- Docker Engine + Docker Compose v2
- Node standard library for file IO, crypto, and child processes
- New root Node deps (planned): `inquirer` (prompts), `bcryptjs` (portable hashing), `chalk` (optional output styling)

**Storage**: Files (`.env`, backups); no DB schema changes.

**Testing**:

- Node built-in `node:test` for the new env tooling modules
- Existing Jest/RTL and Playwright remain unchanged

**Target Platform**: Windows (PowerShell; optionally WSL/Git Bash), macOS, Linux.

**Project Type**: Monorepo (compose + Python services + React app) with root operational scripts.

**Performance Goals**:

- `setup` interactive path completes in < 60s (mostly user input)
- `doctor` completes in < 3s on typical machines (network calls only for public-IP detection if enabled)

**Constraints**:

- `doctor` must be read-only
- No secrets printed when `--no-print` is set
- Always create timestamped backups before overwriting `.env`
- Respect Single-entrypoint ops: cloud deploy guidance must point to `digital_ocean/scripts/powershell/deploy.ps1`

**Scale/Scope**:

- ~200 config keys in `.env.example` spanning local runtime and DigitalOcean deploy settings
- Repo-wide identifier cleanup includes docs, scripts, compose configs, React branding strings, and package metadata

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- **TDD by default**: PASS
  - Plan includes `node:test` coverage for placeholder detection, env parsing, derived identifiers, and `$` escaping.
- **Environment parity**: PASS
  - The feature standardizes `.env` used by compose; does not introduce a separate “dev-only” topology.
- **Container-first, Compose-first**: PASS
  - Setup flow produces a correct `.env` for `development.docker.yml`; existing `scripts/start.sh` remains the primary local entrypoint.
- **Single-entrypoint operations**: PASS
  - Cloud deploy guidance and doctor recommendations point to `digital_ocean/scripts/powershell/deploy.ps1` (no new deploy entrypoints).
- **Observability is a feature**: PASS
  - The CLIs will produce a non-sensitive summary; design allows later integration with `local_run_logs/` artifacts.
- **TLS staging-only policy**: PASS
  - No changes to Traefik staging-first policy; setup scripts validate but do not weaken TLS defaults.

## Project Structure

### Documentation (this feature)

```text
specs/003-env-setup-deploy-ux/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md                 # Phase 2 output (/speckit.tasks); not created here
```

### Source Code (repository root)

```text
scripts/
├── setup.js                 # New (interactive setup)
├── complete-setup.js        # New (validation + generation)
├── doctor.js                # New (read-only readiness)
└── envRules.js              # New (shared rules)

scripts/lib/
├── envFile.js               # Parse/merge/write .env using .env.example as template
├── derived.js               # Derive identifiers from PROJECT_NAME
├── placeholders.js          # Shared placeholder detection
├── ipDetect.js              # Multi-endpoint public IPv4 detection + validation
├── redact.js                # Secret redaction helpers
└── legacyIdentifierScan.js  # Repo scan for hardcoded legacy identifiers (token list provided at runtime)

scripts/tests/
├── placeholders.test.js
├── envRules.test.js
├── derived.test.js
└── envFile.test.js
```

**Structure Decision**: Place Node-based setup tooling under `scripts/` to match existing operational helpers (Bash/PowerShell). The new tooling is cross-platform by default (Node), while existing platform wrappers remain available.

## Phase 0 — Research (completed)

See [specs/003-env-setup-deploy-ux/research.md](research.md) for decisions and alternatives, including:

- `.env` rewrite strategy (use `.env.example` as authoritative template)
- Choice of hashing library and `$`-escaping for compose
- Deploy-mode representation in `.env` (`DEPLOY_MODE=local|digitalocean`)
- Placeholder rules and category mapping strategy

## Phase 1 — Design (completed)

### `envRules` module

- Exports:
  - `CATEGORIES` with keys grouped into Core/Secrets/Admin/Access/TLS/SMTP/OAuth (optional)
  - `isPlaceholder(value, key?)` shared predicate
  - `requiredCategories({ env, deployMode })` logic
  - `validateEnv(envMap, options)` returning categorized findings (missing, placeholder, invalid)
- Treat empty and known placeholder patterns as unfinished (`change_me`, `your_*`, `*_here`, `your_ip_address_here/32`, etc.).

### `setup.js` (interactive)

- Reads `.env.example`; requires it exists.
- Creates `.env` if missing; if present, prompts before overwrite and writes timestamped backup.
- Prompts:
  - `PROJECT_NAME` (validated: lowercase letters, digits, hyphen)
  - `WEBSITE_DOMAIN`
  - `ENV` (development|staging|production)
  - `DEPLOY_MODE` (local|digitalocean)
  - opt-in for “apply safe dev defaults” (development only)
- Derives and sets:
  - `COMPOSE_PROJECT_NAME`, `NETWORK_NAME`, cookie names, JWT issuer/audience, DO app/registry names (where appropriate)
- Writes `.env` using `.env.example` as the template and the merged values.

### `complete-setup.js`

- Supports `--dry-run` (no file writes), `--no-print` (no secrets printed).
- Loads `.env`, validates required categories via `envRules`.
- Generates credentials when missing/placeholder:
  - Primary basic-auth + service-specific with fallback behavior
  - Hash using bcrypt-compatible format; ensure `.env` stores escaped `$` as `$$`.
- Detects public IPv4 and writes allowlists (CIDR `/32`) where placeholders remain.
- Applies safe dev defaults only when `ENV=development` and user opted in.
- Idempotent: re-running with same inputs yields stable results.

### `doctor.js`

- Read-only: never writes files.
- Reports readiness across:
  - placeholder findings per category
  - hardcoded legacy identifier scan with file+line references
  - derived identifier consistency checks (project name vs compose/network/cookies)
  - allowlist correctness (valid CIDR, not placeholder)
  - prerequisite checks (Node, Docker, Compose)
- Flags:
  - `--json` emits a stable JSON report (see schema in `contracts/doctor-output.schema.json`)
  - `--strict` fails nonzero if any required finding exists
- Ends with a recommended next command: `npm run setup:complete`, local start, or `digital_ocean/scripts/powershell/deploy.ps1`.

## Phase 1 Outputs

- [specs/003-env-setup-deploy-ux/data-model.md](data-model.md)
- [specs/003-env-setup-deploy-ux/contracts/](contracts/)
- [specs/003-env-setup-deploy-ux/quickstart.md](quickstart.md)

## Phase 2 — Implementation Planning (tasks to be created by `/speckit.tasks`)

Planned task themes (detailed task IDs will live in `tasks.md`):

1. Add Node tooling dependencies + `npm run setup|setup:complete|doctor` scripts.
2. Implement `envRules` + helpers with unit tests.
3. Implement `setup.js` + `complete-setup.js` + `doctor.js` with unit tests.
4. Repo-wide legacy identifier removal:
   - `.env.example` defaults and docs
   - `scripts/*.sh` and `scripts/*.ps1` user-facing output strings and docker filters
   - React branding strings (`react-app/*`) where required
5. Git hygiene:
   - ignore backups (e.g., `.env.bak.*`) and ensure `.env` is untracked and ignored
6. Documentation updates to root README and quickstart.

**Platform test matrix** (minimum): Windows PowerShell, macOS Bash/Zsh, Linux Bash.
