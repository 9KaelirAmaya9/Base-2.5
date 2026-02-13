#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  echo "Virtual environment not active. Run ./scripts/bash/first-start.sh to activate .venv before installing Node dependencies." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node executable not found in PATH. Install Node.js 18+ and retry." >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm executable not found in PATH. Install npm 9+ and retry." >&2
  exit 1
fi

get_major() {
  local version="$1"
  version="${version#v}"
  echo "$version" | cut -d. -f1
}

node_major="$(get_major "$(node --version)")"
if [[ -z "$node_major" || "$node_major" -lt 18 ]]; then
  echo "Node.js major version 18+ is required but found ${node_major:-unknown}." >&2
  exit 1
fi

npm_major="$(get_major "$(npm --version)")"
if [[ -z "$npm_major" || "$npm_major" -lt 9 ]]; then
  echo "npm version 9+ required but found ${npm_major:-unknown}." >&2
  exit 1
fi

echo "Node version: $(node --version); npm version: $(npm --version)"

doinstall() {
  local dir="$1"
  local label="$2"
  local allow_legacy="$3"

  pushd "$dir" >/dev/null
  if ! npm install --no-fund; then
    if [[ "$allow_legacy" == "true" ]]; then
      echo "npm install ($label) failed; retrying with --legacy-peer-deps."
      npm install --no-fund --legacy-peer-deps
    else
      popd >/dev/null
      return 1
    fi
  fi
  popd >/dev/null
}

echo "Installing npm dependencies in repo root..."
doinstall "$REPO_ROOT" "repo root" "false"

for sub in react-app e2e; do
  if [[ -f "$REPO_ROOT/$sub/package.json" ]]; then
    echo "Installing npm dependencies in $sub..."
    allow_legacy="false"
    if [[ "$sub" == "react-app" ]]; then
      allow_legacy="true"
    fi
    doinstall "$REPO_ROOT/$sub" "$sub" "$allow_legacy"
  fi
 done

echo "Node dependencies installed successfully."
