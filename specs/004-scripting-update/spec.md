# Feature Specification: Scripting Update (Shell Parity + Script Routing)

**Feature Branch**: `004-scripting-update`  
**Created**: 2026-02-12  
**Status**: Draft  
**Input**: User description: "Standardize script routing so PowerShell calls PowerShell locally, Bash calls Bash locally, allow remote Linux payloads only via allowlisted helpers, ensure parity, and add make-like commands once CI is green."

## Objective

Establish strict local shell separation with parity across PowerShell and Bash workflows, add guardrails that prevent cross-shell local invocations while allowing approved remote Linux payload execution, and provide a make-like cross-platform command interface once parity is achieved and CI is green.

## Definitions

- **Local invocation**: executing a script on the developer’s machine (or CI runner) directly or via a shell command.
- **Cross-shell call**: a `.ps1` script invoking a `.sh` script locally OR a `.sh` script invoking a `.ps1` script locally.
- **Remote Linux payload**: a `.sh` script copied to a remote Linux host and executed there via SSH.

## Primary Command Matrix

This table is the source of truth for commands supported by both shells. Each row must be fully populated before implementation begins, using concrete entrypoint paths, flags/options, and exit codes gathered from audit sources (docs, Makefile, CI, and existing scripts). Empty cells are non-compliant.

| Command name | Bash entrypoint path                       | PowerShell entrypoint path                  | Shared implementation (Y/N; specify file if Y) | Supported flags/options | Expected exit codes   | Notes                                      |
| ------------ | ------------------------------------------ | ------------------------------------------- | ---------------------------------------------- | ----------------------- | --------------------- | ------------------------------------------ |
| setup        | Populate during audit: .sh entrypoint path | Populate during audit: .ps1 entrypoint path | Populate during audit                          | Populate during audit   | Populate during audit | Include any config validation requirements |
| start        | Populate during audit: .sh entrypoint path | Populate during audit: .ps1 entrypoint path | Populate during audit                          | Populate during audit   | Populate during audit | Identify if remote payloads are involved   |
| stop         | Populate during audit: .sh entrypoint path | Populate during audit: .ps1 entrypoint path | Populate during audit                          | Populate during audit   | Populate during audit |                                            |
| restart      | Populate during audit: .sh entrypoint path | Populate during audit: .ps1 entrypoint path | Populate during audit                          | Populate during audit   | Populate during audit |                                            |
| logs         | Populate during audit: .sh entrypoint path | Populate during audit: .ps1 entrypoint path | Populate during audit                          | Populate during audit   | Populate during audit |                                            |
| test         | Populate during audit: .sh entrypoint path | Populate during audit: .ps1 entrypoint path | Populate during audit                          | Populate during audit   | Populate during audit | Include DO MVP scope notes if applicable   |
| deploy       | Populate during audit: .sh entrypoint path | Populate during audit: .ps1 entrypoint path | Populate during audit                          | Populate during audit   | Populate during audit | Mark if remote payload allowed             |

## Rules: Forbidden / Allowed

**Forbidden**:

- Any local `.ps1` invoking any `.sh`
- Any local `.sh` invoking any `.ps1`

**Allowed**:

- PowerShell may execute `.sh` scripts on a remote Linux host only through:
  - an explicit remote-exec helper designated in the guardrails section
  - the designated helper is a single entrypoint selected during implementation
  - a documented allowlist of remote paths/patterns

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Windows PowerShell-only workflow (Priority: P1)

As a Windows developer, I run the primary commands entirely through PowerShell without installing or invoking Bash locally.

**Why this priority**: This is the highest-risk workflow for cross-shell leakage and must work end-to-end for Windows contributors.

**Independent Test**: Can be fully tested by running all primary commands from PowerShell on Windows with Bash/WSL/Git Bash unavailable.

**Acceptance Scenarios**:

