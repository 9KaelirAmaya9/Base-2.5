# Quickstart: Scripting Update (Shell Parity + Script Routing)

## Prerequisites

- Windows PowerShell 7+ or Bash on Mac/Linux
- Node.js 18+ (for guard and make-like interface)
- Python 3.12 (for existing repo scripts)

## Validate Guard and Parity (Local)

## Parity Verification Checklist

Use these commands to confirm every script in `scripts/bash` has a matching name in `scripts/powershell` (and vice versa). No output means parity is clean.

### PowerShell (Windows)

```powershell
$bash = Get-ChildItem scripts/bash -Filter *.sh | ForEach-Object { $_.BaseName } | Sort-Object -Unique
$ps = Get-ChildItem scripts/powershell -Filter *.ps1 | ForEach-Object { $_.BaseName } | Sort-Object -Unique
Compare-Object $bash $ps
```

### Bash (Mac/Linux)

```bash
comm -3 <(ls scripts/bash/*.sh | xargs -n1 basename | sed 's/\.sh$//' | sort) <(ls scripts/powershell/*.ps1 | xargs -n1 basename | sed 's/\.ps1$//' | sort)
```

### PowerShell (Windows)

1. Run the guard:
   - `node scripts/guard-shell-parity.js`
2. Run primary commands via PowerShell entrypoints:
   - `./scripts/powershell/first-start.ps1`
   - `./scripts/powershell/start.ps1`
   - `./scripts/powershell/logs.ps1`
   - `./scripts/powershell/test.ps1`
   - `./scripts/powershell/stop.ps1`

### Bash (Mac/Linux)

1. Run the guard:
   - `node scripts/guard-shell-parity.js`
2. Run primary commands via Bash entrypoints:
   - `./scripts/bash/first-start.sh`
   - `./scripts/bash/start.sh`
   - `./scripts/bash/logs.sh`
   - `./scripts/bash/test.sh`
   - `./scripts/bash/stop.sh`

## DigitalOcean MVP (Bash)

- Run the MVP deploy/test path using the Bash entrypoints identified in the command matrix and the DigitalOcean quickstart. Ensure exit codes and log structure match the PowerShell flow.

## Make-like Interface

- Use `scripts/make/make.sh` on Mac/Linux and `scripts/make/make.ps1` on Windows for the unified command interface once parity is achieved.
