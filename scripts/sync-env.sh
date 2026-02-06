#!/bin/bash
# Synchronize literal configuration values with .env variables
# This script updates literal keys in YAML files to match .env values

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Synchronizing configuration with .env variables...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Note: NETWORK_NAME is the single source of truth for the Compose network name."

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  Warning: .env file not found${NC}"
    if [ -f .env.example ]; then
        echo "Creating .env from .env.example..."
        cp .env.example .env
        echo -e "${GREEN}✅ Created .env file${NC}"
    else
        echo "❌ Error: No .env or .env.example found"
        exit 1
    fi
fi

# Load required variables from .env safely (ignore multiline values)
echo "📖 Loading environment variables..."

# Helper to read a single VAR from .env without exporting everything
get_env_var() {
    # Usage: get_env_var VAR_NAME
    # Reads the first matching VAR=value line, strips inline comments, preserves spaces in value
    local key="$1"
    local line
    line=$(grep -E "^${key}=" .env | head -n1 || true)
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
    if grep -q "^TRAEFIK_DOCKER_NETWORK=" .env; then
        echo -e "${YELLOW}⚙️  Syncing TRAEFIK_DOCKER_NETWORK: $CURRENT_TRAEFIK_NETWORK → $NETWORK_NAME${NC}"

        # macOS compatible sed
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^TRAEFIK_DOCKER_NETWORK=.*/TRAEFIK_DOCKER_NETWORK=$NETWORK_NAME/" .env
        else
            sed -i "s/^TRAEFIK_DOCKER_NETWORK=.*/TRAEFIK_DOCKER_NETWORK=$NETWORK_NAME/" .env
        fi
    else
        echo -e "${YELLOW}⚙️  Setting TRAEFIK_DOCKER_NETWORK: (missing) → $NETWORK_NAME${NC}"
        printf "\nTRAEFIK_DOCKER_NETWORK=%s\n" "$NETWORK_NAME" >> .env
    fi

    echo -e "${GREEN}✅ Updated .env${NC}"
    CHANGES_MADE=true
else
    echo "✓ .env is consistent"
fi
echo ""

# ============================================
# 2. Update local.docker.yml network references
# ============================================
echo "🔍 Checking local.docker.yml network configuration..."

# The Compose network *key* is an internal identifier in local.docker.yml.
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
  ' local.docker.yml
)

if [ -z "$CURRENT_NETWORK" ]; then
    echo -e "${YELLOW}⚠️  Warning: Could not detect a networks key in local.docker.yml${NC}"
elif [ "$CURRENT_NETWORK" != "$TARGET_NETWORK_KEY" ]; then
    echo -e "${YELLOW}⚙️  Updating network key: $CURRENT_NETWORK → $TARGET_NETWORK_KEY${NC}"

    # Create backup
    cp local.docker.yml local.docker.yml.bak

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^  $CURRENT_NETWORK:/  $TARGET_NETWORK_KEY:/" local.docker.yml
        sed -i '' "s/- $CURRENT_NETWORK\$/- $TARGET_NETWORK_KEY/" local.docker.yml
    else
        sed -i "s/^  $CURRENT_NETWORK:/  $TARGET_NETWORK_KEY:/" local.docker.yml
        sed -i "s/- $CURRENT_NETWORK\$/- $TARGET_NETWORK_KEY/" local.docker.yml
    fi

    echo -e "${GREEN}✅ Updated local.docker.yml network key${NC}"
    CHANGES_MADE=true

    rm -f local.docker.yml.bak
else
    echo "✓ local.docker.yml network key is correct ($TARGET_NETWORK_KEY)"
fi

# Ensure the network's name is driven by NETWORK_NAME
# Note: grep -E does not support "\s"; use POSIX character classes.
if ! grep -qE "^    name: \$\{NETWORK_NAME\}[[:space:]]*$" local.docker.yml; then
    echo -e "${YELLOW}⚙️  Ensuring networks.$TARGET_NETWORK_KEY uses name: \${NETWORK_NAME}${NC}"
    cp local.docker.yml local.docker.yml.bak
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^  ${TARGET_NETWORK_KEY}:/,/^[^ ]/ s/^    name: .*/    name: \${NETWORK_NAME}/" local.docker.yml
    else
        sed -i "/^  ${TARGET_NETWORK_KEY}:/,/^[^ ]/ s/^    name: .*/    name: \${NETWORK_NAME}/" local.docker.yml
    fi

    # If the block had no name: line to begin with, insert one immediately after the key.
    if ! grep -qE "^    name: \$\{NETWORK_NAME\}[[:space:]]*$" local.docker.yml; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^  ${TARGET_NETWORK_KEY}:/a\\
    name: \${NETWORK_NAME}
" local.docker.yml
        else
            sed -i "/^  ${TARGET_NETWORK_KEY}:/a\\
    name: \${NETWORK_NAME}
" local.docker.yml
        fi
    fi

    CHANGES_MADE=true
    rm -f local.docker.yml.bak
fi

echo "✓ local.docker.yml network name is driven by NETWORK_NAME"
echo ""

# Note: Removed automatic mutation of traefik/traefik.yml entrypoints.
# The dashboard is exposed via HTTPS Host rule in dynamic config.

# ============================================
# 4. Sanitize Traefik dashboard basic-auth user list to escape $ in bcrypt hash
# ============================================
if grep -q "^TRAEFIK_DASH_BASIC_USERS=" .env; then
    ORIGINAL_LINE=$(grep "^TRAEFIK_DASH_BASIC_USERS=" .env | head -n1)
    SANITIZED_LINE=$(echo "$ORIGINAL_LINE" | sed 's/\$/$$/g')
    if [ "$ORIGINAL_LINE" != "$SANITIZED_LINE" ]; then
        echo -e "${YELLOW}⚙️  Escaping dollar signs in TRAEFIK_DASH_BASIC_USERS for Compose compatibility${NC}"
        awk -v orig="$ORIGINAL_LINE" -v repl="$SANITIZED_LINE" '
            BEGIN { done=0 }
            {
                if (!done && index($0, orig) == 1) { print repl; done=1 }
                else { print $0 }
            }
        ' .env > .env.tmp && mv .env.tmp .env
        CHANGES_MADE=true
    fi
fi

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
