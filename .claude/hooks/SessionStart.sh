#!/bin/bash

# Only run in remote environments
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  exit 0
fi

# Session start hook to ensure pre-commit is installed
echo "Setting up pre-commit..."

# Check if pre-commit is available, install if not
if ! command -v pre-commit &> /dev/null; then
    echo "pre-commit is not installed. Installing pre-commit..."
    pip install pre-commit

    # Verify installation
    if ! command -v pre-commit &> /dev/null; then
        echo "Error: Failed to install pre-commit."
        exit 1
    fi

    echo "pre-commit installed successfully!"
fi

# Install pre-commit hooks
pre-commit install
pre-commit install --hook-type commit-msg

echo "Pre-commit hooks installed successfully!"
