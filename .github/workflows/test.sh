#!/bin/bash

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Copy the project files
cp -r . "$TEMP_DIR"
cd "$TEMP_DIR"

# Build and run the test container
docker build -t gallformers-test -f .github/workflows/Dockerfile.test .
docker run --rm gallformers-test

# Clean up
cd -
rm -rf "$TEMP_DIR" 