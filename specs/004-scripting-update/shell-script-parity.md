# Shell Script Naming Parity Report

Date: 2026-02-12
Scope: scripts/bash and scripts/powershell (canonical folders)

## Summary

- Scripts with matching names in both shells: 34
- Bash-only scripts (missing PowerShell sister): 0
- PowerShell-only scripts (missing Bash sister): 0
- Legacy root-level scripts detected in scripts/: removed

## Matching Names (OK)

- bootstrap-venv
- chaos_smoke
- clean
- contract_check
- debug
- first-start
- fmt
- generate-traefik-auth
- generate_client
- health
- install-node-deps
- install-python-deps
- kill
- lint
- logs
- migrate
- perf_smoke
- rebuild
- repo_guard
- reset
- restart
- seed
- setup
- setup-hooks
- shell
- slo_smoke
- spec_kit_update
- start
- status
- stop
- sync-env
- test
- update-django-admin-allowlist
- update-flower-allowlist

## Bash-Only (Missing PowerShell Sister)

- None

## PowerShell-Only (Missing Bash Sister)

- None

## Legacy Root-Level Copies Detected (scripts/)

- Removed during parity cleanup. Canonical scripts now live in scripts/bash and scripts/powershell only.

## Proposed Actions

1. Update remaining documentation references to use scripts/bash or scripts/powershell paths.
2. Re-run guard and parity checks after doc updates.

## Notes

- This report only covers scripts/bash and scripts/powershell.
- DigitalOcean and .specify script parity are tracked separately.
