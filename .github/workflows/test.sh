#!/bin/bash

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Copy the project files
cp -r . "$TEMP_DIR"
cd "$TEMP_DIR"

# Simulate GitHub Actions environment
echo "Setting up Node.js environment..."
export NODE_VERSION=20
export CI=true

# Install Node.js (similar to actions/setup-node)
curl -fsSL https://fnm.vercel.app/install | bash
export PATH="/root/.local/share/fnm:$PATH"
fnm install $NODE_VERSION
fnm use $NODE_VERSION

# Enable Corepack and prepare Yarn (same as GitHub Actions)
echo "Setting up Yarn..."
corepack enable
corepack prepare yarn@4.7.0 --activate

# Install dependencies and run tests
echo "Installing dependencies..."
yarn install --immutable

echo "Running tests..."
yarn test

# Clean up
cd -
rm -rf "$TEMP_DIR" 