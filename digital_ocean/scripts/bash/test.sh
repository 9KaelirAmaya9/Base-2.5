#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PYTHON="${PYTHON:-python}"

DRY_RUN=false
CREATE_IF_MISSING=false
ALL_TESTS=false
LOCAL_TESTS=false
ENV_PATH=""
LOGS_DIR=""
TIMESTAMPED=false

usage() {
  cat <<'EOF'
Usage: ./digital_ocean/scripts/bash/test.sh [options]

Options:
  --dry-run           Print actions without making changes
  --create-if-missing Create droplet if update-only target is missing
  --all-tests         Enable extended remote verification (celery check)
  --local-tests       Run local test suite after deploy
  --env-path <path>   Path to .env (sets ENV_PATH for orchestrate_deploy.py)
  --logs-dir <path>   Artifact directory (sets DEPLOY_ARTIFACT_DIR)
  --timestamped       Append timestamp to logs dir
  --help, -h          Show this help

Notes:
  - This is the Bash MVP test entrypoint. It runs update-only workflow.
  - For full option parity, use the PowerShell test script.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
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
    --local-tests)
      LOCAL_TESTS=true
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

if [[ -n "$ENV_PATH" ]]; then
  export ENV_PATH="$ENV_PATH"
fi

export DEPLOY_TEST_RUNNER="bash"

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

args=("--update-only")
if $DRY_RUN; then
  args+=("--dry-run")
fi
if $CREATE_IF_MISSING; then
  args+=("--create-if-missing")
fi
if $ALL_TESTS; then
  args+=("--all-tests")
fi
if $LOCAL_TESTS; then
  args+=("--local-tests")
fi

script_path="$REPO_ROOT/digital_ocean/scripts/python/orchestrate_deploy.py"

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

echo "[INFO] REPO_ROOT=$REPO_ROOT"
echo "[INFO] PYTHON=$PYTHON"
echo "[INFO] SCRIPT_PATH=$script_path"
echo "[INFO] ARGS=${args[*]}"
if [[ -n "${ENV_PATH:-}" ]]; then
  echo "[INFO] ENV_PATH=$ENV_PATH"
fi
if [[ -n "${DEPLOY_ARTIFACT_DIR:-}" ]]; then
  echo "[INFO] DEPLOY_ARTIFACT_DIR=$DEPLOY_ARTIFACT_DIR"
fi

exec "$PYTHON" "$script_path" "${args[@]}"
