#!/bin/bash
# Quick script to view architecture diagrams with Structurizr Lite

set -e

echo "Starting Structurizr Lite..."
echo "Open http://localhost:8080 in your browser"
echo "Press Ctrl+C to stop"
echo ""

docker run -it --rm -p 8080:8080 \
  -v "$(pwd)":/usr/local/structurizr \
  structurizr/lite
