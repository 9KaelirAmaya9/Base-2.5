#!/bin/bash
# Restart Docker services

set -e

COMPOSE_FILE="local.docker.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🔄 Restarting Docker Environment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse command line arguments
SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Usage: ./restart.sh [SERVICE]"
            echo ""
            echo "Arguments:"
            echo "  SERVICE           Specific service to restart (optional)"
            echo "                    Options: react-app, nginx, postgres, pgadmin, traefik"
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

if [ -z "$SERVICE" ]; then
    echo "🐳 Restarting all services..."
    docker-compose -f "$COMPOSE_FILE" restart
    echo ""
    echo "✅ All services restarted successfully!"
else
    echo "🐳 Restarting $SERVICE..."
    docker-compose -f "$COMPOSE_FILE" restart "$SERVICE"
    echo ""
    echo "✅ Service $SERVICE restarted successfully!"
fi

echo ""
echo "📊 Service Status:"
docker-compose -f "$COMPOSE_FILE" ps

echo ""
echo "💡 View logs: ./scripts/logs.sh"
