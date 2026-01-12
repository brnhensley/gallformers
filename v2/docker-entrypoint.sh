#!/bin/sh
# Docker entrypoint for Gallformers V2
# Fixes file permissions before starting the app

set -e

# Fix ownership of data directory and any existing litestream files
# This handles the case where the volume was created by a different deployment
if [ -d /data ]; then
  chown -R gallformers:gallformers /data
fi

# Switch to gallformers user and start litestream with the app
exec su-exec gallformers litestream replicate -exec "/app/bin/server"
