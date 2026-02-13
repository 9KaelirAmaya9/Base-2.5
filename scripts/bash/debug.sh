#!/bin/bash
# Debug Docker services - inspect containers, networks, and volumes

set -e

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Derive values from env file when present
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

NETWORK_NAME="$(get_env_var NETWORK_NAME)"
if [ -z "$NETWORK_NAME" ]; then NETWORK_NAME="${COMPOSE_PROJECT_NAME}_network"; fi

echo "ðŸ› Debugging Docker Environment..."
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
            echo "Usage: ./debug.sh [SERVICE]"
            echo ""
            echo "Arguments:"
            echo "  SERVICE           Specific service to debug (optional)"
            echo "                    Options: react-app, nginx, postgres, pgadmin, traefik"
            echo ""
            echo "Options:"
            echo "  -c, --compose-file FILE  Use a specific compose file"
            echo "  -e, --env-file FILE      Use a specific env file"
            echo ""
            echo "Examples:"
            echo "  ./debug.sh              # Debug all services"
            echo "  ./debug.sh postgres     # Debug postgres service"
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

if [ -n "$SERVICE" ]; then
    container_name="${COMPOSE_PROJECT_NAME}_${SERVICE}"
    
    echo "ðŸ” Debugging service: $SERVICE"
    echo ""
    
    # Check if container exists
    if ! docker ps -a --filter "name=${container_name}" --format "{{.Names}}" | grep -q "${container_name}"; then
        echo "âŒ Container $container_name not found"
        exit 1
    fi
    
    # Container info
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ“¦ Container Information:"
    docker inspect "${container_name}" --format='
Container: {{.Name}}
Status: {{.State.Status}}
Started: {{.State.StartedAt}}
Health: {{.State.Health.Status}}
Image: {{.Config.Image}}
'
    
    # Environment variables
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ”§ Environment Variables:"
    docker inspect "${container_name}" --format='{{range .Config.Env}}{{println .}}{{end}}' | sort
    
    # Port mappings
    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸŒ Port Mappings:"
    docker port "${container_name}" 2>/dev/null || echo "No port mappings"
    
    # Networks
    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ”— Networks:"
    docker inspect "${container_name}" --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}: {{$v.IPAddress}}{{println}}{{end}}'
    
    # Volumes
    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ’¾ Volumes:"
    docker inspect "${container_name}" --format='{{range .Mounts}}{{.Type}}: {{.Source}} -> {{.Destination}}{{println}}{{end}}' || echo "No volumes"
    
    # Recent logs
    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ“‹ Recent Logs (last 20 lines):"
    docker logs --tail 20 "${container_name}"
    
else
    echo "ðŸ” Debugging all services"
    echo ""
    
    # Overall status
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ“Š Container Status:"
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
    
    # Network info
    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ”— Network Information:"
    docker network inspect "$NETWORK_NAME" --format='
Network: {{.Name}}
Driver: {{.Driver}}
Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}

Connected Containers:
{{range $k, $v := .Containers}}  - {{$v.Name}} ({{$v.IPv4Address}})
{{end}}' 2>/dev/null || echo "Network not found"
    
    # Volume info
    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ’¾ Volume Information:"
    docker volume ls --filter "name=${COMPOSE_PROJECT_NAME}" --format "table {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}"
    
    # Resource usage
    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "ðŸ“ˆ Resource Usage:"
    if docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps -q | grep -q .; then
        docker stats --no-stream $(docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps -q)
    else
        echo "No running containers"
    fi
    
    echo ""
    echo "ðŸ’¡ Debug specific service: ./scripts/bash/debug.sh [service-name]"
fi

echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

