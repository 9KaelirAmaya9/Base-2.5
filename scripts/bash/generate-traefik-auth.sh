#!/usr/bin/env bash
set -euo pipefail

USERNAME=""
PASSWORD=""
ALGORITHM="apr1"
MAX_RETRIES=5

usage() {
  cat <<'EOF'
Usage: ./scripts/bash/generate-traefik-auth.sh [options]

Options:
  --username VALUE     Username for htpasswd
  --password VALUE     Password for htpasswd
  --algorithm VALUE    apr1 or bcrypt (default: apr1)
  --max-retries N      Number of attempts (default: 5)
  --help, -h           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username)
      USERNAME="$2"
      shift 2
      ;;
    --password)
      PASSWORD="$2"
      shift 2
      ;;
    --algorithm)
      ALGORITHM="$2"
      shift 2
      ;;
    --max-retries)
      MAX_RETRIES="$2"
      shift 2
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

if [[ -z "$USERNAME" ]]; then
  read -r -p "Enter username: " USERNAME
fi

if [[ -z "$PASSWORD" ]]; then
  read -r -s -p "Enter password: " PASSWORD
  echo ""
fi

if [[ "$USERNAME" =~ [[:space:]] || "$USERNAME" == *:* ]]; then
  echo "Username must not contain spaces or colons." >&2
  exit 1
fi
if [[ -z "$PASSWORD" ]]; then
  echo "Password cannot be empty." >&2
  exit 1
fi

get_apr1() {
  if command -v docker >/dev/null 2>&1; then
    docker run --rm httpd:2.4-alpine htpasswd -nbm "$USERNAME" "$PASSWORD" 2>/dev/null | head -n1
    return 0
  fi
  return 1
}

get_apr1_fallback() {
  if command -v openssl >/dev/null 2>&1; then
    local salt
    salt=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 8)
    local digest
    digest=$(openssl passwd -apr1 -salt "$salt" "$PASSWORD" 2>/dev/null || true)
    if [[ -n "$digest" ]]; then
      echo "${USERNAME}:${digest}"
      return 0
    fi
  fi
  return 1
}

get_bcrypt() {
  if command -v node >/dev/null 2>&1; then
    node -e "const bcrypt = require('bcrypt'); bcrypt.hash(process.argv[2], 10).then(h => console.log(process.argv[1]+':'+h)).catch(() => process.exit(1));" "$USERNAME" "$PASSWORD"
    return $?
  fi
  return 1
}

escape_for_env() {
  local raw="$1"
  echo "${raw//\$/\$\$}"
}

is_safe() {
  local raw="$1"
  local escaped="$2"

  if [[ "$ALGORITHM" == "apr1" && ! "$raw" =~ \$apr1\$ ]]; then
    return 1
  fi
  if [[ "$ALGORITHM" == "bcrypt" && ! "$raw" =~ \$2[aby]\$ ]]; then
    return 1
  fi
  if echo "$escaped" | grep -qE '(?<!\$)\$(?!\$)'; then
    return 1
  fi
  if echo "$raw" | grep -qE '[[:space:]]'; then
    return 1
  fi
  if ! echo "$raw" | grep -qE '^[^:]+:.+$'; then
    return 1
  fi
  local hash
  hash="${raw#*:}"
  if ! echo "$hash" | grep -qE '^[A-Za-z0-9./$]+$'; then
    return 1
  fi
  return 0
}

attempt=0
while [[ $attempt -lt $MAX_RETRIES ]]; do
  attempt=$((attempt + 1))
  raw=""
  if [[ "$ALGORITHM" == "apr1" ]]; then
    raw=$(get_apr1 || true)
    if [[ -z "$raw" ]]; then
      raw=$(get_apr1_fallback || true)
    fi
  elif [[ "$ALGORITHM" == "bcrypt" ]]; then
    raw=$(get_bcrypt || true)
  else
    echo "Unsupported algorithm: $ALGORITHM" >&2
    exit 1
  fi

  if [[ -z "$raw" ]]; then
    echo "Attempt $attempt failed to generate hash." >&2
    continue
  fi

  escaped=$(escape_for_env "$raw")
  if is_safe "$raw" "$escaped"; then
    echo ""
    echo "Raw htpasswd:"
    echo "  $raw"
    echo ""
    echo "Env-safe line for .env:"
    echo "  TRAEFIK_DASH_BASIC_USERS=$escaped"
    echo ""
    echo "Copy the env-safe line into your .env and redeploy."
    exit 0
  fi

  echo "Generated value failed safety checks. Retrying ($attempt/$MAX_RETRIES)..." >&2
 done

echo "Unable to generate a safe htpasswd entry after $MAX_RETRIES attempts." >&2
exit 2
