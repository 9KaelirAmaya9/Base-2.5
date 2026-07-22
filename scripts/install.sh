#!/bin/bash
# Install Base-2.5's custom agent library into a supported AI coding tool.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$PROJECT_DIR/agents"

TOOL=""
CATEGORY=""
DEST=""

usage() {
    echo "Usage: ./scripts/install.sh --tool <tool> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --tool NAME        Target tool. Supported: claude-code"
    echo "  -c, --category NAME    Install only one division (e.g. engineering)"
    echo "  -d, --dest DIR         Override the destination directory"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/install.sh --tool claude-code"
    echo "  ./scripts/install.sh --tool claude-code --category engineering"
    echo ""
    echo "Divisions available in agents/:"
    for dir in "$AGENTS_DIR"/*/; do
        [ -d "$dir" ] && echo "  - $(basename "$dir")"
    done
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --tool|-t)
            TOOL="$2"
            shift 2
            ;;
        --category|-c)
            CATEGORY="$2"
            shift 2
            ;;
        --dest|-d)
            DEST="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ -z "$TOOL" ]; then
    echo "Error: --tool is required"
    usage
    exit 1
fi

case "$TOOL" in
    claude-code)
        DEST="${DEST:-$HOME/.claude/agents}"
        ;;
    *)
        echo "Error: unsupported tool '$TOOL'. Supported tools: claude-code"
        exit 1
        ;;
esac

if [ ! -d "$AGENTS_DIR" ]; then
    echo "Error: agents directory not found at $AGENTS_DIR"
    exit 1
fi

if [ -n "$CATEGORY" ]; then
    SOURCE_DIRS=("$AGENTS_DIR/$CATEGORY/")
    if [ ! -d "${SOURCE_DIRS[0]}" ]; then
        echo "Error: unknown category '$CATEGORY'"
        usage
        exit 1
    fi
else
    SOURCE_DIRS=("$AGENTS_DIR"/*/)
fi

mkdir -p "$DEST"

COPIED=0
for dir in "${SOURCE_DIRS[@]}"; do
    for file in "$dir"*.md; do
        [ -f "$file" ] || continue
        cp "$file" "$DEST/"
        COPIED=$((COPIED + 1))
    done
done

if [ "$COPIED" -eq 0 ]; then
    echo "No agent files found to install."
    exit 1
fi

echo "Installed $COPIED agent(s) to $DEST"
