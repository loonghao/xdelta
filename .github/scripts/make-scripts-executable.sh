#!/bin/bash
# Script to make all scripts in .github/scripts directory executable
# Usage: ./make-scripts-executable.sh

SCRIPTS_DIR="$(dirname "$0")"
echo "Making all scripts in $SCRIPTS_DIR executable..."

# Find all shell scripts and make them executable
find "$SCRIPTS_DIR" -name "*.sh" -type f -exec chmod +x {} \;
echo "Made all shell scripts executable"

# Make PowerShell scripts executable (if on Unix-like system)
find "$SCRIPTS_DIR" -name "*.ps1" -type f -exec chmod +x {} \; 2>/dev/null || true
echo "Made all PowerShell scripts executable"

# Make root build scripts executable
ROOT_DIR="$(dirname "$(dirname "$SCRIPTS_DIR")")"
chmod +x "$ROOT_DIR/build.sh" 2>/dev/null || true
echo "Made root build scripts executable"

# List all scripts with their permissions
echo "Script permissions:"
ls -la "$SCRIPTS_DIR"
