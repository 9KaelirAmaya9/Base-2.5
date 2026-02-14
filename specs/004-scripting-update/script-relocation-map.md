# Script Relocation Map

This map lists script moves and known callers. Callers are best-effort and will be updated during migration.

## Repo scripts (Bash)

| From                       | To                              | Callers                                                         |
| -------------------------- | ------------------------------- | --------------------------------------------------------------- |
| scripts/start.sh           | scripts/bash/start.sh           | Makefile (up), README.md, docs/TESTING.md                       |
| scripts/stop.sh            | scripts/bash/stop.sh            | Makefile (down), README.md                                      |
| scripts/restart.sh         | scripts/bash/restart.sh         | Makefile (restart)                                              |
| scripts/logs.sh            | scripts/bash/logs.sh            | README.md                                                       |
| scripts/test.sh            | scripts/bash/test.sh            | Makefile (test), docs/TESTING.md                                |
| scripts/setup.sh           | scripts/bash/setup.sh           | README.md, digital_ocean/README.md, digital_ocean/quickstart.md |
| scripts/setup-hooks.sh     | scripts/bash/setup-hooks.sh     | direct CLI usage                                                |
| scripts/spec_kit_update.sh | scripts/bash/spec_kit_update.sh | direct CLI usage                                                |
| scripts/sync-env.sh        | scripts/bash/sync-env.sh        | scripts/start.sh                                                |
| scripts/status.sh          | scripts/bash/status.sh          | direct CLI usage                                                |
| scripts/shell.sh           | scripts/bash/shell.sh           | direct CLI usage                                                |
| scripts/kill.sh            | scripts/bash/kill.sh            | direct CLI usage                                                |
| scripts/clean.sh           | scripts/bash/clean.sh           | direct CLI usage                                                |
| scripts/debug.sh           | scripts/bash/debug.sh           | direct CLI usage                                                |
| scripts/health.sh          | scripts/bash/health.sh          | direct CLI usage                                                |
| scripts/generate_client.sh | scripts/bash/generate_client.sh | direct CLI usage                                                |
| scripts/chaos_smoke.sh     | scripts/bash/chaos_smoke.sh     | direct CLI usage                                                |
| scripts/repo_guard.sh      | scripts/bash/repo_guard.sh      | .github/workflows/ci-repo-guards.yml                            |
| scripts/rebuild.sh         | scripts/bash/rebuild.sh         | direct CLI usage                                                |

## Repo scripts (PowerShell)

| From                                      | To                                                   | Callers                                                         |
| ----------------------------------------- | ---------------------------------------------------- | --------------------------------------------------------------- |
| scripts/start.ps1                         | scripts/powershell/start.ps1                         | README.md                                                       |
| scripts/stop.ps1                          | scripts/powershell/stop.ps1                          | direct CLI usage                                                |
| scripts/restart.ps1                       | scripts/powershell/restart.ps1                       | direct CLI usage                                                |
| scripts/logs.ps1                          | scripts/powershell/logs.ps1                          | README.md                                                       |
| scripts/test.ps1                          | scripts/powershell/test.ps1                          | README.md, docs/TESTING.md                                      |
| scripts/setup.ps1                         | scripts/powershell/setup.ps1                         | README.md, digital_ocean/README.md, digital_ocean/quickstart.md |
| scripts/first-start.ps1                   | scripts/powershell/first-start.ps1                   | README.md, docs/GOLDEN_PATH.md                                  |
| scripts/install-python-deps.ps1           | scripts/powershell/install-python-deps.ps1           | scripts/first-start.ps1                                         |
| scripts/install-node-deps.ps1             | scripts/powershell/install-node-deps.ps1             | scripts/first-start.ps1                                         |
| scripts/bootstrap-venv.ps1                | scripts/powershell/bootstrap-venv.ps1                | scripts/first-start.ps1                                         |
| scripts/generate-traefik-auth.ps1         | scripts/powershell/generate-traefik-auth.ps1         | direct CLI usage                                                |
| scripts/lint.ps1                          | scripts/powershell/lint.ps1                          | direct CLI usage                                                |
| scripts/fmt.ps1                           | scripts/powershell/fmt.ps1                           | direct CLI usage                                                |
| scripts/reset.ps1                         | scripts/powershell/reset.ps1                         | direct CLI usage                                                |
| scripts/migrate.ps1                       | scripts/powershell/migrate.ps1                       | direct CLI usage                                                |
| scripts/seed.ps1                          | scripts/powershell/seed.ps1                          | direct CLI usage                                                |
| scripts/spec_kit_update.ps1               | scripts/powershell/spec_kit_update.ps1               | direct CLI usage                                                |
| scripts/update-flower-allowlist.ps1       | scripts/powershell/update-flower-allowlist.ps1       | direct CLI usage                                                |
| scripts/update-django-admin-allowlist.ps1 | scripts/powershell/update-django-admin-allowlist.ps1 | direct CLI usage                                                |

## Repo scripts (Python)

| From                      | To                               | Callers          |
| ------------------------- | -------------------------------- | ---------------- |
| scripts/contract_check.py | scripts/python/contract_check.py | direct CLI usage |
| scripts/perf_smoke.py     | scripts/python/perf_smoke.py     | direct CLI usage |
| scripts/slo_smoke.py      | scripts/python/slo_smoke.py      | direct CLI usage |

