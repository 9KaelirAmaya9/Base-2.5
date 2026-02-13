# Quickstart: Scripting Update (Shell Parity + Script Routing)

## Prerequisites

- Windows PowerShell 7+ or Bash on Mac/Linux
- Node.js 18+ (for guard and make-like interface)
- Python 3.12 (for existing repo scripts)

## Validate Guard and Parity (Local)

### PowerShell (Windows)

1. Run the guard:
   - `node scripts/guard-shell-parity.js`
2. Run primary commands via PowerShell entrypoints:
   - `./scripts/first-start.ps1`
   - `./scripts/start.ps1`
   - `./scripts/logs.ps1`
   - `./scripts/test.ps1`
   - `./scripts/stop.ps1`

### Bash (Mac/Linux)

1. Run the guard:
   - `node scripts/guard-shell-parity.js`
2. Run primary commands via Bash entrypoints:
   - `./scripts/first-start.sh`
   - `./scripts/start.sh`
   - `./scripts/logs.sh`
   - `./scripts/test.sh`
   - `./scripts/stop.sh`

## DigitalOcean MVP (Bash)

- Run the MVP deploy/test path using the Bash entrypoints identified in the command matrix and the DigitalOcean quickstart. Ensure exit codes and log structure match the PowerShell flow.

## Make-like Interface

- Use `scripts/make/make.sh` on Mac/Linux and `scripts/make/make.ps1` on Windows for the unified command interface once parity is achieved.
