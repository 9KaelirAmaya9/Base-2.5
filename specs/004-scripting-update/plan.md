# Implementation Plan: Scripting Update (Shell Parity + Script Routing)

**Branch**: `004-scripting-update` | **Date**: 2026-02-12 | **Spec**: [specs/004-scripting-update/spec.md](specs/004-scripting-update/spec.md)
**Input**: Feature specification from [specs/004-scripting-update/spec.md](specs/004-scripting-update/spec.md)

## Summary

Standardize script routing so local PowerShell and Bash entrypoints never cross-call, add a guard with an allowlisted remote payload escape hatch, reorganize scripts into canonical shell-specific folders, and provide a make-like cross-platform interface once parity is achieved.

## Technical Context

**Language/Version**: PowerShell 7+, Bash, Node.js 18+, Python 3.12  
**Primary Dependencies**: Node.js repo tooling, Python-based DigitalOcean orchestration, Docker Compose 2+  
**Storage**: N/A (configuration and script files)  
**Testing**: `node --test` for script tests, `pytest` for Python, shell-level smoke commands  
**Target Platform**: Windows (PowerShell), Mac/Linux (Bash), CI runners (Linux)  
**Project Type**: Monorepo with scripts and multi-service Docker Compose  
**Performance Goals**: Guard completes in under 30 seconds on CI (SC-003)  
**Constraints**: No local cross-shell calls, keep CI green during migration, preserve flags/exit codes  
**Scale/Scope**: Hundreds of scripts across repo + DigitalOcean tooling

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- Spec-driven flow preserved (Constitution 0) - PASS
- TDD respected for new guard and script changes (I) - PASS
- Single-entrypoint operations preserved for deploy/test (IV) - PASS
- Script parity and shell boundaries enforced (V) - PASS
- Docs updated for user-facing changes (IV) - PASS

## Project Structure

### Documentation (this feature)

```text
specs/004-scripting-update/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
scripts/
├── *.ps1 / *.sh / *.js / *.py   # Current mixed scripts (to be reorganized)
├── lib/                         # Node script libs
└── tests/                       # Node tests for scripts

.specify/scripts/
├── bash/
└── powershell/

digital_ocean/
├── scripts/
│   ├── powershell/
│   ├── python/
│   └── *.sh
└── *.py

docs/
README.md
Makefile
package.json
```

**Structure Decision**: Continue with the existing monorepo layout; changes are scoped to script locations, guard tooling, and documentation updates.

## Phase 0: Research (complete)

**Goal**: Resolve tool and guard design decisions.
**Outputs**: [specs/004-scripting-update/research.md](specs/004-scripting-update/research.md)

## Phase 1: Design and Contracts (complete)

**Goal**: Document data model and usage guidance for command parity and guard behavior.
**Outputs**:

- [specs/004-scripting-update/data-model.md](specs/004-scripting-update/data-model.md)
- [specs/004-scripting-update/contracts/README.md](specs/004-scripting-update/contracts/README.md)
- [specs/004-scripting-update/quickstart.md](specs/004-scripting-update/quickstart.md)

**Post-design Constitution Check**: PASS (no new violations introduced)

## Phase 2: Audit + Command Matrix

**Goal**: Inventory primary commands and fill the command matrix in the spec.
**Key steps**:

1. Inventory references in docs and config:

- README and docs (DEVELOPMENT, GOLDEN_PATH, RUNBOOKS)
- Makefile targets
- CI workflows and package.json scripts

2. Inventory scripts under:

- scripts/
- .specify/scripts/
- digital_ocean/scripts/

3. Populate the command matrix with:

- concrete entrypoint paths per shell
- flags/options and exit codes
- shared implementation pointers (if any)

4. Capture drift detection strategy:

- Add a simple matrix validation check (phase 2 output) that compares matrix rows to discovered entrypoints and fails on missing parity.

**Files to update**:

- [specs/004-scripting-update/spec.md](specs/004-scripting-update/spec.md)
- New or updated matrix validation script (location finalized in Phase 4)

## Phase 3: Guardrails (no-cross-shell)

**Goal**: Implement guard and integrate with CI.

**Guard design**:

- **Location**: `scripts/guard-shell-parity.js`
- **Scan scope**:
  - scripts/
  - .specify/scripts/
  - digital_ocean/scripts/
  - Additional directories documented in Phase 2 inventory
- **Violation patterns** (local invocation only):
  - PowerShell calling `.sh` paths directly or via `bash`/`sh` execution verbs
  - Bash calling `.ps1` paths directly or via `pwsh`/`powershell` execution verbs
