---
description: 'Tasks for End-to-End Environment Setup + Deploy UX'
---

# Tasks: End-to-End Environment Setup + Deploy UX

**Input**: Design documents from `/specs/003-env-setup-deploy-ux/`

- Required: `specs/003-env-setup-deploy-ux/spec.md`, `specs/003-env-setup-deploy-ux/plan.md`
- Available: `specs/003-env-setup-deploy-ux/research.md`, `specs/003-env-setup-deploy-ux/data-model.md`, `specs/003-env-setup-deploy-ux/contracts/`, `specs/003-env-setup-deploy-ux/quickstart.md`

**Tests**: INCLUDED (spec marks “User Scenarios & Testing” as mandatory; prompt requires regression tests).

## Format: `- [ ] [TaskID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[US#]**: User story label (US1/US2/US3) — REQUIRED only in user story phases
- Every task includes one or more exact file paths

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the task scaffolding, baseline audits, and repo hygiene needed before any story work.

- [x] T001 Inventory all legacy identifier occurrences and write results to specs/003-env-setup-deploy-ux/legacy-identifier-inventory.md ; Verify: inventory output is fully captured and grouped by area
- [x] T002 Update git hygiene ignores for local env + backups in .gitignore ; Verify: `.env` and `.env.bak.*` are ignored and no new local artifacts are tracked
- [x] T003 Add root npm scripts and Node deps for env tooling in package.json ; Verify: `npm run doctor -- --help` runs and prints usage (stub is ok until implementation)
- [x] T004 [P] Create Node tooling directories for this feature in scripts/lib/ and scripts/tests/ ; Verify: the directory structure matches the plan and is committed

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared building blocks required by all stories (parsing/writing `.env`, placeholder rules, derived identifiers, regression tests scaffold).

**Independent Foundation Check**: `npm run test:env-tools` (to be added) runs and exits 0.

- [x] T005 Implement `.env.example`-template writer/merger in scripts/lib/envFile.js ; Verify: preserves comments/order from `.env.example` while updating keys
- [x] T006 [P] Implement shared placeholder detection in scripts/lib/placeholders.js ; Verify: matches placeholders used in .env.example (e.g., `change_me`, `your_*`, `*_here`, `your_ip_address_here/32`)
- [x] T007 [P] Implement identifier derivation from `PROJECT_NAME` in scripts/lib/derived.js ; Verify: derived values are deterministic and lowercased where required
- [x] T008 [P] Implement public IPv4 detection with multi-endpoint fallback in scripts/lib/ipDetect.js ; Verify: returns valid IPv4 or a clear failure with actionable message
- [x] T009 [P] Implement secret redaction helpers in scripts/lib/redact.js ; Verify: secrets are removed from console output when `--no-print` is set
- [x] T010 Implement categories + requirement gating in scripts/envRules.js ; Verify: required categories match spec rules (Core/Secrets/Admin/Access always; TLS/SMTP required when `ENV=production` or `DEPLOY_MODE=digitalocean`)
- [x] T011 [P] Add unit tests for env tooling primitives in scripts/tests/envFile.test.js and scripts/tests/envRules.test.js ; Verify: tests fail before implementation and pass after
- [x] T012 Implement repo scan helper for hardcoded legacy identifiers in scripts/lib/legacyIdentifierScan.js ; Verify: returns file+line+match and supports excluding `node_modules/`, `build/`, and `coverage/`
- [x] T013 [P] Add unit tests for legacy identifier scan behavior in scripts/tests/legacyIdentifierScan.test.js ; Verify: scan finds a known seeded match in a fixture file and ignores excluded paths
- [x] T014 Update example configuration keys and placeholders to support setup flow in .env.example ; Verify: includes `DEPLOY_MODE`, dev-defaults opt-in, and removes default hardcoded identifiers
- [x] T015 Align existing env sync behavior with derived network identifiers in scripts/sync-env.sh ; Verify: still enforces `TRAEFIK_DOCKER_NETWORK` matches `NETWORK_NAME` without breaking macOS/Linux sed compatibility

**Checkpoint**: Foundation ready — user story implementation can begin.

---

## Phase 3: User Story 1 — Guided First-Time Setup (Priority: P1) 🎯 MVP

