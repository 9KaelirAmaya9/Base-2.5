#!/bin/bash
# Clean up Docker resources

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

echo "ðŸ§¹ Cleaning Docker Environment..."
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

# Parse command line arguments
CLEAN_ALL=false
CLEAN_VOLUMES=false
CLEAN_IMAGES=false

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
        --all|-a)
            CLEAN_ALL=true
            shift
            ;;
        --volumes|-v)
            CLEAN_VOLUMES=true
            shift
            ;;
        --images|-i)
            CLEAN_IMAGES=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./clean.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --compose-file FILE  Use a specific compose file"
            echo "  -e, --env-file FILE      Use a specific env file"
            echo "  -a, --all         Clean everything (containers, volumes, images)"
            echo "  -v, --volumes     Clean volumes only (WARNING: deletes data)"
            echo "  -i, --images      Clean images only"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./clean.sh              # Stop and remove containers"
            echo "  ./clean.sh -v           # Remove containers and volumes"
            echo "  ./clean.sh -i           # Remove containers and images"
            echo "  ./clean.sh -a           # Remove everything"
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

# Determine what to clean
if [ "$CLEAN_ALL" = true ]; then
    CLEAN_VOLUMES=true
    CLEAN_IMAGES=true
fi

# Stop and remove containers
echo "ðŸ›‘ Stopping and removing containers..."
if [ "$CLEAN_VOLUMES" = true ]; then
    echo "âš ï¸  WARNING: This will remove volumes and delete all data!"
    read -p "Are you sure? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down -v
        echo "âœ… Containers and volumes removed"
    else
        echo "âŒ Operation cancelled"
        exit 1
    fi
else
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down
    echo "âœ… Containers removed"
fi

# Remove images
if [ "$CLEAN_IMAGES" = true ]; then
    echo ""
    echo "ðŸ—‘ï¸  Removing images..."
    
    # Get images that match the current compose project name
    IMAGES=$(docker images --filter=reference="${COMPOSE_PROJECT_NAME}*" -q)
    if [ -z "$IMAGES" ]; then
        IMAGES=$(docker images --filter=reference="*${COMPOSE_PROJECT_NAME}*" -q)
    fi
    
    if [ -z "$IMAGES" ]; then
        echo "â„¹ï¸  No matching images found"
    else
        echo "Found images:"
        docker images --filter=reference="*${COMPOSE_PROJECT_NAME}*"
        echo ""
        read -p "Remove these images? (yes/no): " -r
        echo
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            docker rmi $IMAGES
            echo "âœ… Images removed"
        else
            echo "âŒ Image removal cancelled"
        fi
    fi
fi

echo ""
echo "ðŸ§¹ Cleanup completed!"
echo ""
echo "ðŸ’¡ To also clean Docker system resources:"
echo "   docker system prune -a"