- **Remote allowlist**:
  - File: `scripts/allowlists/remote-linux-payloads.txt`
  - Format: one path or glob per line, `#` inline comments
  - Allowed only when invocation passes through the designated remote-exec helpers:
  - `digital_ocean/scripts/python/orchestrate_deploy.py`
  - `digital_ocean/scripts/powershell/deploy.ps1`
- **Failure output**: `path:line | violation_type | matched_text`

**CI integration**:

- Add guard execution to CI workflows; block merges on violation.

**Files to create/modify**:

- `scripts/guard-shell-parity.js`
- `scripts/allowlists/remote-linux-payloads.txt`
- CI workflow file(s) running the guard

## Phase 4: Routing Fixes + Script Reorganization (keep guard green)

**Goal**: Move scripts into canonical folders and fix all callers while keeping CI green.

**Approach**:

1. Build a script relocation map (old path -> new path + callers).
2. Create target folders:

- `scripts/bash/`, `scripts/powershell/`, `scripts/python/`, `scripts/make/`
- `.specify/scripts/bash/`, `.specify/scripts/powershell/`
- `digital_ocean/scripts/bash/`, `digital_ocean/scripts/powershell/`, `digital_ocean/scripts/python/`

3. Use optional same-shell shims at old locations (sh -> sh, ps1 -> ps1) to keep CI green during migration.
4. Move and update callers in this order:

- Bash scripts
- PowerShell scripts
- Python scripts

5. For any Python utilities, add Bash and PowerShell wrappers so all operational entrypoints retain shell parity.
6. Remove shims after all references are updated and guard passes.

**Files to update**:

- scripts/\* (moved to canonical subfolders)
- .specify/scripts/\* (ensure parity)
- digital_ocean/scripts/\* (ensure parity)
- Makefile, docs, README, CI, package.json scripts

## Phase 5: Parity Implementation (primary commands)

**Goal**: Ensure the primary commands match across shells.

**Strategy**:

- Choose shared implementation only when logic is complex or already Node/Python-based.
- Otherwise keep shell-native implementations with synchronized flags/exit codes/help output.

**Files to update**:

- `scripts/bash/*` and `scripts/powershell/*` entrypoints
- Shared implementation files where applicable
- Spec-Kit scripts under `.specify/scripts/`

## Phase 6: DigitalOcean MVP parity

**Goal**: Bash deploy/test path mirrors the PowerShell happy-path options.

**Scope definition**:

- MVP options are those documented in DigitalOcean quickstart and README.
- Deferred options include advanced/experimental flags not required by docs.

**Parity definition**:

- Same exit codes for success/failure
- Similar log structure and artifact outputs

**Entry point routing**:

- All DigitalOcean deploy/test entrypoints (Bash or PowerShell) MUST route through `digital_ocean/orchestrate_deploy.py` to satisfy single-entrypoint operations.

**Files to update**:

- `digital_ocean/scripts/bash/*`
- `digital_ocean/scripts/powershell/*` (if alignment needed)
- Docs under `digital_ocean/` and repo root

## Phase 7: Make-like interface

**Goal**: Provide a unified command interface.

**Recommendation**:

- Source of truth: `scripts/make/make.js`
- Wrappers: `scripts/make/make.sh`, `scripts/make/make.ps1`

**Target mapping**:

- Map `setup/start/stop/restart/logs/test/deploy` to existing entrypoints from the matrix.

**Files to update**:

- `scripts/make/*`
- Optional: Makefile targets to delegate to make wrappers

## Phase 8: Docs + Final Verification

**Goal**: Update documentation and confirm all checks pass.

**Docs to update**:

- README, docs/DEVELOPMENT.md, docs/GOLDEN_PATH.md
- DigitalOcean quickstart and README

**Verification**:

- Guard passes
- PowerShell workflow passes without Bash
- Bash workflow passes without PowerShell
- Spec-Kit routing validated
- Make-like commands functional
- CI green

## Risk Register + Mitigations

- **Behavior drift between shells**: Use shared implementations where complexity is high; add parity tests and command matrix validation.
- **CI breakage during reorg**: Use same-shell shims during migration and remove them only after caller updates.
- **Platform differences**: Validate on Windows and Mac/Linux; avoid shell-specific assumptions in shared code.
- **DigitalOcean complexity**: Limit scope to MVP documented options and align logs/exit codes.

## Definition of Done

- Command matrix completed and enforced
- Guard runs in CI and blocks cross-shell local invocations
- Scripts reorganized into canonical folders with no stale references
- PowerShell and Bash workflows pass with matching flags/exit codes
- DigitalOcean MVP Bash path matches PowerShell happy path
- Make-like interface works on Windows and Mac/Linux
- Documentation updated and CI green
