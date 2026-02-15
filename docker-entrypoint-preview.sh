#!/bin/sh
# Docker entrypoint for Gallformers preview deploys
# Runs migrations then starts the server (no Litestream replication)

set -e

DATABASE_PATH="${DATABASE_PATH:-/app/data/gallformers.sqlite}"

echo "Running database migrations..."
/app/bin/gallformers eval 'Gallformers.Release.migrate()'

echo "Starting server..."
exec /app/bin/server