1. **Given** a Windows machine without Bash, **When** I run each primary PowerShell command, **Then** each command completes using only PowerShell or shared implementations and exits with the documented exit codes.
2. **Given** the command matrix, **When** I compare PowerShell flags and exit codes to Bash, **Then** they match for each primary command.

---

### User Story 2 - Mac/Linux Bash-only workflow (Priority: P1)

As a Mac/Linux developer, I run the primary commands entirely through Bash without installing or invoking PowerShell locally.

**Why this priority**: This ensures parity and eliminates cross-shell dependencies for Unix-like environments.

**Independent Test**: Can be fully tested by running all primary commands from Bash on Mac/Linux without PowerShell installed.

**Acceptance Scenarios**:

1. **Given** a Mac/Linux machine without PowerShell, **When** I run each primary Bash command, **Then** each command completes using only Bash or shared implementations and exits with the documented exit codes.
2. **Given** the command matrix, **When** I compare Bash flags and exit codes to PowerShell, **Then** they match for each primary command.

---

### User Story 3 - Spec-Kit parity (Priority: P1)

As a maintainer, I need `.specify/scripts/powershell/*.ps1` to call only PowerShell or shared implementations and `.specify/scripts/bash/*.sh` to call only Bash or shared implementations, with clear configuration validation.

**Why this priority**: Spec-Kit scripts are foundational; cross-shell violations here would break core workflows.

**Independent Test**: Can be fully tested by running the guard and verifying script routing in `.specify/scripts/` without executing any other repo scripts.

**Acceptance Scenarios**:

1. **Given** any `.specify/scripts/powershell/*.ps1`, **When** it is executed locally, **Then** it invokes only PowerShell or shared implementations and passes configuration validation.
2. **Given** any `.specify/scripts/bash/*.sh`, **When** it is executed locally, **Then** it invokes only Bash or shared implementations and passes configuration validation.

---

### User Story 4 - DigitalOcean MVP parity (Priority: P2)

As a developer deploying to DigitalOcean, I can use a Bash deploy/test path that mirrors the PowerShell documented happy-path options and yields equivalent results.

**Why this priority**: This unblocks Mac/Linux contributors for the minimal documented deployment path without requiring full option parity.

**Independent Test**: Can be fully tested by running the MVP deploy and test flow using Bash with the documented options and verifying logs and exit codes.

**Acceptance Scenarios**:

1. **Given** the documented PowerShell happy-path options for DigitalOcean, **When** I run the equivalent Bash deploy and test commands, **Then** the operations succeed and exit codes match the PowerShell workflow.
2. **Given** a failure in the Bash deploy/test flow, **When** it exits, **Then** the exit code and log structure match the PowerShell workflow for the same failure case.

---

### User Story 5 - Make-like commands (Priority: P3)

As a contributor on any platform, I can use a single make-like interface to run common repository operations with consistent behavior.

**Why this priority**: This provides a unified entrypoint after parity is achieved, reducing platform friction.

**Independent Test**: Can be fully tested by running the make-like interface on Windows and Mac/Linux for each primary command.

**Acceptance Scenarios**:

1. **Given** the make-like interface, **When** I run each primary command through it on Windows and Mac/Linux, **Then** the same behavior, flags, and exit codes are observed.
2. **Given** the command matrix, **When** I run the make-like interface help output, **Then** it lists the same commands and flags defined in the matrix.

### Edge Cases

