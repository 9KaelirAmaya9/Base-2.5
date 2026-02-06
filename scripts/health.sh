#!/bin/bash
# Check health status of all services

set -e

COMPOSE_FILE="local.docker.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Derive values from .env when present
get_env_var() {
    local key="$1"
    local line
    line=$(grep -E "^${key}=" .env 2>/dev/null | head -n1 || true)
    if [ -n "$line" ]; then
        line=$(echo "$line" | sed 's/ *#.*//' | sed 's/[[:space:]]*$//')
        echo "$line" | cut -d'=' -f2-
    fi
}

COMPOSE_PROJECT_NAME="$(get_env_var COMPOSE_PROJECT_NAME)"
if [ -z "$COMPOSE_PROJECT_NAME" ]; then COMPOSE_PROJECT_NAME="$(get_env_var PROJECT_NAME)"; fi
if [ -z "$COMPOSE_PROJECT_NAME" ]; then COMPOSE_PROJECT_NAME="app"; fi

echo "🏥 Health Check for Docker Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if services are running
if ! docker-compose -f "$COMPOSE_FILE" ps -q | grep -q .; then
    echo "❌ No services are running"
    echo ""
    echo "💡 Start services: ./scripts/start.sh"
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
            echo "  ✅ ${service}"
            echo "     Status: ${status}"
            echo "     Health: ${health}"
            echo "     Started: ${uptime}"
            return 0
        elif [ "$health" = "unhealthy" ]; then
            echo "  ❌ ${service}"
            echo "     Status: ${status}"
            echo "     Health: ${health}"
            echo "     Started: ${uptime}"
            echo "     Last logs:"
            docker logs --tail 10 "${container_name}" 2>&1 | sed 's/^/       /'
            return 1
        elif [ "$health" = "starting" ]; then
            echo "  🔄 ${service}"
            echo "     Status: ${status}"
            echo "     Health: ${health}"
            echo "     Started: ${uptime}"
            return 2
        else
            if [ "$status" = "running" ]; then
                echo "  🟢 ${service}"
                echo "     Status: ${status}"
                echo "     Health: No healthcheck configured"
                echo "     Started: ${uptime}"
                return 0
            else
                echo "  🔴 ${service}"
                echo "     Status: ${status}"
                echo "     Started: ${uptime}"
                return 1
            fi
        fi
    else
        echo "  ⚫ ${service}"
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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "   ✅ Healthy: $HEALTHY"
echo "   🔄 Starting: $STARTING"
echo "   ❌ Unhealthy: $UNHEALTHY"
echo ""

if [ $UNHEALTHY -gt 0 ]; then
    echo "⚠️  Some services are unhealthy!"
    echo "💡 Debug services: ./scripts/debug.sh [service-name]"
    echo "💡 View logs: ./scripts/logs.sh [service-name]"
    exit 1
elif [ $STARTING -gt 0 ]; then
    echo "⏳ Some services are still starting..."
    echo "💡 Check again in a few moments"
    exit 2
else
    echo "✅ All services are healthy!"
    exit 0
fi
