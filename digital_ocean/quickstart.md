## Edit/Maintain

Run the edit/maintain script to update deployed resources (with `.venv` active):

```bash
(.venv) python edit.py [--dry-run]
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
(.venv) python teardown.py [--dry-run]
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
   - `./scripts/first-start.ps1` (PowerShell) or `pwsh -ExecutionPolicy Bypass -File ./scripts/first-start.ps1`
   - Creates/activates `.venv`, installs Python/Node dependencies, and runs the guided setup.
   - Use `-SkipSetup` if you only need to hydrate dependencies.
   - Keep `.venv` active for all pip installs and DigitalOcean Python commands.
4. **(Optional) Node.js scripts**:
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

Activate the repo virtual environment before running these commands (PowerShell: `.\.venv\Scripts\Activate.ps1`, Bash: `source .venv/bin/activate`). Running `./scripts/first-start.ps1` handles this for the current shell. Once active:

- **Deploy**: `./scripts/deploy.sh [--dry-run]` or `(.venv) python deploy.py [--dry-run]`
- **Teardown**: `./scripts/teardown.sh` or `(.venv) python teardown.py`
- **Edit/Maintain**: `./scripts/edit.sh` or `(.venv) python edit.py`
- **Info/Query**: `./scripts/info.sh` or `(.venv) python info.py`
- **Exec**: `./scripts/exec.sh` or `(.venv) python exec.py`

## Deployment Instructions

1. Ensure all required environment variables are set in `.env`.
2. Run `./scripts/first-start.ps1` if `.venv` is not already active and hydrated.
3. Run the deployment script:
   ```bash
   cd digital_ocean/scripts
   ./deploy.sh
   # or
   (.venv) python ../deploy.py
   ```
4. Monitor logs for deployment status and errors.

## Teardown Instructions

1. Ensure all required environment variables are set in `.env`.
2. Run `./scripts/first-start.ps1` if `.venv` is not already active and hydrated.
3. Run the teardown script:
   ```bash
   cd digital_ocean/scripts
   ./teardown.sh [--dry-run]
   # or
   (.venv) python ../teardown.py [--dry-run]
   ```
4. Monitor logs for teardown status and errors.

## Edit/Maintain Instructions

1. Ensure all required environment variables are set in `.env`.
2. Run `./scripts/first-start.ps1` if `.venv` is not already active and hydrated.
3. Run the edit/maintain script:
   ```bash
   cd digital_ocean/scripts
   ./edit.sh
   # or
   (.venv) python ../edit.py
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
