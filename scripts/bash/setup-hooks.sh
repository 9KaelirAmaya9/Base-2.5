#!/bin/bash
# Setup git hooks for the project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "ðŸ”§ Setting up git hooks..."
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""

# Check if .git directory exists
if [ ! -d ".git" ]; then
    echo "âŒ Error: Not a git repository"
    echo "   Initialize git first: git init"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy pre-commit hook
if [ -f ".git-hooks/pre-commit" ]; then
    echo "ðŸ“‹ Installing pre-commit hook..."
    cp .git-hooks/pre-commit .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo "âœ… Pre-commit hook installed"
else
    echo "âš ï¸  Warning: .git-hooks/pre-commit not found"
fi

echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "âœ… Git hooks setup complete!"
echo ""
echo "The pre-commit hook will:"
echo "  - Automatically synchronize configuration before each commit"
echo "  - Prevent commits if configuration is out of sync"
echo ""
echo "ðŸ’¡ To bypass the hook (not recommended):"
echo "   git commit --no-verify"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
