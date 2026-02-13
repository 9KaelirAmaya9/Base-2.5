## Edit/Maintain

Run the edit/maintain script to update deployed resources (with `.venv` active):

```bash
(.venv) python digital_ocean/scripts/python/edit.py [--dry-run]
# or
./digital_ocean/scripts/bash/edit.sh [--dry-run]
```

**Options:**

- `--dry-run`: Show what would be updated without making changes.

**Environment:**

- Requires all Digital Ocean variables in `.env`.

**Error Handling:**

- Exits nonzero on error. See logs for details.

**Rollback:**

- If update fails, rollback logic will log the error and exit with code 4.

**Windows:**

- Use PowerShell for venv activation and script execution.

**Mac/Linux:**

- Use Bash or Zsh for venv activation and script execution.

**Docker:**

- All scripts work in containerized environments.

## Teardown

Run the teardown script to remove deployed resources:

```bash
(.venv) python digital_ocean/scripts/python/teardown.py [--dry-run]
# or
./digital_ocean/scripts/bash/teardown.sh [--dry-run]
```

**Options:**

- `--dry-run`: Show what would be deleted without making changes.

**Environment:**

- Requires all Digital Ocean variables in `.env`.

**Error Handling:**

- Exits nonzero on error. See logs for details.

**Rollback:**

- If deletion fails, rollback logic will log the error and exit with code 4.

**Windows:**

- Use PowerShell for venv activation and script execution.

**Mac/Linux:**

- Use Bash or Zsh for venv activation and script execution.

**Docker:**

- All scripts work in containerized environments.

## Onboarding Steps

1. **Clone the repository** and enter the project directory.
2. **Configure environment variables**:
   - Copy `.env.example` to `.env` and fill in all required Digital Ocean variables (see comments in `.env.example`).
   - Key variables: `DO_API_TOKEN`, `DO_API_REGION`, `DO_API_IMAGE`, `DO_APP_NAME`, etc.
   - Never commit `.env` to version control.
3. **Run first-start orchestration**:
   - `./scripts/powershell/first-start.ps1` (PowerShell) or `pwsh -ExecutionPolicy Bypass -File ./scripts/powershell/first-start.ps1`
   - Creates/activates `.venv`, installs Python/Node dependencies, and runs the guided setup.
   - Guided setup generates `.env` from `.env.example` and may prompt to overwrite `.env` and request required values (DigitalOcean token, domain, emails, etc.).
   - Use `-SkipSetup` if you only need to hydrate dependencies.
   - Keep `.venv` active for all pip installs and DigitalOcean Python commands.

   Exact scripts invoked by `first-start.ps1` (in order):
   - `scripts/powershell/bootstrap-venv.ps1`
   - `scripts/powershell/install-python-deps.ps1`
   - `scripts/powershell/install-node-deps.ps1`
   - `scripts/powershell/setup.ps1`

## Experimental tools

Experimental or stubbed scripts live in [digital_ocean/experimental](experimental/README.md). These are not part of the supported automation path and may change without notice.

### DigitalOcean SSH key sync (runs during setup)

This step runs inside [scripts/powershell/setup.ps1](../scripts/powershell/setup.ps1) after .env is written. It calls [scripts/powershell/add-ssh-key.ps1](scripts/powershell/add-ssh-key.ps1) and uses [DO_ssh_keys.py](DO_ssh_keys.py).

What it does (ordered):

- Determines the key name from PROJECT_NAME (fallback: do-ssh).
- Ensures a local SSH key exists at ~/.ssh/<keyName> (creates ED25519 key if missing).
- Queries DigitalOcean for matching keys (same name and public key).
- If a mismatch exists, deletes old DO keys and registers the local key.
- Updates .env with DO_SSH_KEY_ID and DO_API_SSH_KEYS.

Why it exists:

- Droplet provisioning requires a valid DO SSH key; this keeps local and DO keys in sync automatically.

### Setup prompts (interactive)

The interactive questions come from [scripts/setup.js](../scripts/setup.js) (invoked by [scripts/powershell/setup.ps1](../scripts/powershell/setup.ps1)). These are the exact prompts and choices:

- Overwrite existing .env: yes/no (default no); creates a timestamped backup on yes.
- Project name: lowercase letters, digits, hyphen only; required.
- Website domain: required non-empty value.
- Primary email: optional; if provided you are asked whether to apply it to all default email fields.
- Primary password: optional (masked); if provided you are asked whether to apply it to all default password fields.
- Primary username: optional; if provided you are asked whether to apply it to all default username fields.
- Git repo URL: optional; used for deploy automation defaults.
- Git repo branch: optional; used for deploy automation defaults.
- Environment: choice of development, staging, production.
- Deploy mode: choice of local or digitalocean.
- Apply safe dev defaults: yes/no, only when environment is development.