**Goal**: A single guided command creates/overwrites `.env` safely, derives identifiers, and prints a categorized next-steps checklist.

**Independent Test**: From a fresh clone with only `.env.example`, running `npm run setup` creates `.env` and prints next steps.

### Tests for User Story 1

- [x] T016 [P] [US1] Add tests for `PROJECT_NAME` validation + backup naming in scripts/tests/setup.validation.test.js ; Verify: rejects invalid names and creates timestamped backups
- [x] T017 [P] [US1] Add tests for derived identifiers applied during setup in scripts/tests/setup.derived.test.js ; Verify: derived keys update consistently from `PROJECT_NAME`

### Implementation for User Story 1

- [x] T018 [US1] Implement guided setup CLI in scripts/setup.js ; Verify: creates `.env` if missing, prompts before overwrite, writes backup, and prints categorized checklist
- [x] T019 [US1] Add Bash wrapper for setup in scripts/setup.sh ; Verify: `./scripts/setup.sh` runs Node CLI and exits nonzero if Node is missing
- [x] T020 [P] [US1] Add PowerShell wrapper for setup in scripts/setup.ps1 ; Verify: `./scripts/setup.ps1` runs Node CLI and works on Windows PowerShell

---

## Phase 4: User Story 2 — Setup Completion, Validation, Credential Generation (Priority: P2)

**Goal**: Validate required categories, generate missing credentials, fill allowlists from public IP, and apply safe dev defaults only when opted in.

**Independent Test**: With a partially-filled `.env`, `npm run setup:complete` reports missing/placeholder keys by category and generates credentials when appropriate.

### Tests for User Story 2

- [x] T021 [P] [US2] Add tests for category validation reporting in scripts/tests/complete-setup.validation.test.js ; Verify: missing/placeholder keys are grouped by category and required/optional is correct
- [x] T022 [P] [US2] Add tests for basic-auth generation + fallback + `$$` escaping in scripts/tests/complete-setup.auth.test.js ; Verify: generated htpasswd is bcrypt-like and safe for Compose
- [x] T023 [P] [US2] Add tests for idempotency (no net changes on rerun) in scripts/tests/complete-setup.idempotency.test.js ; Verify: rerun does not rewrite derived values or regenerate creds
- [x] T024 [P] [US2] Add tests for dev-defaults gating in scripts/tests/complete-setup.dev-defaults.test.js ; Verify: defaults apply only when `ENV=development` and user opted in

### Implementation for User Story 2

- [x] T025 [US2] Implement setup completion CLI in scripts/complete-setup.js (`--dry-run`, `--no-print`) ; Verify: exits nonzero when required placeholders remain; respects flags
- [x] T026 [US2] Implement allowlist auto-fill behavior in scripts/complete-setup.js (uses scripts/lib/ipDetect.js) ; Verify: replaces allowlist placeholders with `<public-ip>/32` and validates CIDR
- [x] T027 [US2] Implement credential generation + fallback behavior in scripts/complete-setup.js ; Verify: primary creds generated when missing and propagate to service-specific when blank/placeholder

---

## Phase 5: User Story 3 — Read-Only Doctor / Readiness Check (Priority: P3)

**Goal**: A read-only command audits readiness, supports `--json` and `--strict`, detects hardcoded identifiers, and recommends the next command.

**Independent Test**: `npm run doctor -- --json --strict` produces valid JSON and fails nonzero when required issues exist.

### Tests for User Story 3

- [x] T028 [P] [US3] Add tests for `--json` output shape per contract in scripts/tests/doctor.json.test.js ; Verify: output matches schemas in specs/003-env-setup-deploy-ux/contracts/doctor-output.schema.json
- [x] T029 [P] [US3] Add tests for strict-mode exit codes in scripts/tests/doctor.strict.test.js ; Verify: strict mode returns nonzero on any required finding

### Implementation for User Story 3

- [x] T030 [US3] Implement doctor CLI in scripts/doctor.js (`--json`, `--strict`) ; Verify: never writes files and emits findings for placeholders, prerequisites, and hardcoded identifier scan
- [x] T031 [US3] Implement recommendation logic in scripts/doctor.js ; Verify: recommends `npm run setup:complete`, local start, or digital_ocean/scripts/powershell/deploy.ps1 based on state

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Repo-wide legacy identifier removal, docs updates, and regression coverage.

