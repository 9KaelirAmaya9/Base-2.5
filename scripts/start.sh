#!/bin/bash
# Start all Docker services

set -e

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Platform compatibility note
echo "ℹ️  This script requires Bash and is tested on Mac, Linux, and Windows (WSL/Git Bash)."
echo "   For Windows, use WSL or Git Bash for best results."

# Docker Compose version check
REQUIRED_COMPOSE_VERSION="2.0.0"
COMPOSE_VERSION=$(docker-compose version --short 2>/dev/null || echo "")
if [ -z "$COMPOSE_VERSION" ]; then
    echo "⚠️  Docker Compose not found. Please install Docker Compose v$REQUIRED_COMPOSE_VERSION or newer."
    exit 1
fi
if [ "$(printf '%s\n' "$REQUIRED_COMPOSE_VERSION" "$COMPOSE_VERSION" | sort -V | head -n1)" != "$REQUIRED_COMPOSE_VERSION" ]; then
    echo "⚠️  Docker Compose version $COMPOSE_VERSION detected. v$REQUIRED_COMPOSE_VERSION or newer is required."
    exit 1
fi

echo "🚀 Starting Docker Environment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if env file exists and validate required variables
if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  Warning: env file not found: $ENV_FILE. Creating from .env.example..."
    if [ -f .env.example ]; then
        cp .env.example "$ENV_FILE"
        echo "✅ Created $ENV_FILE. Please review and update it if needed."
    else
        echo "❌ Error: .env.example not found. Cannot create $ENV_FILE."
        exit 1
    fi
fi

# Validate required .env variables relevant to this stack
# Keep concise: domain and core service ports/credentials
REQUIRED_VARS=(WEBSITE_DOMAIN NETWORK_NAME TRAEFIK_PORT FASTAPI_PORT DJANGO_PORT POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB)
for VAR in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^$VAR=" "$ENV_FILE"; then
        echo "❌ Error: Required environment variable $VAR is missing in .env."
        exit 1
    fi
done

# Parse command line arguments
BUILD=false
DETACHED=true
SELF_TEST=false
FOLLOW_LOGS=false

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
        --build|-b)
            BUILD=true
            shift
            ;;
        --foreground|-f)
            DETACHED=false
            shift
            ;;
        --self-test)
            SELF_TEST=true
            shift
            ;;
        --follow-logs)
            FOLLOW_LOGS=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./start.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --compose-file FILE  Use a specific compose file"
            echo "  -e, --env-file FILE      Use a specific env file"
            echo "  -b, --build       Rebuild images before starting"
            echo "  -f, --foreground  Run in foreground (don't detach)"
            echo "  --self-test       Run script self-test and exit"
            echo "  --follow-logs     After up -d, follow service logs briefly"
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

# Synchronize configuration with .env before starting
echo "🔄 Synchronizing configuration..."
if [ -f "$SCRIPT_DIR/sync-env.sh" ]; then
    "$SCRIPT_DIR/sync-env.sh" --compose-file "$COMPOSE_FILE" --env-file "$ENV_FILE"
    echo ""
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: compose file not found: $COMPOSE_FILE"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: env file not found: $ENV_FILE"
    exit 1
fi

# Self-test function
if [ "$SELF_TEST" = true ]; then
    echo "🔎 Running start.sh self-test..."
    # Check Docker
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker not found."
        exit 1
    fi
    # Check Docker Compose
    if ! command -v docker-compose &>/dev/null; then
        echo "❌ Docker Compose not found."
        exit 1
    fi
    # Check .env
    if [ ! -f "$ENV_FILE" ]; then
        echo "❌ .env file missing."
        exit 1
    fi
    # Check required variables
    for VAR in "${REQUIRED_VARS[@]}"; do
        if ! grep -q "^$VAR=" "$ENV_FILE"; then
            echo "❌ Required variable $VAR missing in .env."
            exit 1
        fi
    done
    echo "✅ Self-test passed."
    exit 0
fi

# Ensure Traefik ACME storage exists and is writable by the Traefik user.
ACME_DIR="$PROJECT_DIR/letsencrypt"
mkdir -p "$ACME_DIR"
touch "$ACME_DIR/acme.json" "$ACME_DIR/acme-staging.json"
chmod 600 "$ACME_DIR/acme.json" "$ACME_DIR/acme-staging.json" || true
chmod 700 "$ACME_DIR" || true
chown -R 1000:1000 "$ACME_DIR" || true

# Build if requested
if [ "$BUILD" = true ]; then
    echo "🔨 Building services..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" build
fi

# Start services
if [ "$DETACHED" = true ]; then
    echo "🐳 Starting services in detached mode..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
    
    echo ""
    echo "✅ Services started successfully!"
    echo ""
    echo "📊 Service Status:"
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
    
    echo ""
    echo "🌐 Access services at:"
    # Load env for dynamic endpoints
    if [ -f "$ENV_FILE" ]; then
        # shellcheck disable=SC2046
        export $(grep -E '^(WEBSITE_DOMAIN)=' "$ENV_FILE" | xargs)
    fi
    WEBSITE_DOMAIN_PRINT=${WEBSITE_DOMAIN:-localhost}
    echo "  - Frontend (HTTP via Traefik):  http://localhost"
    echo "  - Frontend (HTTPS via Traefik): https://${WEBSITE_DOMAIN_PRINT} (staging cert)"
    echo "  - API (via Traefik):            https://${WEBSITE_DOMAIN_PRINT}/api"
    echo "  - PostgreSQL:                   internal-only"
    echo "  - pgAdmin:                      internal-only"
    echo "  - Traefik Dashboard:            disabled insecure access"
    echo ""
    echo "💡 View logs: ./scripts/logs.sh"

    # Optionally follow logs for a short window (useful for orchestrated deploys)
    if [ "$FOLLOW_LOGS" = true ] || [ "${START_FOLLOW_LOGS:-}" = "true" ]; then
        DURATION=${POST_DEPLOY_LOGS_FOLLOW_SECONDS:-60}
        echo "\n🔎 Following logs for ${DURATION}s (traefik, api, django, nginx, pgadmin)..."
        # Use timeout to avoid hanging forever; fallback if timeout is not available
        if command -v timeout >/dev/null 2>&1; then
            timeout "$DURATION" docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs -f --tail=100 traefik api django nginx pgadmin || true
        else
            # Portable fallback: run in background and kill after duration
            ( docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs -f --tail=100 traefik api django nginx pgadmin & LOG_PID=$!; \
              sleep "$DURATION"; \
              kill "$LOG_PID" 2>/dev/null || true )
        fi
    fi
else
    echo "🐳 Starting services in foreground mode..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up
fi