## Repo scripts (Node.js utilities remain in place)

| From                      | To                        | Callers                              |
| ------------------------- | ------------------------- | ------------------------------------ |
| scripts/setup.js          | scripts/setup.js          | scripts/setup.sh, scripts/setup.ps1  |
| scripts/complete-setup.js | scripts/complete-setup.js | package.json scripts: setup:complete |
| scripts/doctor.js         | scripts/doctor.js         | package.json scripts: doctor         |
| scripts/envRules.js       | scripts/envRules.js       | scripts/doctor.js                    |

## Spec-Kit scripts (no move)

| From                           | To                             | Callers            |
| ------------------------------ | ------------------------------ | ------------------ |
| .specify/scripts/bash/\*       | .specify/scripts/bash/\*       | spec-kit CLI usage |
| .specify/scripts/powershell/\* | .specify/scripts/powershell/\* | spec-kit CLI usage |

## DigitalOcean scripts (Bash)

| From                                          | To                                                 | Callers                                            |
| --------------------------------------------- | -------------------------------------------------- | -------------------------------------------------- |
| digital_ocean/scripts/digital_ocean_base.sh   | digital_ocean/scripts/bash/digital_ocean_base.sh   | digital_ocean/scripts/python/orchestrate_deploy.py |
| digital_ocean/scripts/post_reboot_complete.sh | digital_ocean/scripts/bash/post_reboot_complete.sh | digital_ocean/scripts/python/orchestrate_deploy.py |
| digital_ocean/scripts/teardown.sh             | digital_ocean/scripts/bash/teardown.sh             | direct CLI usage                                   |

## DigitalOcean scripts (PowerShell)

| From                                                          | To                                                            | Callers                                                  |
| ------------------------------------------------------------- | ------------------------------------------------------------- | -------------------------------------------------------- |
| digital_ocean/scripts/powershell/deploy.ps1                   | digital_ocean/scripts/powershell/deploy.ps1                   | docs/DEPLOY.md, docs/DEVELOPMENT.md, docs/GOLDEN_PATH.md |
| digital_ocean/scripts/powershell/test.ps1                     | digital_ocean/scripts/powershell/test.ps1                     | direct CLI usage                                         |
| digital_ocean/scripts/powershell/smoke-tests.ps1              | digital_ocean/scripts/powershell/smoke-tests.ps1              | direct CLI usage                                         |
| digital_ocean/scripts/powershell/validate-predeploy.ps1       | digital_ocean/scripts/powershell/validate-predeploy.ps1       | digital_ocean/scripts/powershell/deploy.ps1              |
| digital_ocean/scripts/powershell/update-pgadmin-allowlist.ps1 | digital_ocean/scripts/powershell/update-pgadmin-allowlist.ps1 | digital_ocean/scripts/powershell/deploy.ps1              |
| digital_ocean/scripts/powershell/add-ssh-key.ps1              | digital_ocean/scripts/powershell/add-ssh-key.ps1              | scripts/setup.ps1                                        |

## DigitalOcean scripts (Python)

| From                                               | To                                                   | Callers                                                                      |
| -------------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------- |
| digital_ocean/scripts/python/orchestrate_deploy.py | digital_ocean/scripts/python/orchestrate_deploy.py   | digital_ocean/scripts/powershell/deploy.ps1                                  |
| digital_ocean/scripts/python/validate_dns.py       | digital_ocean/scripts/python/validate_dns.py         | digital_ocean/scripts/powershell/deploy.ps1                                  |
| digital_ocean/deploy.py                            | digital_ocean/scripts/python/deploy.py               | digital_ocean/README.md, quickstart.md, digital_ocean/tests/test_deploy.py   |
| digital_ocean/info.py                              | digital_ocean/scripts/python/info.py                 | digital_ocean/README.md, quickstart.md, digital_ocean/tests/test_info.py     |
| digital_ocean/exec.py                              | digital_ocean/scripts/python/exec.py                 | digital_ocean/README.md, quickstart.md, digital_ocean/tests/test_exec.py     |
| digital_ocean/env_check.py                         | digital_ocean/scripts/python/env_check.py            | digital_ocean/tests/test_env_check.py                                        |
| digital_ocean/edit.py                              | digital_ocean/scripts/python/edit.py                 | digital_ocean/README.md, quickstart.md, digital_ocean/tests/test_edit.py     |
| digital_ocean/teardown.py                          | digital_ocean/scripts/python/teardown.py             | digital_ocean/README.md, quickstart.md, digital_ocean/tests/test_teardown.py |
| digital_ocean/orchestrate_teardown.py              | digital_ocean/scripts/python/orchestrate_teardown.py | direct CLI usage                                                             |
| digital_ocean/DO_ssh_keys.py                       | digital_ocean/scripts/python/DO_ssh_keys.py          | scripts/setup.ps1, digital_ocean/scripts/powershell/add-ssh-key.ps1          |
| digital_ocean/destroy_droplet.py                   | digital_ocean/scripts/python/destroy_droplet.py      | direct CLI usage                                                             |
| digital_ocean/do_logging.py                        | digital_ocean/scripts/python/do_logging.py           | digital_ocean/scripts/python/\*.py                                           |
| digital_ocean/logging.py                           | digital_ocean/scripts/python/logging.py              | digital_ocean/scripts/python/\*.py                                           |
