# Quickstart — End-to-End Environment Setup + Deploy UX

See the feature specification at `specs/003-env-setup-deploy-ux/spec.md` and implementation plan at `specs/003-env-setup-deploy-ux/plan.md`.

## Prerequisites

- Node.js 18+ (repo root `package.json` engines)
- Docker Engine + Docker Compose v2
- Windows users:
  - PowerShell is supported
  - Git Bash/WSL is recommended for existing `scripts/*.sh`

## Install

From repo root:

```bash
npm install
```

React app dependencies remain separate:

```bash
cd react-app
npm install
```

## Guided setup

### 1) Create/refresh `.env`

```bash
npm run setup
```

What it does:

- Requires `.env.example`.
- Creates `.env` if missing.
- If `.env` exists, prompts before overwrite and creates a timestamped backup.
- Sets derived identifiers from `PROJECT_NAME`.

### 2) Validate + generate missing credentials

```bash
npm run setup:complete
```

Recommended options:

- `--dry-run`: validate and show actions without writing files
- `--no-print`: do not print any secrets

### 3) Read-only readiness check

```bash
npm run doctor
```

Recommended options:

- `--json`: machine-readable report
- `--strict`: nonzero exit if any required issue exists

## Start locally

Bash:

```bash
./scripts/start.sh --build
```

Windows PowerShell:

```powershell
./scripts/start.ps1
```

## Cloud deploy (DigitalOcean)

When `DEPLOY_MODE=digitalocean`, follow the constitution’s single-entrypoint ops rule:

```powershell
./digital_ocean/scripts/powershell/deploy.ps1
```

## Verify

- `npm run doctor --strict` returns exit code 0 when ready.
- No hardcoded legacy identifier strings remain in committed source/config/docs after cleanup work is applied.
