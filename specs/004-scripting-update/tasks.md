---
description: 'Tasks for 004-scripting-update'
---

# Tasks: Scripting Update (Shell Parity + Script Routing)

**Input**: Design documents from `specs/004-scripting-update/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Priority: P1 | Title: Inventory primary commands and fill matrix | Why: Establish the source of truth before implementation | Scope: Audit README/docs, Makefile, CI, scripts, and update the Primary Command Matrix in specs/004-scripting-update/spec.md | Output files: specs/004-scripting-update/spec.md | Acceptance criteria: Matrix rows contain concrete Bash/PowerShell entrypoints, flags, exit codes, and notes | Validation: `git diff -- specs/004-scripting-update/spec.md` | Dependencies: none
- [x] T027 [P] Priority: P1 | Title: Add command matrix validation check | Why: Detect drift between declared and discovered entrypoints | Scope: Create a validation script and wire it to CI to fail when matrix rows are missing parity | Output files: scripts/validate-command-matrix.js, .github/workflows/\*.yml | Acceptance criteria: CI fails when a matrix row lacks Bash or PowerShell entrypoints (supports FR-001/FR-008 parity enforcement) | Validation: `node scripts/validate-command-matrix.js` | Dependencies: T001
- [x] T002 [P] Priority: P1 | Title: Create script relocation map | Why: Track old to new paths to keep CI green during reorg | Scope: Add a mapping file listing old paths, new paths, and callers | Output files: specs/004-scripting-update/script-relocation-map.md | Acceptance criteria: Each moved script has an entry with callers | Validation: `git diff -- specs/004-scripting-update/script-relocation-map.md` | Dependencies: T001

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Priority: P1 | Title: Create canonical script folders and initial shims | Why: Enable incremental moves without breaking CI | Scope: Add scripts/bash, scripts/powershell, scripts/python, scripts/make, digital*ocean/scripts/{bash,powershell,python}, .specify/scripts/{bash,powershell}; add same-shell shims at old primary entrypoints in scripts/ | Output files: scripts/bash/, scripts/powershell/, scripts/python/, scripts/make/, digital_ocean/scripts/*, .specify/scripts/_, scripts/_.ps1, scripts/\_.sh | Acceptance criteria: Shims call same-shell targets and guard passes on clean repo | Validation: `node scripts/guard-shell-parity.js` | Dependencies: T001
- [x] T004 [P] Priority: P1 | Title: Move Python utilities to canonical folders | Why: Align repo structure with language-based separation | Scope: Move repo Python scripts into scripts/python and DO Python scripts into digital*ocean/scripts/python; add Bash and PowerShell wrapper entrypoints for each Python utility; update imports and callers | Output files: scripts/python/*.py, digital*ocean/scripts/python/*.py, scripts/bash/_.sh, scripts/powershell/_.ps1, digital*ocean/scripts/bash/*.sh, digital*ocean/scripts/powershell/*.ps1, updated callers | Acceptance criteria: Python utilities run from new locations via Bash and PowerShell wrappers and imports resolve | Validation: `python -m pytest digital_ocean/tests -k "test_deploy or test_exec"` | Dependencies: T003
- [x] T005 [P] Priority: P1 | Title: Add remote payload allowlist | Why: Provide explicit guardrail for remote Linux payloads | Scope: Create allowlist with entries for DigitalOcean payloads | Output files: scripts/allowlists/remote-linux-payloads.txt | Acceptance criteria: Allowlist contains documented remote payload paths/patterns and comments | Validation: `git diff -- scripts/allowlists/remote-linux-payloads.txt` | Dependencies: T003
- [x] T006 [P] Priority: P1 | Title: Add guard tests | Why: Enforce cross-shell rules with test-first coverage | Scope: Add node tests and fixtures for cross-shell detection and allowlist behavior | Output files: scripts/tests/guard-shell-parity.test.js, scripts/tests/fixtures/cross-shell/\* | Acceptance criteria: Tests fail before guard implementation and cover PS->sh, sh->PS, and allowlist cases | Validation: `node --test scripts/tests/guard-shell-parity.test.js` | Dependencies: T005
- [x] T007 Priority: P1 | Title: Implement guard script | Why: Block local cross-shell invocations | Scope: Implement scripts/guard-shell-parity.js to scan scripts/, .specify/scripts/, digital_ocean/scripts/ and report violations | Output files: scripts/guard-shell-parity.js | Acceptance criteria: Guard reports file:line with violation type and exits non-zero on violation | Validation: `node scripts/guard-shell-parity.js` | Dependencies: T006
- [x] T008 Priority: P1 | Title: Wire guard into CI | Why: Enforce guard on every change | Scope: Add guard command to CI workflows | Output files: .github/workflows/\*.yml | Acceptance criteria: CI includes a step running node scripts/guard-shell-parity.js | Validation: `rg "guard-shell-parity" .github/workflows` | Dependencies: T007
- [x] T009 Priority: P1 | Title: Verify guard fail/pass behavior | Why: Ensure guard blocks violations and allows clean state | Scope: Add or adjust fixtures to force a violation and ensure passing case | Output files: scripts/tests/fixtures/cross-shell/\*, scripts/tests/guard-shell-parity.test.js | Acceptance criteria: Guard fails on violation fixture and passes on clean fixture | Validation: `node --test scripts/tests/guard-shell-parity.test.js` | Dependencies: T007
- [x] T028 [P] Priority: P1 | Title: Validate guard runtime performance | Why: Meet SC-003 timing requirement | Scope: Add a timing check for guard runtime in CI or local validation | Output files: .github/workflows/\*.yml, scripts/tests/guard-shell-parity.test.js | Acceptance criteria: Guard completes under 30 seconds on CI | Validation: `pwsh -Command "$t=Measure-Command { node scripts/guard-shell-parity.js }; if ($t.TotalSeconds -gt 30) { throw 'Guard exceeded 30s' }"` | Dependencies: T007

---

## Phase 3: User Story 1 - Windows PowerShell-only workflow (Priority: P1)

**Goal**: PowerShell-only workflow supports all primary commands without Bash.
**Independent Test**: Run all primary PowerShell entrypoints on Windows with no Bash installed.

- [x] T010 [P] [US1] Priority: P1 | Title: Move PowerShell entrypoints | Why: Enforce PowerShell-only local routing | Scope: Move scripts/_.ps1 into scripts/powershell/ and update PowerShell callers and shims | Output files: scripts/powershell/_.ps1, scripts/\*.ps1, docs/ | Acceptance criteria: PowerShell entrypoints resolve to scripts/powershell and no PS script calls .sh locally | Validation: `pwsh -File scripts/powershell/start.ps1 -Help` | Dependencies: T003, T007
- [x] T011 [US1] Priority: P1 | Title: Normalize PowerShell flags and exit codes | Why: Match parity requirements | Scope: Align flags/options/help output and exit codes with command matrix | Output files: scripts/powershell/\*.ps1 | Acceptance criteria: PowerShell flags and exit codes match the matrix | Validation: `pwsh -File scripts/powershell/start.ps1 -Help` | Dependencies: T010, T001
- [x] T012 [US1] Priority: P1 | Title: Validate PowerShell workflow | Why: Confirm Windows-only path is functional | Scope: Run primary commands via PowerShell entrypoints | Output files: none | Acceptance criteria: setup/start/logs/test/stop succeed and exit codes match | Validation: `pwsh -File scripts/powershell/test.ps1` | Dependencies: T011

---

## Phase 4: User Story 2 - Mac/Linux Bash-only workflow (Priority: P1)

**Goal**: Bash-only workflow supports all primary commands without PowerShell.
**Independent Test**: Run all primary Bash entrypoints on Mac/Linux with no PowerShell installed.

- [x] T013 [P] [US2] Priority: P1 | Title: Move Bash entrypoints | Why: Enforce Bash-only local routing | Scope: Move scripts/_.sh into scripts/bash/ and update Bash callers and shims (including Makefile targets) | Output files: scripts/bash/_.sh, scripts/\*.sh, Makefile, docs/ | Acceptance criteria: Bash entrypoints resolve to scripts/bash and no Bash script calls .ps1 locally | Validation: `bash scripts/bash/start.sh --help` | Dependencies: T003, T007
- [x] T014 [US2] Priority: P1 | Title: Normalize Bash flags and exit codes | Why: Match parity requirements | Scope: Align flags/options/help output and exit codes with command matrix | Output files: scripts/bash/\*.sh | Acceptance criteria: Bash flags and exit codes match the matrix | Validation: `bash scripts/bash/start.sh --help` | Dependencies: T013, T001
- [x] T015 [US2] Priority: P1 | Title: Validate Bash workflow | Why: Confirm Mac/Linux-only path is functional | Scope: Run primary commands via Bash entrypoints | Output files: none | Acceptance criteria: setup/start/logs/test/stop succeed and exit codes match | Validation: `bash scripts/bash/test.sh --compose-file development.docker.yml --env-file .env` | Dependencies: T014

---

## Phase 5: User Story 3 - Spec-Kit parity (Priority: P1)

**Goal**: Spec-Kit scripts stay within their shell and validate configuration.
**Independent Test**: Run Spec-Kit scripts in each shell and confirm guard passes.

- [x] T016 [P] [US3] Priority: P1 | Title: Audit Spec-Kit scripts for shell-only routing | Why: Prevent cross-shell violations in core tooling | Scope: Update .specify/scripts/bash and .specify/scripts/powershell to call only same-shell or shared implementations | Output files: .specify/scripts/bash/_.sh, .specify/scripts/powershell/_.ps1 | Acceptance criteria: No local cross-shell calls remain in Spec-Kit scripts | Validation: `node scripts/guard-shell-parity.js` | Dependencies: T007
- [x] T017 [US3] Priority: P1 | Title: Add Spec-Kit configuration validation | Why: Ensure required config inputs are checked consistently | Scope: Add or update validation in .specify/scripts/_ (bash and PowerShell) | Output files: .specify/scripts/bash/_.sh, .specify/scripts/powershell/\*.ps1 | Acceptance criteria: Missing config causes non-zero exit with clear message | Validation: `pwsh -File .specify/scripts/powershell/check-prerequisites.ps1 -Json` | Dependencies: T016

---

## Phase 5.5: Shell Script Naming Parity (Priority: P1)

**Goal**: Every Bash script has a PowerShell sister (and vice versa) with identical naming and equivalent behavior, with no stale copies left in old locations.

- [x] T029 [P] Priority: P1 | Title: Audit shell script parity | Why: Identify missing counterparts and stale duplicates | Scope: Inventory scripts/bash and scripts/powershell, list mismatches and stale legacy copies | Output files: specs/004-scripting-update/shell-script-parity.md | Acceptance criteria: Report lists scripts missing counterparts and any duplicates outside canonical folders | Validation: `rg "scripts/bash|scripts/powershell" specs/004-scripting-update/shell-script-parity.md` | Dependencies: T013, T010
- [x] T030 Priority: P1 | Title: Implement shell script parity fixes | Why: Enforce naming symmetry and canonical locations | Scope: Add missing sister scripts or consolidate shared implementations; delete stale duplicates from legacy paths | Output files: scripts/bash/\*.sh, scripts/powershell/\*.ps1, removed legacy scripts | Acceptance criteria: Every script in scripts/bash has a matching scripts/powershell name and vice versa (except documented exemptions) | Validation: `node scripts/guard-shell-parity.js` | Dependencies: T029
- [x] T031 Priority: P1 | Title: Add parity verification checklist | Why: Prevent drift after parity fixes | Scope: Add a validation checklist or script to confirm Bash/PowerShell naming parity | Output files: scripts/tests/ or specs/004-scripting-update/quickstart.md | Acceptance criteria: Parity validation can be re-run and documented | Validation: `git diff -- specs/004-scripting-update/quickstart.md` | Dependencies: T030

---

## Phase 6: User Story 4 - DigitalOcean MVP parity (Priority: P2)

**Goal**: Bash deploy/test mirrors PowerShell happy-path options for DigitalOcean.
**Independent Test**: Run Bash deploy/test for the documented MVP option surface.

- [x] T018 [P] [US4] Priority: P2 | Title: Define DigitalOcean MVP option surface | Why: Scope parity to the documented happy path | Scope: Document MVP flags and deferred options in digital_ocean/quickstart.md and digital_ocean/README.md | Output files: digital_ocean/quickstart.md, digital_ocean/README.md | Acceptance criteria: MVP options are explicitly listed and mapped to PowerShell flags | Validation: `git diff -- digital_ocean/quickstart.md digital_ocean/README.md` | Dependencies: T001
- [x] T019 [P] [US4] Priority: P2 | Title: Implement Bash deploy/test entrypoints | Why: Provide Mac/Linux deploy/test path | Scope: Add digital_ocean/scripts/bash/deploy.sh and test.sh (and helpers as needed) as wrappers that invoke digital_ocean/orchestrate_deploy.py and align with PowerShell behavior | Output files: digital_ocean/scripts/bash/\*.sh | Acceptance criteria: Bash scripts support MVP flags, route through orchestrate_deploy.py, and exit codes match | Validation: `bash digital_ocean/scripts/bash/deploy.sh --help` | Dependencies: T018, T007
- [x] T020 [US4] Priority: P2 | Title: Align DO logs and exit codes | Why: Ensure parity between Bash and PowerShell flows | Scope: Normalize log structure, artifact paths, and exit codes between Bash and PowerShell deploy/test routed through orchestrate*deploy.py | Output files: digital_ocean/scripts/bash/*.sh, digital*ocean/scripts/powershell/*.ps1 | Acceptance criteria: DO Bash and PowerShell output semantics match for success/failure | Validation: `bash digital_ocean/scripts/bash/test.sh --help` | Dependencies: T019

---

## Phase 7: User Story 5 - Make-like commands (Priority: P3)

**Goal**: Provide a cross-platform make-like command interface.
**Independent Test**: Run make-like commands on Windows and Mac/Linux for primary operations.

- [x] T021 [P] [US5] Priority: P3 | Title: Implement shared make CLI | Why: Single behavior source for all platforms | Scope: Create scripts/make/make.js with command routing to matrix entrypoints | Output files: scripts/make/make.js | Acceptance criteria: make.js supports setup/start/stop/restart/logs/test/deploy with help output | Validation: `node scripts/make/make.js --help` | Dependencies: T001, T011, T014
- [x] T022 [P] [US5] Priority: P3 | Title: Add make wrappers | Why: Provide shell-native entrypoints | Scope: Add scripts/make/make.sh and scripts/make/make.ps1 wrappers | Output files: scripts/make/make.sh, scripts/make/make.ps1 | Acceptance criteria: Wrappers delegate to make.js with correct exit codes | Validation: `bash scripts/make/make.sh --help` | Dependencies: T021
- [x] T023 [US5] Priority: P3 | Title: Optionally delegate Makefile to make wrappers | Why: Unify behavior across platforms | Scope: Update Makefile targets to call scripts/make wrappers where safe | Output files: Makefile | Acceptance criteria: Makefile targets still work with same flags and outputs | Validation: `make logs` | Dependencies: T022

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T024 [P] Priority: P1 | Title: Remove shims and stale path references | Why: Finalize reorg and prevent drift | Scope: Remove temporary shims and update references in docs, CI, and package.json scripts | Output files: scripts/_.ps1, scripts/_.sh, docs/_, .github/workflows/_, package.json | Acceptance criteria: No references to old script paths remain | Validation: `rg "scripts/[^/]+\.sh|scripts/[^/]+\.ps1" docs .github/workflows package.json` | Dependencies: T010, T013, T020, T022
- [x] T025 [P] Priority: P1 | Title: Update documentation and quickstart | Why: Keep user-facing guidance accurate | Scope: Update README, docs/DEVELOPMENT.md, docs/GOLDEN_PATH.md, digital_ocean/README.md, digital_ocean/quickstart.md, specs/004-scripting-update/quickstart.md | Output files: README.md, docs/DEVELOPMENT.md, docs/GOLDEN_PATH.md, digital_ocean/README.md, digital_ocean/quickstart.md, specs/004-scripting-update/quickstart.md | Acceptance criteria: Docs reference new script paths and make-like interface | Validation: `git diff -- README.md docs/DEVELOPMENT.md docs/GOLDEN_PATH.md digital_ocean/README.md digital_ocean/quickstart.md specs/004-scripting-update/quickstart.md` | Dependencies: T024
- [x] T026 Priority: P1 | Title: Final verification checklist | Why: Confirm DoD before merge | Scope: Run guard, PS workflow, Bash workflow, Spec-Kit validation, DO MVP, and CI check | Output files: none | Acceptance criteria: All verification commands succeed with expected exit codes | Validation: `node scripts/guard-shell-parity.js` | Dependencies: T012, T015, T017, T020, T023, T025

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (Phase 1): No dependencies
- Foundational (Phase 2): Depends on Setup completion; blocks all user stories
- User Stories (Phases 3-7): Depend on Foundational completion
- Polish (Phase 8): Depends on all user stories

### User Story Dependencies

- US1 (P1): Depends on Foundational tasks T003-T009
- US2 (P1): Depends on Foundational tasks T003-T009
- US3 (P1): Depends on Foundational tasks T003-T009
- US4 (P2): Depends on US1 and US2 parity for shared behaviors
- US5 (P3): Depends on US1 and US2 parity and command matrix completion

---

## Parallel Execution Examples

### US1 (PowerShell-only)

- T010 Move PowerShell entrypoints in scripts/powershell/\*.ps1
- T011 Normalize PowerShell flags and exit codes in scripts/powershell/\*.ps1

### US2 (Bash-only)

- T013 Move Bash entrypoints in scripts/bash/\*.sh
- T014 Normalize Bash flags and exit codes in scripts/bash/\*.sh

### US3 (Spec-Kit parity)

- T016 Audit Spec-Kit routing in .specify/scripts/\*
- T017 Add Spec-Kit configuration validation in .specify/scripts/\*

### US4 (DigitalOcean MVP)

- T018 Define MVP option surface in digital_ocean/quickstart.md
- T019 Implement Bash deploy/test entrypoints in digital_ocean/scripts/bash/\*.sh

### US5 (Make-like interface)

- T021 Implement scripts/make/make.js
- T022 Add scripts/make/make.sh and scripts/make/make.ps1

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2
2. Complete US1 tasks T010-T012
3. Validate PowerShell-only workflow on Windows

### Incremental Delivery

1. US1 (PowerShell-only) -> validate
2. US2 (Bash-only) -> validate
3. US3 (Spec-Kit parity) -> validate
4. US4 (DigitalOcean MVP) -> validate
5. US5 (Make-like interface) -> validate

---

## Notes

- [P] tasks can run in parallel if dependencies are met.
- Each task lists explicit outputs and validation commands for independent verification.
- Tests are included for the guard as the primary enforcement mechanism.
