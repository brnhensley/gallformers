# Map Tiles (boundaries.pmtiles) Operations

## Overview

Range maps use a PMTiles vector tile file (`boundaries.pmtiles`, ~370MB) containing country and subdivision boundaries from Natural Earth. The file is built locally, uploaded to public S3, and downloaded automatically on first boot in production.

For build pipeline internals, layer structure, diagnostic scripts, and gotchas, see `services/boundaries/README.md`.

## Architecture

```
Natural Earth shapefiles
    │
    ↓  services/boundaries/build_boundaries.sh
    │
    priv/static/data/boundaries.pmtiles (local dev)
    │
    ↓  aws s3 cp → public S3
    │
    s3://gallformers-backups/public/boundaries.pmtiles
    │
    ↓  curl at boot (prod) or Docker build (preview)
    │
    /data/boundaries.pmtiles (prod volume)
    /app/data/boundaries.pmtiles (preview)
    │
    ↓  symlink at boot (docker-entrypoint.sh)
    │
    /app/lib/gallformers-0.1.0/priv/static/data/boundaries.pmtiles
    │
    ↓  Phoenix Plug.Static serves at /data/boundaries.pmtiles
    │
    assets/js/hooks/range_map.js (MapLibre GL JS)
```

## Environment-Specific Flow

### Local Development

| Item | Details |
|------|---------|
| **File** | `priv/static/data/boundaries.pmtiles` |
| **Built by** | `services/boundaries/build_boundaries.sh` |
| **Served by** | Phoenix `Plug.Static` via `static_dirs` including `data` |

```bash
# Build tiles (~2 minutes, requires gdal, tippecanoe, jq)
cd services/boundaries
./build_boundaries.sh ../../priv/static/data/boundaries.pmtiles

# Hard refresh browser (Cmd+Shift+R) to pick up new tiles
```

Prerequisites: `brew install gdal tippecanoe curl unzip jq`

### Preview (gallformers-preview.fly.dev)

| Item | Details |
|------|---------|
| **File** | `/app/data/boundaries.pmtiles` (baked into Docker image) |
| **Downloaded at** | Docker build time from public S3 |
| **Symlinked at** | Boot by `docker-entrypoint-preview.sh` |

The preview Dockerfile downloads the file during build:
```dockerfile
curl -fSL -o /app/data/boundaries.pmtiles \
  https://gallformers-backups.s3.amazonaws.com/public/boundaries.pmtiles
```

To update preview: rebuild tiles locally, upload to S3 (see below), redeploy preview.

### Production (gallformers.fly.dev)

| Item | Details |
|------|---------|
| **File** | `/data/boundaries.pmtiles` on Fly persistent volume |
| **Downloaded at** | First boot if not present (by `docker-entrypoint.sh`) |
| **Symlinked at** | Every boot by `docker-entrypoint.sh` |
| **Source** | `https://gallformers-backups.s3.amazonaws.com/public/boundaries.pmtiles` |

The entrypoint checks if the file exists on the volume. If not, it downloads from public S3 automatically. Once on the volume, it persists across deploys.

The symlink bridges the volume path to Phoenix's static file serving:
```
/data/boundaries.pmtiles → /app/lib/gallformers-0.1.0/priv/static/data/boundaries.pmtiles
```

## Updating Map Tiles

When boundaries need to change (new territories, updated geometry, etc.):

```bash
# 1. Rebuild tiles locally
cd services/boundaries
./build_boundaries.sh ../../priv/static/data/boundaries.pmtiles

# 2. Verify coverage against the database
python3 verify_tiles.py

# 3. Upload to public S3
aws s3 cp priv/static/data/boundaries.pmtiles s3://gallformers-backups/public/boundaries.pmtiles

# 4. Update production (choose one):

# Option A: Delete the file and restart (triggers re-download from S3)
fly ssh console -C "rm /data/boundaries.pmtiles"
fly machine restart

# Option B: Upload directly to the volume
echo "put priv/static/data/boundaries.pmtiles /data/boundaries.pmtiles" | fly ssh sftp shell
fly machine restart
```

## Git and Docker Status

- `.gitignore`: `priv/static/data/boundaries.pmtiles` — not committed (build artifact)
- `.dockerignore`: `priv/static/data/` — entire directory excluded from build context

## Troubleshooting

### Maps are empty

1. Check if the file exists on the volume:
   ```bash
   fly ssh console -C "ls -lh /data/boundaries.pmtiles"
   ```

2. Check if the symlink exists:
   ```bash
   fly ssh console -C "ls -la /app/lib/gallformers-0.1.0/priv/static/data/"
   ```

3. Check the entrypoint log for download errors:
   ```bash
   fly logs 2>&1 | timeout 5 cat | grep -i boundaries
   ```

4. If the file is missing, restart the machine (triggers auto-download):
   ```bash
   fly machine restart
   ```

### Tiles don't match database places

Run the verification script after any tile rebuild:
```bash
cd services/boundaries
python3 verify_tiles.py
```

See `services/boundaries/README.md` for detailed diagnostic scripts.

### Browser shows stale tiles

Hard refresh (Cmd+Shift+R / Ctrl+Shift+R). If tiles still wrong, clear browser cache entirely. PMTiles are aggressively cached by browsers.