- [x] T032 [P] Remove hardcoded legacy identifiers from root metadata in package.json ; Verify: legacy name does not remain in name/description and scripts still work
- [x] T033 [P] Remove hardcoded legacy identifiers from example config defaults in .env.example ; Verify: `PROJECT_NAME` is no longer set to a legacy default and derived identifiers are not hardcoded
- [x] T034 [P] Remove hardcoded legacy identifiers from operational scripts in scripts/_.sh and scripts/_.ps1 ; Verify: user-facing output and docker filters do not mention the legacy name
- [x] T035 [P] Remove hardcoded legacy identifiers from React app branding in react-app/public/index.html and react-app/src/components/Navigation.js ; Verify: UI no longer renders legacy branding by default
- [x] T036 [P] Remove hardcoded legacy identifiers from React app metadata/tests in react-app/package.json and react-app/e2e/auth.spec.ts ; Verify: tests pass after renaming/title updates
- [x] T037 [P] Remove hardcoded legacy identifiers from docs in README.md, quickstart.md, docs/_.md, and digital_ocean/_.md ; Verify: docs contain no hardcoded legacy-name strings
- [x] T038 [P] Remove hardcoded legacy identifiers from governance docs in .specify/memory/constitution.md ; Verify: constitution no longer hardcodes the legacy name
- [x] T039 Add regression test suite for required scenarios in scripts/tests/regression.test.js ; Verify: covers dev vs prod, DigitalOcean mode gating, auth fallback, bcrypt `$$`, idempotency, and legacy identifier scan
- [x] T040 Update user-facing onboarding docs for the new flow in README.md ; Verify: includes `npm install`, `npm run setup`, `npm run setup:complete`, `npm run doctor`, and troubleshooting guidance
- [x] T041 Add final “manual test” checklist and capture results in specs/003-env-setup-deploy-ux/manual-test-results.md ; Verify: includes the exact commands: `npm install`, `npm run setup`, edit `.env`, `npm run setup:complete`, `npm run doctor`, deploy
- [x] T042 Final verification sweep: confirm zero legacy identifier occurrences via `git grep` and record command output in specs/003-env-setup-deploy-ux/legacy-identifier-final-grep.txt ; Verify: grep output is empty and committed

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Phase 1; BLOCKS user stories
- **User Stories (Phases 3–5)**: depend on Phase 2; can proceed in priority order
- **Polish (Phase 6)**: depends on completing the desired stories (usually at least US1+US2)

### User Story Dependencies (intended)

- **US1 (P1)**: depends only on Foundational
- **US2 (P2)**: depends on Foundational and assumes US1 created `.env` (but should still handle “.env exists” state)
- **US3 (P3)**: depends only on Foundational (read-only), but becomes more valuable after US1/US2 exist

Dependency graph:

- Phase 1 → Phase 2 → {US1, US2, US3} → Phase 6

---

## Parallel Execution Examples

### User Story 1

- Parallel tests:
  - T016 (scripts/tests/setup.validation.test.js)
  - T017 (scripts/tests/setup.derived.test.js)

### User Story 2

- Parallel tests:
  - T021 (scripts/tests/complete-setup.validation.test.js)
  - T022 (scripts/tests/complete-setup.auth.test.js)
  - T023 (scripts/tests/complete-setup.idempotency.test.js)
  - T024 (scripts/tests/complete-setup.dev-defaults.test.js)

### User Story 3

- Parallel tests:
  - T028 (scripts/tests/doctor.json.test.js)
  - T029 (scripts/tests/doctor.strict.test.js)

---

## Implementation Strategy

### Suggested MVP scope

- **MVP = US1 only** (Phase 1 + Phase 2 + Phase 3)
- Validate onboarding success before implementing generation/doctor features.

### Incremental delivery

1. Phase 1 + Phase 2 → foundation
2. US1 → guided setup
3. US2 → completion + generation + validation
4. US3 → doctor readiness
5. Phase 6 → repo cleanup + docs + regression suite + manual test capture
