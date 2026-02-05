# Feature Specification: End-to-End Environment Setup + Deploy UX

**Feature Branch**: `[003-env-setup-deploy-ux]`  
**Created**: 2026-02-04  
**Status**: Draft  
**Input**: User description: "Feature: End-to-end environment setup + deploy UX (PROJECT_NAME templating, DigitalOcean mode, doctor command, category validation, auth fallbacks, safe dev defaults, zero hardcoded identifiers)"

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Guided First-Time Setup (Priority: P1)

As a new contributor (or a developer setting up a new environment), I can run a single guided setup command that creates or updates my local environment configuration safely, with clear next steps.

This setup flow eliminates hardcoded project identifiers and derives consistent environment identifiers from a user-provided project name.

**Why this priority**: This is the “first touch” experience. If it’s confusing or unsafe, onboarding fails and support burden increases.

**Independent Test**: From a fresh clone, run the setup command and confirm it creates a usable configuration file, creates a timestamped backup when overwriting, and outputs a categorized checklist with the next command to run.

**Acceptance Scenarios**:

1. **Given** a repository checkout with a provided example configuration file and no local configuration file, **When** I run the setup command, **Then** it creates a new local configuration file, prompts for required core inputs, and prints a categorized “next steps” checklist.
2. **Given** an existing local configuration file, **When** I run the setup command and confirm overwrite, **Then** it creates a timestamped backup first and then rewrites derived identifiers consistently from the chosen project name.
3. **Given** a project name that violates the allowed format (lowercase letters, numbers, hyphen), **When** I enter it in the setup prompt, **Then** the setup command rejects it and explains the expected format.

---

### User Story 2 - Setup Completion, Validation, and Credential Generation (Priority: P2)

As a developer preparing to run the application or deploy it, I can run a “setup completion” command that validates required configuration by category, fills in safe defaults for development (when opted in), generates required access credentials, and ensures allowlists reflect my public IP.

**Why this priority**: This makes the environment “ready” while preventing accidental insecure defaults and preventing placeholder values from shipping.

**Independent Test**: With a partially-filled local configuration file, run the setup completion command and confirm: (1) it fails with a categorized validation report when placeholders remain in required categories, (2) it generates missing credentials when needed, (3) it can run idempotently without continually changing values.

**Acceptance Scenarios**:

1. **Given** missing or placeholder values in required categories, **When** I run setup completion, **Then** it fails with a categorized list of what must be filled before continuing.
2. **Given** blank or placeholder basic-auth configuration, **When** I run setup completion, **Then** it generates primary credentials and applies them as fallbacks for service-specific credentials that are blank or placeholder.
3. **Given** I run setup completion multiple times without changing inputs, **When** I compare the resulting configuration files, **Then** the outputs remain stable (except for creating backups), demonstrating idempotence.
4. **Given** the environment is development and I enabled applying development defaults, **When** I run setup completion, **Then** it fills only the documented safe defaults and does not weaken production requirements.

---

### User Story 3 - Read-Only Doctor / Readiness Check (Priority: P3)

As a developer, I can run a read-only “doctor” command that audits readiness without modifying files, including placeholder detection, project identifier consistency, allowlist correctness, and missing prerequisites. It ends with a recommended next command.

**Why this priority**: Readiness checks reduce guesswork and prevent avoidable deployment/runtime failures.

**Independent Test**: Run doctor on (a) a fresh clone, (b) a partially configured environment, and (c) a fully configured environment; confirm it reports actionable findings and never modifies files.

**Acceptance Scenarios**:

1. **Given** placeholders remain in required categories, **When** I run doctor, **Then** it reports them by category and recommends the next corrective step.
2. **Given** the repository contains hardcoded legacy project identifiers, **When** I run doctor, **Then** it reports them and points to the affected locations.
3. **Given** everything required is configured for my selected environment and deploy mode, **When** I run doctor, **Then** it reports a clean readiness result and recommends starting the app or deploying.

---

### Edge Cases

