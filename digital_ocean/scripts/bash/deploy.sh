#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PYTHON="${PYTHON:-python}"

DRY_RUN=false
UPDATE_ONLY=false
FULL=false
CREATE_IF_MISSING=false
ALL_TESTS=false
ENV_PATH=""
LOGS_DIR=""
TIMESTAMPED=false

usage() {
  cat <<'EOF'
Usage: ./digital_ocean/scripts/bash/deploy.sh [options]

Options:
  --dry-run           Print actions without making changes
  --update-only       Skip droplet creation; update existing droplet
  --create-if-missing Create droplet if update-only target is missing
  --all-tests         Run full post-deploy verification suite
  --full              Force full deploy (default when neither flag is set)
  --env-path <path>   Path to .env (sets ENV_PATH for orchestrate_deploy.py)
  --logs-dir <path>   Artifact directory (sets DEPLOY_ARTIFACT_DIR)
  --timestamped       Append timestamp to logs dir
  --help, -h          Show this help

Notes:
  - This is the Bash MVP entrypoint. It routes through orchestrate_deploy.py.
  - For full option parity, use the PowerShell deploy script.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --update-only)
      UPDATE_ONLY=true
      shift
      ;;
    --create-if-missing)
      CREATE_IF_MISSING=true
      shift
      ;;
    --all-tests)
      ALL_TESTS=true
      shift
      ;;
    --full)
      FULL=true
      shift
      ;;
    --env-path)
      ENV_PATH="$2"
      shift 2
      ;;
    --logs-dir)
      LOGS_DIR="$2"
      shift 2
      ;;
    --timestamped)
      TIMESTAMPED=true
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

if $UPDATE_ONLY && $FULL; then
  echo "ERROR: --update-only and --full are mutually exclusive." >&2
  exit 1
fi

if [[ -n "$ENV_PATH" ]]; then
  export ENV_PATH="$ENV_PATH"
fi

if [[ -n "$LOGS_DIR" ]]; then
  if $TIMESTAMPED; then
    stamp=$(date -u +%Y%m%d_%H%M%S)
    LOGS_DIR="$LOGS_DIR/unknown-$stamp"
  fi
  mkdir -p "$LOGS_DIR"
  export DEPLOY_ARTIFACT_DIR="$LOGS_DIR"
elif $TIMESTAMPED; then
  stamp=$(date -u +%Y%m%d_%H%M%S)
  LOGS_DIR="$REPO_ROOT/local_run_logs/unknown-$stamp"
  mkdir -p "$LOGS_DIR"
  export DEPLOY_ARTIFACT_DIR="$LOGS_DIR"
fi

abs_path() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo ""
    return
  fi
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target"
    return
  fi
  if [[ -d "$target" ]]; then
    (cd "$target" && pwd)
    return
  fi
  local dir
  dir="$(dirname "$target")"
  local base
  base="$(basename "$target")"
  (cd "$dir" && printf "%s/%s" "$(pwd)" "$base")
}

args=()
if $DRY_RUN; then
  args+=("--dry-run")
fi
if $UPDATE_ONLY; then
  args+=("--update-only")
fi
if $CREATE_IF_MISSING; then
  args+=("--create-if-missing")
fi
if $ALL_TESTS; then
  args+=("--all-tests")
fi

script_path="$REPO_ROOT/digital_ocean/scripts/python/orchestrate_deploy.py"

if [[ "$PYTHON" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
  if [[ -n "${ENV_PATH:-}" ]]; then
    ENV_PATH="$(abs_path "$ENV_PATH")"
    export ENV_PATH
  fi
  if [[ -n "${DEPLOY_ARTIFACT_DIR:-}" ]]; then
    DEPLOY_ARTIFACT_DIR="$(abs_path "$DEPLOY_ARTIFACT_DIR")"
    export DEPLOY_ARTIFACT_DIR
  fi
  if [[ -n "${WSLENV:-}" ]]; then
    WSLENV="$WSLENV:ENV_PATH/p:DEPLOY_ARTIFACT_DIR/p"
  else
    WSLENV="ENV_PATH/p:DEPLOY_ARTIFACT_DIR/p"
  fi
  export WSLENV
  script_path="$(wslpath -w "$script_path")"
fi
exec "$PYTHON" "$script_path" "${args[@]}"
