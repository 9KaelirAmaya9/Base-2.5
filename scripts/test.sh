#!/bin/bash

# ==========================================
# Test Script
# Usage: ./scripts/test.sh [--coverage] [--watch] [--self-test]
# Options:
#   --coverage        Run tests with coverage
#   --watch           Run tests in watch mode
#   --self-test       Run script self-test and exit
# ==========================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse arguments
COVERAGE_FLAG=""
WATCH_FLAG=""
SELF_TEST=false

for arg in "$@"
do
    case $arg in
        --coverage)
        COVERAGE_FLAG="--coverage"
        shift
        ;;
        --watch)
        WATCH_FLAG="--watch"
        shift
        ;;
        --self-test)
        SELF_TEST=true
        shift
        ;;
        *)
        shift
        ;;
    esac
done

COMPOSE_FILE="local.docker.yml"
COMPOSE_CMD="docker compose -f $COMPOSE_FILE"

require_compose_running() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not installed or not on PATH.${NC}"
        echo -e "${BLUE}Run ./scripts/start.sh to start the stack, then re-run tests.${NC}"
        exit 1
    fi

    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${RED}❌ $COMPOSE_FILE not found. Run this script from the repo root.${NC}"
        exit 1
    fi

    running_services=$($COMPOSE_CMD ps --services --filter "status=running" 2>/dev/null || true)
    if ! echo "$running_services" | grep -q '^api$'; then
        echo -e "${RED}❌ api container is not running.${NC}"
        echo -e "${BLUE}Run ./scripts/start.sh (or make up) to start the stack.${NC}"
        exit 1
    fi
    if ! echo "$running_services" | grep -q '^django$'; then
        echo -e "${RED}❌ django container is not running.${NC}"
        echo -e "${BLUE}Run ./scripts/start.sh (or make up) to start the stack.${NC}"
        exit 1
    fi
}

# Self-test function
if [ "$SELF_TEST" = true ]; then
    echo -e "${BLUE}🔎 Running test.sh self-test...${NC}"
    # Check Docker
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}❌ docker not found.${NC}"
        exit 1
    fi
    # Check Node.js
    if ! command -v node &>/dev/null; then
        echo -e "${RED}❌ Node.js not found.${NC}"
        exit 1
    fi
    # Check npm
    if ! command -v npm &>/dev/null; then
        echo -e "${RED}❌ npm not found.${NC}"
        exit 1
    fi
    # Check frontend test script
    if ! grep -q 'test' react-app/package.json; then
        echo -e "${RED}❌ Frontend test script missing in package.json.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Self-test passed.${NC}"
    exit 0
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Running All Tests${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

BACKEND_EXIT_CODE=0
echo -e "${BLUE}Running backend tests inside Docker compose...${NC}"
require_compose_running

set +e
$COMPOSE_CMD exec -T api pytest
API_EXIT_CODE=$?
$COMPOSE_CMD exec -T django pytest
DJANGO_EXIT_CODE=$?
set -e

if [ $API_EXIT_CODE -ne 0 ] || [ $DJANGO_EXIT_CODE -ne 0 ]; then
    BACKEND_EXIT_CODE=1
fi

echo ""
echo -e "${GREEN}Running Frontend Tests...${NC}"
cd react-app

if [ ! -d "node_modules" ]; then
    echo -e "${RED}Frontend dependencies not installed. Run 'npm install' first.${NC}"
    exit 1
fi

if [ -n "$WATCH_FLAG" ]; then
    npm run test:watch
elif [ -n "$COVERAGE_FLAG" ]; then
    npm run test
else
    npm run test:ci
fi

FRONTEND_EXIT_CODE=$?

cd ..

echo ""
echo -e "${BLUE}================================================${NC}"

if [ $BACKEND_EXIT_CODE -eq 0 ] && [ $FRONTEND_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo -e "${BLUE}================================================${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo -e "${BLUE}================================================${NC}"
    exit 1
fi
