#!/bin/bash
# Nuclear option: Stop and completely remove ALL Docker resources for this project
# WARNING: This will delete EVERYTHING including all data!

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

echo "ðŸ’€ KILL ALL - Docker Environment"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""
echo "âš ï¸  âš ï¸  âš ï¸  DANGER ZONE âš ï¸  âš ï¸  âš ï¸"
echo ""
echo "This will PERMANENTLY DELETE:"
echo "  â€¢ All containers (${COMPOSE_PROJECT_NAME}_*)"
echo "  â€¢ All volumes (${COMPOSE_PROJECT_NAME}_*) - ALL DATA WILL BE LOST"
echo "  â€¢ All images (*${COMPOSE_PROJECT_NAME}*)"
echo "  â€¢ Network: ${NETWORK_NAME} (and any network matching *${COMPOSE_PROJECT_NAME}*)"
echo ""
echo "This action CANNOT be undone!"
echo ""

# Parse command line arguments
FORCE=false

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
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./kill.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --compose-file FILE  Use a specific compose file"
            echo "  -e, --env-file FILE      Use a specific env file"
            echo "  -f, --force       Skip confirmation prompt"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "WARNING: This will permanently delete all containers, volumes,"
            echo "images, and networks associated with this project."
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

# Confirmation prompt
if [ "$FORCE" = false ]; then
    echo "Type 'DELETE EVERYTHING' to confirm:"
    read -r confirmation
    
    if [ "$confirmation" != "DELETE EVERYTHING" ]; then
        echo ""
        echo "âŒ Operation cancelled"
        exit 0
    fi
fi

echo ""
echo "ðŸ”¥ Starting complete removal process..."
echo ""

# 1. Stop and remove containers with volumes
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ›‘ Stopping and removing containers..."
docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
echo "âœ… Containers removed"

# 2. Force remove any remaining project containers
echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ—‘ï¸  Force removing any remaining containers..."
CONTAINERS=$(docker ps -aq --filter "name=${COMPOSE_PROJECT_NAME}_" 2>/dev/null || true)
if [ -n "$CONTAINERS" ]; then
    echo "Found containers to remove:"
    docker ps -a --filter "name=${COMPOSE_PROJECT_NAME}_" --format "table {{.Names}}\t{{.Status}}"
    docker rm -f $CONTAINERS
    echo "âœ… Force removed remaining containers"
else
    echo "â„¹ï¸  No containers found"
fi


# 4. Remove all project images
echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ–¼ï¸  Removing all images..."
IMAGES=$(docker images -q --filter "reference=${COMPOSE_PROJECT_NAME}*" 2>/dev/null || true)
if [ -n "$IMAGES" ]; then
    echo "Found images to remove:"
    docker images --filter "reference=${COMPOSE_PROJECT_NAME}*"
    docker rmi -f $IMAGES 2>/dev/null || true
    echo "âœ… Images removed"
else
    echo "â„¹ï¸  No images found"
fi

# Also remove images by project name pattern
IMAGES_ALT=$(docker images -q --filter "reference=*${COMPOSE_PROJECT_NAME}*" 2>/dev/null || true)
if [ -n "$IMAGES_ALT" ]; then
    docker rmi -f $IMAGES_ALT 2>/dev/null || true
fi

# 5. Remove project networks
echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ”— Removing networks..."
if docker network ls --format '{{.Name}}' | grep -Fxq "$NETWORK_NAME"; then
    docker network rm "$NETWORK_NAME" 2>/dev/null || true
fi
NETWORKS=$(docker network ls -q --filter "name=${COMPOSE_PROJECT_NAME}" 2>/dev/null || true)
if [ -n "$NETWORKS" ]; then
    echo "Found networks to remove:"
    docker network ls --filter "name=${COMPOSE_PROJECT_NAME}"
    docker network rm $NETWORKS 2>/dev/null || true
    echo "âœ… Networks removed"
else
    echo "â„¹ï¸  No matching networks found"
fi

# 6. Clean up any dangling resources
echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ§¹ Cleaning up dangling resources..."
docker system prune -f --volumes 2>/dev/null || true
echo "âœ… Dangling resources cleaned"

# 7. Final volume cleanup - check and remove any remaining project volumes
echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ’¾ Final volume cleanup check..."

# List all volumes with the project name in the name
VOLUMES=$(docker volume ls -q --filter "name=${COMPOSE_PROJECT_NAME}" 2>/dev/null || true)

if [ -n "$VOLUMES" ]; then
    echo "âš ï¸  Found remaining volumes to remove:"
    docker volume ls --filter "name=${COMPOSE_PROJECT_NAME}" --format "table {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}"
    echo ""
    echo "ðŸ—‘ï¸  Forcefully removing volumes..."
    
    # Try to remove each volume individually
    for volume in $VOLUMES; do
        echo "  Removing: $volume"
        docker volume rm -f "$volume" 2>/dev/null || \
            echo "  âš ï¸  Could not remove $volume (may be in use)"
    done
    
    # Check if any volumes remain
    REMAINING=$(docker volume ls -q --filter "name=${COMPOSE_PROJECT_NAME}" 2>/dev/null || true)
    if [ -n "$REMAINING" ]; then
        echo ""
        echo "âš ï¸  Some volumes could not be removed. They may be in use."
        echo "   Remaining volumes:"
        docker volume ls --filter "name=${COMPOSE_PROJECT_NAME}"
        echo ""
        echo "   Try stopping all Docker containers and run this script again:"
        echo "   docker stop \$(docker ps -aq) && ./scripts/bash/kill.sh --force"
    else
        echo "âœ… All volumes successfully removed"
    fi
else
    echo "âœ… No volumes found (already clean)"
fi

echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ’€ Complete removal finished!"
echo ""
echo "All Docker resources for this project have been permanently deleted."
echo ""
echo "ðŸ’¡ To start fresh: ./scripts/bash/start.sh --build"

