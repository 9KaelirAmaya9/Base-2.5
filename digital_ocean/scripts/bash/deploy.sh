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
LOCAL_TESTS=false
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
  --all-tests         Enable extended remote verification (celery check)
  --local-tests       Run local test suite after deploy
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
    --local-tests)
      LOCAL_TESTS=true
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
if $LOCAL_TESTS; then
  args+=("--local-tests")
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

extract_ip_from_json() {
  local json_path="$1"
  if [[ -z "$json_path" || ! -f "$json_path" ]]; then
    return 1
  fi
  "$PYTHON" - <<'PY' "$json_path" 2>/dev/null || true
import json
import sys

path = sys.argv[1]
try:
  with open(path, encoding='utf-8') as fh:
    data = json.load(fh) or {}
except Exception:
  data = {}

ip = data.get('ip_address') or ''
if isinstance(ip, str):
  print(ip)
PY
}

finalize_artifact_dir_name() {
  if [[ -z "${DEPLOY_ARTIFACT_DIR:-}" ]]; then
    return 0
  fi

  local current="$DEPLOY_ARTIFACT_DIR"
  local leaf
  leaf="$(basename "$current")"
  if [[ "$leaf" != unknown-* ]]; then
    return 0
  fi

  local stamp
  stamp="${leaf#unknown-}"

  local ip=""
  ip="$(extract_ip_from_json "$current/DO_userdata.json" | head -n 1)"
  if [[ -z "$ip" ]]; then
    ip="$(extract_ip_from_json "$current/deploy-meta.json" | head -n 1)"
  fi
  if [[ -z "$ip" ]]; then
    return 0
  fi

  local target
  target="$(dirname "$current")/${ip}-${stamp}"
  if [[ "$target" == "$current" || -e "$target" ]]; then
    return 0
  fi

  if mv "$current" "$target" 2>/dev/null; then
    export DEPLOY_ARTIFACT_DIR="$target"
    return 0
  fi

  mkdir -p "$target" || return 0
  if cp -a "$current"/. "$target"/ 2>/dev/null; then
    printf 'Original artifact path: %s\n' "$current" > "$target/artifact-alias.txt" 2>/dev/null || true
    export DEPLOY_ARTIFACT_DIR="$target"
    rm -rf "$current" 2>/dev/null || true
  fi

  if [[ -f "$target/artifact-alias.txt" ]]; then
    original_path=$(sed -n 's/^Original artifact path: //p' "$target/artifact-alias.txt" | head -n 1)
    if [[ -n "$original_path" && -d "$original_path" ]]; then
      rm -rf "$original_path" 2>/dev/null || true
    fi
  fi
}

"$PYTHON" "$script_path" "${args[@]}"
status=$?
finalize_artifact_dir_name
exit $status
