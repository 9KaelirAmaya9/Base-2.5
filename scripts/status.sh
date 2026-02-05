#!/bin/bash
# Check status of Docker services

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

echo "📊 Docker Environment Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if docker-compose is running
if docker-compose -f "$COMPOSE_FILE" ps -q | grep -q .; then
    echo "🐳 Container Status:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏥 Health Check Status:"
    echo ""
    
    # Check health of each service
    for service in traefik react-app api django postgres nginx nginx-static pgadmin redis celery-worker celery-beat flower; do
        container_name="${COMPOSE_PROJECT_NAME}_${service}"
        if docker ps --filter "name=${container_name}" --format "{{.Names}}" | grep -q "${container_name}"; then
            health=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "no healthcheck")
            status=$(docker inspect --format='{{.State.Status}}' "${container_name}")
            
            if [ "$health" = "healthy" ]; then
                echo "  ✅ ${service}: ${status} (healthy)"
            elif [ "$health" = "unhealthy" ]; then
                echo "  ❌ ${service}: ${status} (unhealthy)"
            elif [ "$health" = "starting" ]; then
                echo "  🔄 ${service}: ${status} (starting)"
            else
                if [ "$status" = "running" ]; then
                    echo "  🟢 ${service}: ${status}"
                else
                    echo "  🔴 ${service}: ${status}"
                fi
            fi
        else
            echo "  ⚫ ${service}: not running"
        fi
    done
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Resource Usage:"
    echo ""
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(docker-compose -f "$COMPOSE_FILE" ps -q)
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Service URLs (via Traefik):"
    domain=${WEBSITE_DOMAIN:-$(get_env_var WEBSITE_DOMAIN)}
    if [ -z "$domain" ]; then domain=localhost; fi
    echo "  - Frontend:          https://${domain}/"
    echo "  - API health:        https://${domain}/api/health"
    echo "  - Static:            https://${domain}/static/"
    echo "  - Traefik Dashboard: https://${TRAEFIK_DNS_LABEL:-traefik}.${domain}/ (guarded)"
    echo "  - Django Admin:      https://${DJANGO_ADMIN_DNS_LABEL:-admin}.${domain}/admin (guarded)"
else
    echo "⚠️  No containers are running"
    echo ""
    echo "💡 Start services: ./scripts/start.sh"
fi
