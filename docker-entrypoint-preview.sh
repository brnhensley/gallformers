#!/bin/sh
# Docker entrypoint for Gallformers preview deploys
# Runs migrations against remote Postgres, then starts the server

set -e

# Boundary tiles are served via CloudFront (TILES_URL env var).
# No local file or symlink needed.

# Run database migrations (no-op when already applied)
echo "Running database migrations..."
attempts=0
max_attempts=3
until /app/bin/gallformers eval 'Gallformers.Release.migrate()'; do
  attempts=$((attempts + 1))
  if [ "$attempts" -ge "$max_attempts" ]; then
    echo "ERROR: Migrations failed after $max_attempts attempts"
    exit 1
  fi
  echo "Migration attempt $attempts failed, retrying in 5s..."
  sleep 5
done

echo "Starting server..."
exec /app/bin/server
