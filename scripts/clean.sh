#!/bin/bash
# Clean up Docker resources

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

echo "🧹 Cleaning Docker Environment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse command line arguments
CLEAN_ALL=false
CLEAN_VOLUMES=false
CLEAN_IMAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
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

# Determine what to clean
if [ "$CLEAN_ALL" = true ]; then
    CLEAN_VOLUMES=true
    CLEAN_IMAGES=true
fi

# Stop and remove containers
echo "🛑 Stopping and removing containers..."
if [ "$CLEAN_VOLUMES" = true ]; then
    echo "⚠️  WARNING: This will remove volumes and delete all data!"
    read -p "Are you sure? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        docker-compose -f "$COMPOSE_FILE" down -v
        echo "✅ Containers and volumes removed"
    else
        echo "❌ Operation cancelled"
        exit 1
    fi
else
    docker-compose -f "$COMPOSE_FILE" down
    echo "✅ Containers removed"
fi

# Remove images
if [ "$CLEAN_IMAGES" = true ]; then
    echo ""
    echo "🗑️  Removing images..."
    
    # Get images that match the current compose project name
    IMAGES=$(docker images --filter=reference="${COMPOSE_PROJECT_NAME}*" -q)
    if [ -z "$IMAGES" ]; then
        IMAGES=$(docker images --filter=reference="*${COMPOSE_PROJECT_NAME}*" -q)
    fi
    
    if [ -z "$IMAGES" ]; then
        echo "ℹ️  No matching images found"
    else
        echo "Found images:"
        docker images --filter=reference="*${COMPOSE_PROJECT_NAME}*"
        echo ""
        read -p "Remove these images? (yes/no): " -r
        echo
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            docker rmi $IMAGES
            echo "✅ Images removed"
        else
            echo "❌ Image removal cancelled"
        fi
    fi
fi

echo ""
echo "🧹 Cleanup completed!"
echo ""
echo "💡 To also clean Docker system resources:"
echo "   docker system prune -a"
