# Manual Test Results — 003-env-setup-deploy-ux

Date: 2026-02-05
OS: Windows (PowerShell)
Repo: root workspace

## Notes / Scope

- This file captures the manual commands required by the feature spec and their observed results in this workspace.
- Steps that are interactive (e.g., `npm run setup`) are listed with a placeholder for the operator to run.

## 1) Install deps

Command:

```powershell
npm install
```

Result:

- Not re-run during this capture (dependencies already present in workspace).

## 2) Guided setup (interactive)

Command:

```powershell
npm run setup
```

Result:

- Not executed in this capture (interactive prompts).

## 3) Edit `.env`

Action:

- Open `.env` and fill any remaining placeholders (especially Secrets/Admin/SMTP/TLS depending on `ENV`/`DEPLOY_MODE`).

Result:

- Not executed in this capture.

## 4) Setup completion (validation + generation)

Command (dry-run example used for capture):

```powershell
npm run setup:complete -- --dry-run --no-print
```

Observed output:

```text
setup:complete report
- dry-run: true
- no-print: true
- planned changes: 0

Validation failed (required categories):
- SMTP:
  - EMAIL_HOST: EMAIL_HOST is missing
  - EMAIL_HOST_USER: EMAIL_HOST_USER is missing
  - EMAIL_HOST_PASSWORD: EMAIL_HOST_PASSWORD is missing
- Secrets:
  - DJANGO_SECRET_KEY: DJANGO_SECRET_KEY is still a placeholder
  - JWT_SECRET: JWT_SECRET is still a placeholder
  - TOKEN_PEPPER: TOKEN_PEPPER is still a placeholder
  - OAUTH_STATE_SECRET: OAUTH_STATE_SECRET is still a placeholder
- Admin:
  - SEED_ADMIN_PASSWORD: SEED_ADMIN_PASSWORD is still a placeholder
```

Exit code:

- Non-zero (as expected with missing/placeholder required config)

## 5) Doctor readiness check

Help command:

```powershell
npm run doctor -- --help
```

Observed output:

```text
Usage: npm run doctor -- [--json] [--strict]

Read-only readiness report for the repo configuration.

Options:
  --json     Emit machine-readable JSON
  --strict   Exit nonzero if any required issue exists
  --help     Show this help
```

Strict command:

```powershell
npm run doctor -- --strict
```

Observed output:

```text
doctor: NOT READY
- ENV=production DEPLOY_MODE=digitalocean
- hardcoded identifier matches: 746
- missing: 5
- placeholders: 5
- invalid: 0
- prerequisites: 0

Recommendation: npm run setup:complete
Reason: Required configuration is incomplete or invalid
```

Exit code:

- Non-zero (as expected in strict mode when required issues exist)

## 6) Deploy (DigitalOcean)

Command:

```powershell
./digital_ocean/scripts/powershell/deploy.ps1
```

Result:

- Not executed in this capture.
