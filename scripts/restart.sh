#!/bin/bash
# Restart Docker services

set -e

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🔄 Restarting Docker Environment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse command line arguments
SERVICE=""

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
            echo "Usage: ./restart.sh [SERVICE]"
            echo ""
            echo "Arguments:"
            echo "  SERVICE           Specific service to restart (optional)"
            echo "                    Options: react-app, nginx, postgres, pgadmin, traefik"
            echo ""
            echo "Options:"
            echo "  -c, --compose-file FILE  Use a specific compose file"
            echo "  -e, --env-file FILE      Use a specific env file"
            echo ""
            echo "Examples:"
            echo "  ./restart.sh              # Restart all services"
            echo "  ./restart.sh nginx        # Restart only nginx"
            exit 0
            ;;
        *)
            SERVICE="$1"
            shift
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

if [ -z "$SERVICE" ]; then
    echo "🐳 Restarting all services..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" restart
    echo ""
    echo "✅ All services restarted successfully!"
else
    echo "🐳 Restarting $SERVICE..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" restart "$SERVICE"
    echo ""
    echo "✅ Service $SERVICE restarted successfully!"
fi

echo ""
echo "📊 Service Status:"
docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps

echo ""
echo "💡 View logs: ./scripts/logs.sh"

