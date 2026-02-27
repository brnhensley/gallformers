#!/bin/sh
# Docker entrypoint for Gallformers preview deploys
# Runs migrations then starts the server (no Litestream replication)

set -e

DATABASE_PATH="${DATABASE_PATH:-/app/data/gallformers.sqlite}"

# Symlink boundaries PMTiles into static assets
if [ -f /app/data/boundaries.pmtiles ]; then
  mkdir -p /app/lib/gallformers-0.1.0/priv/static/data
  ln -sf /app/data/boundaries.pmtiles /app/lib/gallformers-0.1.0/priv/static/data/boundaries.pmtiles
fi

echo "Running database migrations..."
/app/bin/gallformers eval 'Gallformers.Release.migrate()'

echo "Starting server..."
exec /app/bin/server