Dev defaults summary:

- Selecting "Apply safe dev defaults" sets `APPLY_DEV_DEFAULTS=true` in `.env`.
- When you later run `npm run setup:complete`, the only change it applies is `DJANGO_DEBUG=true` (only if `ENV=development`).

Non-interactive note:

- `scripts/powershell/setup.ps1 -NonInteractive` disables prompts and reads values from args/environment; it will fail fast if required values are missing.

After writing .env, [scripts/setup.js](../scripts/setup.js) prints a checklist of required categories and recommends running:

- npm run setup:complete
- npm run doctor

Tip: `scripts/powershell/first-start.ps1 -Help` and `scripts/powershell/setup.ps1 -Help` print usage details.

### Golden path (all-green deploy)

See the full end-to-end sequence in [docs/GOLDEN_PATH.md](../docs/GOLDEN_PATH.md). 4. **(Optional) Node.js scripts**:

- Additional `npm install` runs are only needed for custom directories beyond the defaults handled by `first-start`.

5. **Cross-platform usage**:
   - Windows: Use PowerShell for venv activation and script execution.
   - Mac/Linux: Use Bash or Zsh for venv activation and script execution.
   - Docker: All scripts work in containerized environments.

## Environment Variables Summary

| Variable      | Purpose/Usage                           |
| ------------- | --------------------------------------- |
| DO_API_TOKEN  | API authentication (required)           |
| DO_API_REGION | Resource region (required, e.g., nyc3)  |
| DO_API_IMAGE  | Image slug for Droplets/Apps (required) |
| DO_APP_NAME   | Name for deployed app (required)        |
| ...           | See `.env.example` for full list        |

## Usage

Activate the repo virtual environment before running these commands (PowerShell: `.\.venv\Scripts\Activate.ps1`, Bash: `source .venv/bin/activate`). Running `./scripts/powershell/first-start.ps1` handles this for the current shell. Once active:

- **Deploy**: `./digital_ocean/scripts/bash/deploy.sh [options]` or `(.venv) python digital_ocean/scripts/python/deploy.py [--dry-run]`
- **Teardown**: `./digital_ocean/scripts/bash/teardown.sh` or `(.venv) python digital_ocean/scripts/python/teardown.py`
- **Edit/Maintain**: `./digital_ocean/scripts/bash/edit.sh` or `(.venv) python digital_ocean/scripts/python/edit.py`
- **Info/Query**: `./digital_ocean/scripts/bash/info.sh` or `(.venv) python digital_ocean/scripts/python/info.py`
- **Exec**: `./digital_ocean/scripts/bash/exec.sh` or `(.venv) python digital_ocean/scripts/python/exec.py`

## Deployment Instructions

1. Ensure all required environment variables are set in `.env`.
2. Run `./scripts/powershell/first-start.ps1` if `.venv` is not already active and hydrated.
3. Run the deployment script:
   ```bash
   ./digital_ocean/scripts/bash/deploy.sh [options]
   # or
   (.venv) python digital_ocean/scripts/python/deploy.py [--dry-run]
   ```
   Bash MVP flags:
   - `--dry-run`
   - `--update-only`
   - `--full` (default when no deploy mode is specified)
   - `--env-path <path>` (sets `ENV_PATH` for the orchestrator)
   - `--logs-dir <path>` (sets `DEPLOY_ARTIFACT_DIR`)
   - `--timestamped` (append a timestamp to the logs dir)
4. Monitor logs for deployment status and errors.

## Teardown Instructions

1. Ensure all required environment variables are set in `.env`.
2. Run `./scripts/powershell/first-start.ps1` if `.venv` is not already active and hydrated.
3. Run the teardown script:
   ```bash
   ./digital_ocean/scripts/bash/teardown.sh [--dry-run]
   # or
   (.venv) python digital_ocean/scripts/python/teardown.py [--dry-run]
   ```
4. Monitor logs for teardown status and errors.

## Edit/Maintain Instructions

1. Ensure all required environment variables are set in `.env`.
2. Run `./scripts/powershell/first-start.ps1` if `.venv` is not already active and hydrated.
3. Run the edit/maintain script:
   ```bash
   ./digital_ocean/scripts/bash/edit.sh
   # or
   (.venv) python digital_ocean/scripts/python/edit.py
   ```
4. Monitor logs for edit/maintain status and errors.

## Troubleshooting

- Missing or invalid environment variables will cause scripts to exit with an error.
- API errors: Check token, region, image, and permissions.
- Deployment failures: Check logs and API response codes.
- Rate limits: Adjust retry settings in `.env.example`.

## References

- [Digital Ocean API Docs](https://docs.digitalocean.com/reference/api/api-reference/)
- See `README.md` for more details and advanced usage.
