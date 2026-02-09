#!/bin/bash
# Synchronize literal configuration values with .env variables
# This script updates literal keys in YAML files to match .env values

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"

while [[ $# -gt 0 ]]; do
    case $1 in
        --compose-file|-c)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        --env-file|-e)
            ENV_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ./scripts/sync-env.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --compose-file FILE  Use a specific compose file"
            echo "  -e, --env-file FILE      Use a specific env file"
            echo "  -h, --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: compose file not found: $COMPOSE_FILE"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  Warning: env file not found: $ENV_FILE"
    if [ -f .env.example ]; then
        echo "Creating $ENV_FILE from .env.example..."
        cp .env.example "$ENV_FILE"
    else
        echo "❌ Error: .env.example not found. Cannot create $ENV_FILE."
        exit 1
    fi
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Synchronizing configuration with .env variables...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Note: NETWORK_NAME is the single source of truth for the Compose network name."

# Load required variables from .env safely (ignore multiline values)
echo "📖 Loading environment variables..."

# Helper to read a single VAR from .env without exporting everything
get_env_var() {
    # Usage: get_env_var VAR_NAME
    # Reads the first matching VAR=value line, strips inline comments, preserves spaces in value
    local key="$1"
    local line
    line=$(grep -E "^${key}=" "$ENV_FILE" | head -n1 || true)
    if [ -n "$line" ]; then
        # Remove inline comments and trailing spaces
        line=$(echo "$line" | sed 's/ *#.*//' | sed 's/[[:space:]]*$//')
        echo "$line" | cut -d'=' -f2-
    fi
}

# Read only the variables we actually need
NETWORK_NAME="$(get_env_var NETWORK_NAME)"
TRAEFIK_DOCKER_NETWORK="$(get_env_var TRAEFIK_DOCKER_NETWORK)"

# Validate required variables
if [ -z "$NETWORK_NAME" ]; then
    echo "❌ Error: NETWORK_NAME not set in .env"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables loaded${NC}"
echo ""

CHANGES_MADE=false

# ============================================
# 1. Sync TRAEFIK_DOCKER_NETWORK with NETWORK_NAME in .env
# ============================================
echo "🔍 Checking .env consistency..."
echo "   - NETWORK_NAME will override TRAEFIK_DOCKER_NETWORK"
CURRENT_TRAEFIK_NETWORK="$TRAEFIK_DOCKER_NETWORK"

if [ "$CURRENT_TRAEFIK_NETWORK" != "$NETWORK_NAME" ]; then
    if grep -q "^TRAEFIK_DOCKER_NETWORK=" "$ENV_FILE"; then
        echo -e "${YELLOW}⚙️  Syncing TRAEFIK_DOCKER_NETWORK: $CURRENT_TRAEFIK_NETWORK → $NETWORK_NAME${NC}"

        # macOS compatible sed
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^TRAEFIK_DOCKER_NETWORK=.*/TRAEFIK_DOCKER_NETWORK=$NETWORK_NAME/" "$ENV_FILE"
        else
            sed -i "s/^TRAEFIK_DOCKER_NETWORK=.*/TRAEFIK_DOCKER_NETWORK=$NETWORK_NAME/" "$ENV_FILE"
        fi
    else
        echo -e "${YELLOW}⚙️  Setting TRAEFIK_DOCKER_NETWORK: (missing) → $NETWORK_NAME${NC}"
        printf "\nTRAEFIK_DOCKER_NETWORK=%s\n" "$NETWORK_NAME" >> "$ENV_FILE"
    fi

    echo -e "${GREEN}✅ Updated .env${NC}"
    CHANGES_MADE=true
else
    echo "✓ .env is consistent"
fi
echo ""

# ============================================
# 2. Update compose network references
# ============================================
echo "🔍 Checking compose network configuration in $COMPOSE_FILE..."

# The Compose network *key* is an internal identifier in the compose file.
# The Compose network *name* should be driven by NETWORK_NAME via: name: ${NETWORK_NAME}
TARGET_NETWORK_KEY="app_network"

# Detect the first network key under networks:
CURRENT_NETWORK=$(
  awk '
    /^networks:/{in_n=1; next}
    in_n && $0 ~ /^[[:space:]]{2}[A-Za-z0-9_-]+:/{
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/:.*/, "", line)
      print line
      exit
    }
  ' "$COMPOSE_FILE"
)

if [ -z "$CURRENT_NETWORK" ]; then
    echo -e "${YELLOW}⚠️  Warning: Could not detect a networks key in $COMPOSE_FILE${NC}"
