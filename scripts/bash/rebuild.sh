#!/bin/bash
# Rebuild Docker services

set -e

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "ðŸ”¨ Rebuilding Docker Environment..."
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

# Parse command line arguments
SERVICE=""
NO_CACHE=false

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
            echo "  -c, --compose-file FILE  Use a specific compose file"
            echo "  -e, --env-file FILE      Use a specific env file"
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

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "âŒ Error: compose file not found: $COMPOSE_FILE"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "âŒ Error: env file not found: $ENV_FILE"
    exit 1
fi

# Build command
CMD="docker-compose --env-file $ENV_FILE -f $COMPOSE_FILE build"

if [ "$NO_CACHE" = true ]; then
    CMD="$CMD --no-cache"
fi

if [ -n "$SERVICE" ]; then
    CMD="$CMD $SERVICE"
    echo "ðŸ³ Rebuilding service: $SERVICE"
else
    echo "ðŸ³ Rebuilding all services..."
fi

if [ "$NO_CACHE" = true ]; then
    echo "ðŸ“¦ Build mode: No cache"
else
    echo "ðŸ“¦ Build mode: Using cache"
fi

echo ""

# Execute build
eval $CMD

echo ""
echo "âœ… Build completed successfully!"
echo ""
echo "ðŸ’¡ Start services: ./scripts/bash/start.sh"

