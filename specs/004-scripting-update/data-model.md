# Data Model: Scripting Update (Shell Parity + Script Routing)

## Entities

### CommandDefinition

Represents a primary command and its parity requirements.

Fields:

- `name` (string, required): Command name (setup/start/stop/restart/logs/test/deploy).
- `bash_entrypoint` (string, required): Path to the Bash entrypoint.
- `powershell_entrypoint` (string, required): Path to the PowerShell entrypoint.
- `shared_impl` (string, optional): Shared implementation path if used.
- `flags` (string[], required): Supported flags/options.
- `exit_codes` (int[], required): Expected exit codes.
- `notes` (string, optional): Constraints such as remote payload allowance.

Relationships:

- Has many `ShellEntrypoint` entries (one per shell).

### ShellEntrypoint

Represents a script entrypoint and its shell type.

Fields:

- `path` (string, required)
- `shell` (enum: bash, powershell)
- `command` (string, required): Associated primary command name.

### RemotePayloadAllowlistEntry

Defines an allowlisted remote Linux payload path or pattern.

Fields:

- `pattern` (string, required)
- `comment` (string, optional)

### GuardViolation

Captures a guard failure for cross-shell local invocation.

Fields:

- `file_path` (string, required)
- `line_number` (int, required)
- `matched_text` (string, required)
- `violation_type` (enum: ps_calls_sh, sh_calls_ps, unknown)

### ScriptRelocationMap

Tracks old-to-new script locations during reorganization.

Fields:

- `from_path` (string, required)
- `to_path` (string, required)
- `shell` (enum: bash, powershell, python, node)
- `callers` (string[], required)
