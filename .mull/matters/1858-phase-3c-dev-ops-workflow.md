---
status: done
created: 2026-03-11
updated: 2026-03-15
epic: postgres
blocks: [cead]
needs: [f176]
parent: 4474
---

# Phase 3c: Dev + ops workflow

## Goal

All operational workflows working against Postgres before cutover. No surprises on day one.

## 1. Public data distribution — DONE

**Format:** pg_dump custom (binary). Researchers who want the full normalized dataset can restore into a local Postgres instance (`docker run postgres` or similar). Everyone else uses the public API for structured access.

**Excluded tables (not public data):**
articles, keys, content_images, daily_stats, daily_page_stats, daily_referrer_stats, daily_device_stats, daily_browser_stats, schema_migrations, users, page_views, site_settings

No sanitization step needed — users table is excluded entirely.

**Rationale:** SQLite distribution doesn't make sense when the DB is Postgres. CSV requires denormalized views that need maintenance as the schema evolves. pg_dump is zero maintenance — just a command with exclusion flags. The public API covers the accessible/casual use case.

## 2. Snapshot pipeline — DONE

Replaces the current Litestream restore → validate → sanitize → upload workflow (`db-snapshot.yml`).

**Pipeline (GH Actions daily cron):**
1. Install `fly` CLI, authenticate with Fly token (already available for deploys)
2. `fly proxy` to production Postgres
3. Full pg_dump → upload to private S3 bucket (daily backup, 24hr RPO)
4. Filtered pg_dump (12 tables excluded) → upload to public S3 bucket
5. Kill proxy

Implemented in `.github/workflows/db-snapshot.yml`. Requires three GitHub secrets: `PG_USERNAME`, `PG_PASSWORD`, `PG_DBNAME`.

## 3. Dev workflow — DONE

- `make download-db` — downloads full pg_dump from private S3 bucket, restores into local `gallformers_dev`
- `make check-db` — verify local Postgres has data (error message updated)
- Requires `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` in `.env`
- `.env.sample` created with all local dev env vars

## 4. Fly config — DONE

fly.toml reviewed — already correct for Postgres. No `DATABASE_PATH` to remove. `DATABASE_URL` is set via `fly secrets`. `WCVP_DATABASE_PATH` stays for SQLite WCVP. Volume mount stays for request logs + WCVP.

## 5. Conversion tool: remote support — DONE

Solved by `scripts/pg-load.sh` — uses `fly proxy` to tunnel, `pg_restore` into remote Postgres. Tested end-to-end on preview.

## Output
- [x] Public data distribution approach decided
- [x] Snapshot pipeline implemented (`db-snapshot.yml`)
- [x] Dev workflow updated (`make download-db`, `check-db`, `.env.sample`)
- [x] Fly config verified — no changes needed
- [x] Conversion tool verified against remote Postgres
- [x] About page updated (database download section — new format, new URL)
