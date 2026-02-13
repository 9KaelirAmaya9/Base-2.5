# Research: Scripting Update (Shell Parity + Script Routing)

## Decision 1: Guard implementation language

**Decision**: Implement the cross-shell invocation guard as a Node.js script at `scripts/guard-shell-parity.js`.
**Rationale**: The repo already uses Node.js for repo tooling (`scripts/*.js`) and runs `node --test` for script tests, so Node provides a familiar runtime and easy cross-platform execution in CI.
**Alternatives considered**: Python utility (consistent with other scripts), shell-based grep (simpler but higher false positive risk).

## Decision 2: Remote payload allowlist format and location

**Decision**: Store the allowlist at `scripts/allowlists/remote-linux-payloads.txt` with one path or glob per line and `#` inline comments.
**Rationale**: A simple line-based format is readable, versionable, and easy to parse in the guard without extra dependencies.
**Alternatives considered**: JSON/YAML allowlist (more structure but more overhead), embedding allowlist in the guard (less maintainable).

## Decision 3: Remote execution helper scope

**Decision**: Treat remote Linux payload execution as allowed only when invoked through the DigitalOcean orchestration helpers: `digital_ocean/scripts/python/orchestrate_deploy.py` and `digital_ocean/scripts/powershell/deploy.ps1`.
**Rationale**: These are the canonical DigitalOcean deployment paths already used for remote SSH and cloud-init operations; constraining to them limits accidental cross-shell execution locally.
**Alternatives considered**: Allow any SSH caller (too broad), add a new generic remote-exec wrapper immediately (more change than needed for guard-first).

## Decision 4: Script reorganization approach

**Decision**: Reorganize scripts into canonical folders (`scripts/bash/`, `scripts/powershell/`, `scripts/python/`, `scripts/make/`, plus DigitalOcean and Spec-Kit subfolders) with optional same-shell shims during migration to keep CI green.
**Rationale**: Matches the required structure and keeps changes incremental while avoiding cross-shell regressions.
**Alternatives considered**: Big-bang move without shims (higher CI break risk), partial reorg (does not satisfy separation goals).

## Decision 5: Make-like interface source of truth

**Decision**: Use `scripts/make/make.js` as the shared behavior source with thin wrappers `scripts/make/make.sh` and `scripts/make/make.ps1`.
**Rationale**: Single behavior source ensures parity across platforms while keeping shell-specific wrappers minimal.
**Alternatives considered**: Separate Bash/PowerShell implementations (higher drift risk), GNU Make only (not cross-platform).
