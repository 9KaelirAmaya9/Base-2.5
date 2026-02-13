#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"

cd "$PROJECT_ROOT"

if [[ -d "$PROJECT_ROOT/react-app" ]]; then
  (cd "$PROJECT_ROOT/react-app" && npm run format)
fi

if [[ -x "$VENV_PYTHON" ]]; then
  "$VENV_PYTHON" -m ruff format .
else
  python -m ruff format .
fi
