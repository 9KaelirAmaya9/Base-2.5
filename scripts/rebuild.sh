#!/bin/bash
# Rebuild Docker services

set -e

COMPOSE_FILE="local.docker.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🔨 Rebuilding Docker Environment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse command line arguments
SERVICE=""
NO_CACHE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache|-n)
            NO_CACHE=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./rebuild.sh [OPTIONS] [SERVICE]"
            echo ""
            echo "Arguments:"
            echo "  SERVICE           Specific service to rebuild (optional)"
            echo "                    Options: react-app, nginx, postgres, pgadmin, traefik"
            echo ""
            echo "Options:"
            echo "  -n, --no-cache    Build without using cache"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./rebuild.sh              # Rebuild all services"
            echo "  ./rebuild.sh nginx        # Rebuild only nginx"
            echo "  ./rebuild.sh -n           # Rebuild all without cache"
            exit 0
            ;;
        *)
            SERVICE="$1"
            shift
            ;;
    esac
done

# Build command
CMD="docker-compose -f $COMPOSE_FILE build"

if [ "$NO_CACHE" = true ]; then
    CMD="$CMD --no-cache"
fi

if [ -n "$SERVICE" ]; then
    CMD="$CMD $SERVICE"
    echo "🐳 Rebuilding service: $SERVICE"
else
    echo "🐳 Rebuilding all services..."
fi

if [ "$NO_CACHE" = true ]; then
    echo "📦 Build mode: No cache"
else
    echo "📦 Build mode: Using cache"
fi

echo ""

# Execute build
eval $CMD

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "💡 Start services: ./scripts/start.sh"
