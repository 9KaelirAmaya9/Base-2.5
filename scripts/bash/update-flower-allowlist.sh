#!/usr/bin/env bash
set -euo pipefail

ENV_PATH=""
IP=""
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./scripts/bash/update-flower-allowlist.sh [options]

Options:
  --env-path PATH   Path to .env (default: repo root .env)
  --ip ADDRESS      Use a specific public IPv4
  --dry-run         Print intended change without writing
  --help, -h        Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-path)
      ENV_PATH="$2"
      shift 2
      ;;
    --ip)
      IP="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
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

if [[ -z "$ENV_PATH" ]]; then
  ENV_PATH="$REPO_ROOT/.env"
fi

if [[ ! -f "$ENV_PATH" ]]; then
  echo "Could not find .env at: $ENV_PATH" >&2
  exit 1
fi

get_public_ipv4() {
  local ip
  ip=$(curl -fsS 'https://api.ipify.org?format=json' | sed -n 's/.*"ip"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || true)
  if [[ -n "$ip" ]]; then
    echo "$ip"
    return 0
  fi
  ip=$(curl -fsS 'https://ifconfig.me/ip' || true)
  if [[ -n "$ip" ]]; then
    echo "${ip//[[:space:]]/}"
    return 0
  fi
  return 1
}

is_ipv4() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

use_ip="$IP"
if [[ -z "$use_ip" ]]; then
  use_ip=$(get_public_ipv4 || true)
  if [[ -z "$use_ip" ]]; then
    echo "Failed to detect public IPv4. Provide --ip <addr>." >&2
    exit 1
  fi
fi

if ! is_ipv4 "$use_ip"; then
  echo "Provided IP is not a valid IPv4 address: $use_ip" >&2
  exit 1
fi

cidr="$use_ip/32"

if $DRY_RUN; then
  echo "[DryRun] Would write FLOWER_ALLOWLIST=$cidr"
  exit 0
fi

tmp_file=$(mktemp)
if [[ -f "$ENV_PATH" ]]; then
  grep -v '^FLOWER_ALLOWLIST=' "$ENV_PATH" > "$tmp_file" || true
fi
printf 'FLOWER_ALLOWLIST=%s\n' "$cidr" >> "$tmp_file"
mv "$tmp_file" "$ENV_PATH"

if grep -q '^FLOWER_ALLOWLIST=' "$ENV_PATH"; then
  echo "Updated: FLOWER_ALLOWLIST=$cidr"
  echo "Done. Restart Traefik to apply: docker compose up -d --force-recreate traefik"
else
  echo "Failed to confirm FLOWER_ALLOWLIST write." >&2
  exit 1
fi