- A local script attempts to invoke a cross-shell entrypoint with a relative path.
- A local script attempts to invoke a cross-shell entrypoint via a shell executable (for example, `bash` or `pwsh`).
- A remote Linux payload path is not in the allowlist.
- The allowlist file is missing or malformed.
- A command exists in one shell but has no counterpart in the other shell.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The system MUST maintain the Primary Command Matrix as the source of truth, and each primary command MUST have both a Bash and PowerShell entrypoint (or an explicit shared implementation) before implementation begins.
- **FR-002**: Local invocation MUST prohibit cross-shell calls, with any `.ps1` invoking `.sh` or any `.sh` invoking `.ps1` treated as a violation.
- **FR-003**: A guard MUST scan the repository for local cross-shell violations across `scripts/`, `.specify/scripts/`, `digital_ocean/scripts/`, and any other documented script directories.
- **FR-004**: The guard MUST allow remote Linux payload execution only when invoked through a designated remote-exec helper and only for allowlisted remote paths/patterns.
- **FR-005**: The allowlist mechanism MUST be documented, versioned, and support one path or pattern per line with inline `#` comments.
- **FR-006**: The guard MUST report violations with file path, line number, and matched text and MUST exit non-zero on any violation.
- **FR-007**: CI MUST run the guard and fail the build when violations are detected.
- **FR-008**: PowerShell-only and Bash-only workflows MUST support the full primary command set with matching flags/options and exit codes.
- **FR-009**: `.specify/scripts/powershell/*.ps1` and `.specify/scripts/bash/*.sh` MUST only invoke their native shell or shared implementations and MUST validate required configuration inputs.
- **FR-010**: The DigitalOcean MVP Bash deploy/test path MUST mirror the documented PowerShell happy-path option surface, including exit codes and log structure.
- **FR-011**: A make-like interface MUST expose the primary commands on all platforms with the same flags and exit codes as the native entrypoints.
- **FR-012**: Scripts MUST be reorganized into canonical shell-specific folders while preserving existing behavior, flags, and exit codes.

### Key Entities _(include if feature involves data)_

- **Command Definition**: Primary command name, Bash entrypoint path, PowerShell entrypoint path, shared implementation reference, flags/options, and expected exit codes.
- **Shell Entrypoint**: A script path plus its shell type (Bash or PowerShell) used for local invocation.
- **Remote Payload Allowlist Entry**: A remote Linux path or pattern plus an optional comment describing intent.
- **Guard Violation**: File path, line number, matched text, and violation type.

## Guardrails / CI Requirements

- The guard MUST scan shell entrypoints and wrappers for local cross-shell invocation patterns, including direct file references and shell executable calls.
- The guard MUST treat local cross-shell invocation as a violation and report file path, line number, and matched text.
- Remote Linux payload execution MUST be allowed only through a designated remote-exec helper and a documented allowlist mechanism.
- The remote-exec helper is a single, designated entrypoint for remote payload execution.
- The guard MUST run in CI as a required check for all changes that touch script files or the allowlist.

## Verification Checklist (DoD)

- Guard passes on a clean repository state.
- PowerShell workflow works end-to-end without Bash installed.
- Bash workflow works end-to-end without PowerShell installed.
- Spec-Kit routing validation passes.
- Make-like commands are functional on Windows and Mac/Linux.
- CI is green with the guard enforced.

## Assumptions

- Exit codes use `0` for success and non-zero for failure across all primary commands.
- Documentation reflects the canonical set of primary commands and flags used by contributors.

## Dependencies

- CI workflows are available to run the guard on all pull requests.
- DigitalOcean documentation defines a minimal happy-path option surface for deploy/test.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: 100% of primary commands can be executed on Windows using PowerShell without Bash/WSL/Git Bash installed.
- **SC-002**: 100% of primary commands can be executed on Mac/Linux using Bash without PowerShell installed.
- **SC-003**: The guard completes in under 30 seconds on CI and blocks all detected local cross-shell invocations.
- **SC-004**: Flags/options and exit codes match across shells for every primary command in the matrix.
- **SC-005**: The make-like interface can invoke every primary command on Windows and Mac/Linux with the same observable outcomes as native entrypoints.
- **SC-006**: The DigitalOcean MVP Bash deploy/test flow matches the documented PowerShell happy-path exit codes and log structure for success and failure cases.

## Non-goals

- Full DigitalOcean option parity beyond the documented MVP happy path.
- Rewriting every script for stylistic consistency outside of parity and routing needs.
- Changing the underlying deployment architecture or infrastructure providers.
