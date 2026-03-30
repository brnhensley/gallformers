#!/bin/sh
# Docker entrypoint for Gallformers V2
# Downloads data files if needed, runs migrations, then starts the app

set -e

DISK_WARN_PERCENT=80

# Check disk usage and warn if above threshold
check_disk_usage() {
  usage=$(df /data | awk 'NR==2 {gsub(/%/,""); print $5}')
  if [ "$usage" -ge "$DISK_WARN_PERCENT" ]; then
    echo "WARNING: /data volume is ${usage}% full — consider extending the volume"
  fi
}

# Fix ownership of data directory
if [ -d /data ]; then
  chown -R gallformers:gallformers /data 2>/dev/null || echo "WARNING: Could not chown all files in /data — continuing"
fi

check_disk_usage

# WCVP data lives in Postgres now (separate database on the same cluster).
# Loaded via pg_restore — see runbooks/wcvp.md.
#
# Boundaries PMTiles is served directly from S3 via CloudFront at /tiles/*.
# No local download or symlink needed.

# Run database migrations
echo "Running database migrations..."
attempts=0
max_attempts=3
until su-exec gallformers /app/bin/gallformers eval 'Gallformers.Release.migrate()'; do
  attempts=$((attempts + 1))
  if [ "$attempts" -ge "$max_attempts" ]; then
    echo "ERROR: Migrations failed after $max_attempts attempts"
    exit 1
  fi
  echo "Migration attempt $attempts failed, retrying in 5s..."
  sleep 5
done

# Switch to gallformers user and start the app
exec su-exec gallformers /app/bin/server
