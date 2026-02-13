#!/bin/bash
# Restart Docker services

set -e

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "ðŸ”„ Restarting Docker Environment..."
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

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
            echo "Usage: ./scripts/bash/restart.sh [SERVICE]"
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
            echo "  ./scripts/bash/restart.sh              # Restart all services"
            echo "  ./scripts/bash/restart.sh nginx        # Restart only nginx"
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

if [ -z "$SERVICE" ]; then
    echo "ðŸ³ Restarting all services..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" restart
    echo ""
    echo "âœ… All services restarted successfully!"
else
    echo "ðŸ³ Restarting $SERVICE..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" restart "$SERVICE"
    echo ""
    echo "âœ… Service $SERVICE restarted successfully!"
fi

echo ""
echo "ðŸ“Š Service Status:"
docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps

echo ""
echo "ðŸ’¡ View logs: ./scripts/bash/logs.sh"
