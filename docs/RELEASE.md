# Release Process

## Overview

This document describes the lightweight release process for the stack.

## Steps

1. Ensure `main` is green in CI (backend, frontend, security)
2. Bump versions if needed (app or docs)
3. Tag the release: `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push --tags`
4. Create GitHub Release with changelog highlights
5. Run deploy gate:
   - `powershell -File digital_ocean/scripts/powershell/deploy.ps1 -UpdateOnly -AllTests -Timestamped`
6. Verify post-deploy report success
7. Update `CHANGELOG.md` with notable changes

## Mobile regression check (required)

Before tagging a release (or immediately after the deploy gate), verify:

- iOS Safari: home page renders, login page renders, no white screen
- Android Chrome: same checks
- Dark mode: toggle theme (or system dark mode), verify the UI renders and stays navigable

If anything fails, capture:

- Browser console logs (CSP violations, JS exceptions)
- Network errors (blocked scripts, failed OAuth calls)

## Rollback

- Use the rollback hook in deploy logs if enabled
- Alternatively, revert and re-run the deploy gate

## Notes

- SBOM and security scans run in CI
- Coverage thresholds enforced (backend, frontend)
- Storybook builds in CI (see workflow)
