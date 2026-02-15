#!/bin/bash
# Check health status of all services

set -e

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

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
            echo "Usage: ./health.sh [OPTIONS]"
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
    echo "âŒ Error: compose file not found: $COMPOSE_FILE"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "âŒ Error: env file not found: $ENV_FILE"
    exit 1
fi

# Derive values from .env when present
get_env_var() {
    local key="$1"
    local line
    line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -n1 || true)
    if [ -n "$line" ]; then
        line=$(echo "$line" | sed 's/ *#.*//' | sed 's/[[:space:]]*$//')
        echo "$line" | cut -d'=' -f2-
    fi
}

COMPOSE_PROJECT_NAME="$(get_env_var COMPOSE_PROJECT_NAME)"
if [ -z "$COMPOSE_PROJECT_NAME" ]; then COMPOSE_PROJECT_NAME="$(get_env_var PROJECT_NAME)"; fi
if [ -z "$COMPOSE_PROJECT_NAME" ]; then COMPOSE_PROJECT_NAME="app"; fi

echo "ðŸ¥ Health Check for Docker Environment"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""

# Check if services are running
if ! docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps -q | grep -q .; then
    echo "âŒ No services are running"
    echo ""
    echo "ðŸ’¡ Start services: ./scripts/bash/start.sh"
    exit 1
fi

# Function to check service health
check_health() {
    local service=$1
    local container_name="${COMPOSE_PROJECT_NAME}_${service}"

    if docker ps --filter "name=${container_name}" --format "{{.Names}}" | grep -q "${container_name}"; then
        health=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "no healthcheck")
        status=$(docker inspect --format='{{.State.Status}}' "${container_name}")
        uptime=$(docker inspect --format='{{.State.StartedAt}}' "${container_name}")

        if [ "$health" = "healthy" ]; then
            echo "  âœ… ${service}"
            echo "     Status: ${status}"
            echo "     Health: ${health}"
            echo "     Started: ${uptime}"
            return 0
        elif [ "$health" = "unhealthy" ]; then
            echo "  âŒ ${service}"
            echo "     Status: ${status}"
            echo "     Health: ${health}"
            echo "     Started: ${uptime}"
            echo "     Last logs:"
            docker logs --tail 10 "${container_name}" 2>&1 | sed 's/^/       /'
            return 1
        elif [ "$health" = "starting" ]; then
            echo "  ðŸ”„ ${service}"
            echo "     Status: ${status}"
            echo "     Health: ${health}"
            echo "     Started: ${uptime}"
            return 2
        else
            if [ "$status" = "running" ]; then
                echo "  ðŸŸ¢ ${service}"
                echo "     Status: ${status}"
                echo "     Health: No healthcheck configured"
                echo "     Started: ${uptime}"
                return 0
            else
                echo "  ðŸ”´ ${service}"
                echo "     Status: ${status}"
                echo "     Started: ${uptime}"
                return 1
            fi
        fi
    else
        echo "  âš« ${service}"
        echo "     Status: Not running"
        return 1
    fi
}

# Check all services
HEALTHY=0
UNHEALTHY=0
STARTING=0
STOPPED=0

for service in react-app nginx postgres pgadmin traefik; do
    check_health "$service"
    result=$?

    if [ $result -eq 0 ]; then
        ((HEALTHY++))
    elif [ $result -eq 1 ]; then
        ((UNHEALTHY++))
    elif [ $result -eq 2 ]; then
        ((STARTING++))
    fi

    echo ""
done

# Summary
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ“Š Summary:"
echo "   âœ… Healthy: $HEALTHY"
echo "   ðŸ”„ Starting: $STARTING"
echo "   âŒ Unhealthy: $UNHEALTHY"
echo ""

if [ $UNHEALTHY -gt 0 ]; then
    echo "âš ï¸  Some services are unhealthy!"
    echo "ðŸ’¡ Debug services: ./scripts/bash/debug.sh [service-name]"
    echo "ðŸ’¡ View logs: ./scripts/bash/logs.sh [service-name]"
    exit 1
elif [ $STARTING -gt 0 ]; then
    echo "â³ Some services are still starting..."
    echo "ðŸ’¡ Check again in a few moments"
    exit 2
else
    echo "âœ… All services are healthy!"
    exit 0
fi
