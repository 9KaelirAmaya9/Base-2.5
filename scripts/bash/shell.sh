#!/bin/bash
# Access shell in a Docker container

set -e

COMPOSE_FILE="development.docker.yml"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Derive container prefix from env file (fallback to PROJECT_NAME/app)
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
if [ -z "$COMPOSE_PROJECT_NAME" ]; then
    COMPOSE_PROJECT_NAME="$(get_env_var PROJECT_NAME)"
fi
if [ -z "$COMPOSE_PROJECT_NAME" ]; then
    COMPOSE_PROJECT_NAME="app"
fi

# Parse command line arguments
SERVICE=""
SHELL_TYPE="sh"

while [[ $# -gt 0 ]]; do
    case $1 in
        --bash|-b)
            SHELL_TYPE="bash"
            shift
            ;;
        --env-file|-e)
            ENV_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ./shell.sh [OPTIONS] SERVICE"
            echo ""
            echo "Arguments:"
            echo "  SERVICE           Service to access (required)"
            echo "                    Options: react-app, nginx, postgres, pgadmin, traefik"
            echo ""
            echo "Options:"
            echo "  -b, --bash        Use bash instead of sh (if available)"
            echo "  -e, --env-file FILE      Use a specific env file"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./shell.sh postgres         # Access postgres container with sh"
            echo "  ./shell.sh -b react-app     # Access react-app with bash"
            exit 0
            ;;
        *)
            SERVICE="$1"
            shift
            ;;
    esac
done

if [ ! -f "$ENV_FILE" ]; then
    echo "âŒ Error: env file not found: $ENV_FILE"
    exit 1
fi

if [ -z "$SERVICE" ]; then
    echo "âŒ Error: SERVICE argument is required"
    echo "Use --help for usage information"
    exit 1
fi

container_name="${COMPOSE_PROJECT_NAME}_${SERVICE}"

echo "ðŸš Accessing shell for: $SERVICE"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""

# Check if container is running
if ! docker ps --filter "name=${container_name}" --format "{{.Names}}" | grep -q "${container_name}"; then
    echo "âŒ Container $container_name is not running"
    echo ""
    echo "ðŸ’¡ Start services: ./scripts/bash/start.sh"
    exit 1
fi

echo "ðŸ”— Connecting to $container_name..."
echo "ðŸ’¡ Type 'exit' to leave the shell"
echo ""

# Try to use specified shell, fall back to sh if not available
if [ "$SHELL_TYPE" = "bash" ]; then
    docker exec -it "${container_name}" bash 2>/dev/null || \
    docker exec -it "${container_name}" sh
else
    docker exec -it "${container_name}" sh
fi