- Example configuration file is missing or unreadable.
- Public IP detection fails (no network, multiple endpoints unavailable) or returns non-IPv4 output.
- User declines overwrite when an existing local configuration file is present.
- User selects production-like conditions (production environment or cloud deploy enabled) but required TLS/SMTP fields are blank.
- Placeholders remain in optional categories (e.g., OAuth) but required categories are valid.
- Credentials already exist; regeneration must not happen unexpectedly.
- Developer runs commands on a platform without required prerequisites (e.g., container runtime or package manager unavailable).

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The repository MUST contain zero hardcoded legacy project identifiers in committed code, configuration, and documentation; all identifiers MUST be derived from a user-provided project name (and UI branding from a configurable display name).
- **FR-002**: The setup command MUST require the presence of an example configuration file and MUST create a local configuration file when one is missing.
- **FR-003**: If a local configuration file exists, the setup command MUST prompt before overwriting and MUST create a timestamped pre-setup backup before making changes.
- **FR-004**: The setup command MUST prompt for a project name and enforce a validation rule of lowercase letters, numbers, and hyphen only.
- **FR-005**: The setup command MUST detect the user’s public IPv4 address using multiple endpoints and MUST validate the result as IPv4 before using it.
- **FR-006**: The setup command MUST derive and set consistent identifiers based on the project name, including service grouping identifiers, network identifiers, and web cookie identifiers.
- **FR-007**: The setup command MUST prompt for whether a cloud deploy mode will be used and MUST reflect that choice in subsequent validation requirements.
- **FR-008**: The system MUST implement a shared placeholder detection rule set that treats values as “unfinished” when they are empty or match known placeholder patterns (including IP allowlist placeholders).
- **FR-009**: The system MUST classify configuration keys into categories (Core, Secrets, Admin, Access, TLS, SMTP, OAuth optional) and MUST validate required categories.
- **FR-010**: Core, Secrets, Admin, and Access categories MUST always be required.
- **FR-011**: TLS and SMTP categories MUST be required when the environment is production OR when cloud deploy mode is enabled.
- **FR-012**: In development, when the user opts in to applying safe development defaults, the system MUST populate only the documented development defaults and MUST not apply them outside of development.
- **FR-013**: The setup completion command MUST validate categories and MUST block completion until all required categories are non-placeholder.
- **FR-014**: The setup completion command MUST generate primary basic-auth credentials when missing, MUST generate service-specific credentials when missing, and MUST support a documented fallback behavior where blank/placeholder service-specific credentials inherit the primary credentials.
- **FR-015**: The setup completion command MUST generate hashed credential strings suitable for use in access control configuration and MUST ensure they are safe to store in the local configuration file.
- **FR-016**: The setup completion command MUST fill allowlist values using the detected public IP.
- **FR-017**: The setup completion command MUST support a dry-run mode (no file modifications) and a no-print mode (no secrets printed to console).
- **FR-018**: The setup completion command MUST be idempotent: re-running it without input changes MUST not continually mutate the configuration.
- **FR-019**: The doctor command MUST be read-only and MUST report readiness across: placeholder detection, hardcoded identifier detection, project name consistency, auth integrity, allowlist completeness, and missing prerequisites.
- **FR-020**: The doctor command MUST end with a recommended next command appropriate to the detected state (e.g., run setup completion, start locally, or deploy).
- **FR-021**: Git hygiene MUST prevent accidental commits of local configuration artifacts by ensuring backup files are ignored by version control.
- **FR-022**: Deploy UX MUST follow the selected deploy mode: when cloud deploy mode is false, it MUST recommend local start; when true, it MUST recommend the cloud deploy orchestrator path.

### Assumptions

- A single local configuration file exists for local/dev usage, and an example configuration file exists in the repository.
- OAuth configuration is optional unless explicitly enabled by the user.
- “Safe dev defaults” apply only when the environment is development and the user opts in.

### Dependencies

- The user can access at least one public IP detection endpoint during setup (or the system provides a clear failure mode and guidance).
- The user has the required runtime prerequisites installed to start services locally and/or to run a deployment (doctor will report missing prerequisites).

### Key Entities _(include if feature involves data)_

- **Environment Configuration**: The user-editable set of configuration keys and values used to run or deploy the system (includes derived identifiers, secrets, allowlists).
- **Placeholder**: A value considered unfinished (empty or matching known placeholder patterns) and therefore not acceptable for required categories.
- **Category**: A labeled grouping of configuration keys used for validation and user guidance (Core, Secrets, Admin, Access, TLS, SMTP, OAuth optional).
- **Backup**: A timestamped snapshot of a pre-existing local configuration file created before any overwrite.
- **Credential Set**: Generated basic-auth credentials (primary plus optional service-specific overrides) used to protect administrative endpoints.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A new user can complete the guided setup flow (setup → edit config → completion → doctor) in under 10 minutes using only on-screen prompts and the printed checklist.
- **SC-002**: Running doctor on a fully configured environment reports zero required-category placeholder findings.
- **SC-003**: A repository-wide scan finds zero occurrences of hardcoded legacy project identifiers in committed files.
- **SC-004**: Re-running setup completion without changing inputs produces no net configuration changes (excluding the creation of backup files).
- **SC-005**: When cloud deploy mode is enabled or the environment is production, setup completion blocks until TLS and SMTP required fields are non-placeholder.
- **SC-006**: No secrets are printed to the console when no-print mode is enabled.
