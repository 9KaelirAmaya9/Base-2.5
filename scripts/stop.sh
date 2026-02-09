#!/bin/bash
# Stop all Docker services

set -e

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# ==========================================
# Stop Script
# Usage: ./stop.sh [OPTIONS]
# Options:
#   -v, --volumes     Remove volumes (WARNING: deletes data)
#   -h, --help        Show this help message
#   --self-test       Run script self-test and exit
# ==========================================

echo "🛑 Stopping Docker Environment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse command line arguments
REMOVE_VOLUMES=false
SELF_TEST=false

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
        --volumes|-v)
            REMOVE_VOLUMES=true
            shift
            ;;
        --self-test)
            SELF_TEST=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./stop.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --compose-file FILE  Use a specific compose file"
            echo "  -e, --env-file FILE      Use a specific env file"
            echo "  -v, --volumes     Remove volumes (WARNING: deletes data)"
            echo "  --self-test       Run script self-test and exit"
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
    echo "❌ Error: env file not found: $ENV_FILE"
    exit 1
fi

# Self-test function
if [ "$SELF_TEST" = true ]; then
    echo "🔎 Running stop.sh self-test..."
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
    echo "✅ Self-test passed."
    exit 0
fi

# Stop services
if [ "$REMOVE_VOLUMES" = true ]; then
    echo "⚠️  WARNING: This will remove all volumes and delete data!"
    read -p "Are you sure? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "🗑️  Stopping services and removing volumes..."
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down -v
        echo "✅ Services stopped and volumes removed"
    else
        echo "❌ Operation cancelled"
        exit 1
    fi
else
    echo "🐳 Stopping services..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down
    echo "✅ Services stopped successfully"
fi

echo ""
echo "💡 Start services again: ./scripts/start.sh"