elif [ "$CURRENT_NETWORK" != "$TARGET_NETWORK_KEY" ]; then
    echo -e "${YELLOW}⚙️  Updating network key: $CURRENT_NETWORK → $TARGET_NETWORK_KEY${NC}"

    # Create backup
    cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^  $CURRENT_NETWORK:/  $TARGET_NETWORK_KEY:/" "$COMPOSE_FILE"
        sed -i '' "s/- $CURRENT_NETWORK\$/- $TARGET_NETWORK_KEY/" "$COMPOSE_FILE"
    else
        sed -i "s/^  $CURRENT_NETWORK:/  $TARGET_NETWORK_KEY:/" "$COMPOSE_FILE"
        sed -i "s/- $CURRENT_NETWORK\$/- $TARGET_NETWORK_KEY/" "$COMPOSE_FILE"
    fi

    echo -e "${GREEN}✅ Updated compose network key${NC}"
    CHANGES_MADE=true

    rm -f "$COMPOSE_FILE.bak"
else
    echo "✓ compose network key is correct ($TARGET_NETWORK_KEY)"
fi

# Ensure the network's name is driven by NETWORK_NAME
ensure_network_name_driven_by_env() {
    local file="$COMPOSE_FILE"
    local tmp

    tmp="$(mktemp "${TMPDIR:-/tmp}/sync-env.local-docker.XXXXXX")"

    # Rewrite ONLY the root-level networks: -> TARGET_NETWORK_KEY: block to ensure
    # exactly one normalized `name: ${NETWORK_NAME}` line (idempotent, no duplicates).
    awk -v target="$TARGET_NETWORK_KEY" '
        BEGIN { in_root=0; in_target=0; name_written=0 }

        function emit_name() {
            if (!name_written) {
                print "    name: ${NETWORK_NAME}"
                name_written=1
            }
        }

        {
            # Enter/exit root-level networks block
            if (!in_root) {
                print $0
                if ($0 ~ /^networks:[[:space:]]*$/) { in_root=1 }
                next
            }

            # If we hit a new top-level key, root networks is over.
            if (!in_target && $0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*$/ && $0 !~ /^networks:/) {
                in_root=0
                print $0
                next
            }

            # Not in target network yet
            if (!in_target) {
                print $0
                if ($0 ~ ("^  " target ":[[:space:]]*$")) {
                    in_target=1
                    name_written=0
                }
                next
            }

            # In target block: if we hit the next network entry or a new top-level key,
            # ensure name exists before leaving the block.
            if ($0 ~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/ && $0 !~ ("^  " target ":")) {
                emit_name()
                in_target=0
                print $0
                next
            }
            if ($0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*$/ && $0 !~ /^networks:/) {
                emit_name()
                in_target=0
                in_root=0
                print $0
                next
            }

            # Normalize and dedupe any name: lines inside the target network block.
            if ($0 ~ /^[[:space:]]+name:[[:space:]]*/) {
                emit_name()
                next
            }

            print $0
        }

        END {
            if (in_target) {
                emit_name()
            }
        }
    ' "$file" > "$tmp"

    if ! cmp -s "$file" "$tmp"; then
        cp "$file" "${file}.bak"
        mv "$tmp" "$file"
        rm -f "${file}.bak"
        CHANGES_MADE=true
    else
        rm -f "$tmp"
    fi
}

ensure_network_name_driven_by_env

echo "✓ compose network name is driven by NETWORK_NAME"
echo ""

# Note: Removed automatic mutation of traefik/traefik.yml entrypoints.
# The dashboard is exposed via HTTPS Host rule in dynamic config.

# ============================================
# 4. Normalize basic-auth users to avoid double-escaping '$'
# ============================================
normalize_basic_users() {
    local key="$1"
    if grep -q "^${key}=" "$ENV_FILE"; then
        local original_line
        original_line=$(grep "^${key}=" "$ENV_FILE" | head -n1)
        local value
        value="${original_line#*=}"
        # Collapse any run of '$' to a single '$', then escape once for .env.
        local value_single
        value_single=$(printf '%s' "$value" | sed -E 's/\$+/\$/g')
        local value_escaped
        value_escaped=$(printf '%s' "$value_single" | sed 's/\$/$$/g')
        local sanitized_line
        sanitized_line="${key}=${value_escaped}"

        if [ "$original_line" != "$sanitized_line" ]; then
            echo -e "${YELLOW}⚙️  Normalizing ${key} dollar signs for Compose compatibility${NC}"
            awk -v orig="$original_line" -v repl="$sanitized_line" '
                BEGIN { done=0 }
                {
                    if (!done && index($0, orig) == 1) { print repl; done=1 }
                    else { print $0 }
                }
            ' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
            CHANGES_MADE=true
        fi
    fi
}

normalize_basic_users "TRAEFIK_DASH_BASIC_USERS"
normalize_basic_users "FLOWER_BASIC_USERS"

# ============================================
# Summary
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$CHANGES_MADE" = true ]; then
    echo -e "${GREEN}🎉 Synchronization complete! Changes were made.${NC}"
    echo ""
    echo "Current configuration:"
    echo "  - Network Name: $NETWORK_NAME"
    echo ""
    echo "💡 You should rebuild your containers for changes to take effect:"
    echo "   ./scripts/stop.sh && ./scripts/start.sh --build"
else
    echo -e "${GREEN}✅ All configuration is already synchronized!${NC}"
    echo ""
    echo "Current configuration:"
    echo "  - Network Name: $NETWORK_NAME"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

