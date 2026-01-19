#!/bin/sh
# Docker entrypoint for Gallformers V2
# Runs migrations then starts the app with Litestream replication

set -e

# Fix ownership of data directory and any existing litestream files
# This handles the case where the volume was created by a different deployment
if [ -d /data ]; then
  chown -R gallformers:gallformers /data
fi

# Run database migrations before starting the server
# Note: release_command doesn't work with SQLite volumes on Fly.io because
# the release machine gets a forked snapshot that doesn't persist changes
echo "Running database migrations..."
su-exec gallformers /app/bin/gallformers eval 'Gallformers.Release.migrate()'

# Switch to gallformers user and start litestream with the app
exec su-exec gallformers litestream replicate -exec "/app/bin/server"
