# Branch Preview Deploys — Design

**Matter**: 9ca2
**Date**: 2026-02-15
**Status**: Approved

## Goal

Deploy any local branch to a disposable Fly.io instance with its own copy of production data for testing. Single preview slot, on-demand only, controlled via Make targets.

## Decisions

- **Database delivery**: Bake into the Docker image via Litestream restore at build time. No volumes.
- **Trigger**: Local CLI only (`make preview`). GitHub Actions workflow deferred.
- **Data source**: Full Litestream backup from S3 (includes user data).
- **Access**: Open, no auth gate beyond Auth0 for admin pages.
- **Image uploads**: Prefixed to `preview/` in the same S3 bucket. Cleaned up manually.
- **Scope**: SQLite only. Will be revisited when Postgres migration (4474) lands.

## Architecture

```
Local machine                         Fly.io
─────────────                         ──────
make preview
  └─ fly deploy                       gallformers-preview
       --config fly.preview.toml        ├─ /app/data/gallformers.sqlite (baked in)
       --dockerfile Dockerfile.preview  ├─ No volumes
       --build-secret aws creds         ├─ No Litestream replication
                                        ├─ No health checks
                                        ├─ S3_IMAGE_PREFIX=preview
                                        └─ PHX_HOST=gallformers-preview.fly.dev
```

## Components

### fly.preview.toml

Preview app configuration:

- **App name**: `gallformers-preview`
- **Region**: `iad`
- **No volumes**
- **No health checks**
- **VM**: 512MB shared (same as production)
- **Env vars**:
  - `PHX_HOST=gallformers-preview.fly.dev`
  - `DATABASE_PATH=/app/data/gallformers.sqlite`
  - `S3_IMAGE_PREFIX=preview`

### Dockerfile.preview

Extends the existing multi-stage build:

- **Builder stage**: Identical to production Dockerfile.
- **Runtime stage**: Same base image and dependencies, plus:
  - Litestream installed (for build-time restore only)
  - `RUN` step: `litestream restore -o /app/data/gallformers.sqlite s3://gallformers-backups/litestream`
  - AWS credentials passed as build secrets (`--build-secret`), not persisted in layers
  - Simple entrypoint: run migrations, start server. No Litestream replication, no backup dance.

### S3 Image Prefix

- New env var `S3_IMAGE_PREFIX` — empty in production, `"preview"` in preview.
- Image upload code prepends this to S3 keys: `preview/gall/{id}/filename.jpg`.
- Image reads also use the prefix for newly uploaded images.
- Existing images (referenced in the baked-in DB) still resolve from their original paths in S3/CloudFront.
- Cleanup: `aws s3 rm --recursive s3://gallformers-images-us-east-1/preview/`

### Make Targets

| Target | Action |
|--------|--------|
| `make preview` | Build and deploy preview from current local branch |
| `make preview-stop` | Stop the machine (preserves app config and secrets) |
| `make preview-destroy` | Destroy the app entirely |

### One-Time Prerequisites

1. Create the Fly app: `fly apps create gallformers-preview`
2. Set secrets: mirror production secrets via `fly secrets set` on the preview app
3. Auth0: add `https://gallformers-preview.fly.dev` to allowed callback URLs, logout URLs, and web origins

## What We're NOT Building

- GitHub Actions workflow (can add later)
- Health checks
- Litestream replication on the preview
- Persistent volumes
- Automatic teardown / TTL
- Postgres support (revisit with 4474)
- Multiple simultaneous preview slots
