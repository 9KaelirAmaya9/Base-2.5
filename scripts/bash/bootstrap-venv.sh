#!/usr/bin/env bash
set -euo pipefail

FORCE=false

usage() {
  cat <<'EOF'
Usage: ./scripts/bash/bootstrap-venv.sh [--force]

Options:
  --force, -f   Recreate the .venv even if it exists
  --help, -h    Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f)
      FORCE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PYTHON_CMD=""
if command -v python >/dev/null 2>&1; then
  PYTHON_CMD="python"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
else
  echo "python executable not found in PATH. Install Python 3.12+ and retry." >&2
  exit 1
fi

VENV_DIR="$REPO_ROOT/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"

if $FORCE && [[ -d "$VENV_DIR" ]]; then
  rm -rf "$VENV_DIR"
fi

if [[ -x "$VENV_PYTHON" ]]; then
  echo "Existing Python virtual environment detected."
else
  echo "Creating Python virtual environment (.venv)..."
  "$PYTHON_CMD" -m venv "$VENV_DIR"
fi

echo "Virtual environment ready at: $VENV_PYTHON"
