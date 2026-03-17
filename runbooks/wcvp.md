# WCVP (World Checklist of Vascular Plants) Operations

## Overview

The WCVP integration uses a **separate Postgres database** (`wcvp`) on the same cluster as the main gallformers database. It contains plant taxonomy and distribution data from Kew Gardens, used for host plant lookups, POWO-WCVP refresh, and range reconciliation.

One supporting file works alongside the database:

| File | Purpose | Location |
|------|---------|----------|
| `tdwg_to_places.json` | Static mapping from all 368 TDWG L3 botanical region codes to gallformers place codes (global coverage) | Bundled in release under `priv/repo/data/` |

## Architecture

```
Wcvp.Lookup          — search/get queries against Repo.WCVP (wcvp database)
Wcvp.Tdwg            — TDWG-to-places mapping (reads tdwg_to_places.json)
Wcvp.WcvpName        — Ecto schema for wcvp_names table (typed structs)
Wcvp.WcvpDistribution — Ecto schema for wcvp_distributions table
Repo.WCVP            — read-only Ecto repo for the separate wcvp database
```

## Environment-Specific Flow

### Local Development

| Item | Details |
|------|---------|
| **wcvp database** | Local Postgres database named `wcvp` |
| **tdwg_to_places.json** | `priv/repo/data/tdwg_to_places.json` — checked into repo |
| **Config** | `config/dev.exs` sets `database: "wcvp"` for Repo.WCVP |
| **Repo startup** | Repo.WCVP starts unconditionally in supervision tree |

**Setting up WCVP locally:**

```bash
# Option A: Restore from S3 (recommended — gives you the same data as production)
make wcvp-restore

# Option B: Build from Kew CSVs
mix gallformers.wcvp.download          # download ~85MB zip from Kew
mix gallformers.wcvp.build_db          # process CSVs, load into local wcvp DB

# Option C: Build and upload to S3 (for distributing to other environments)
mix gallformers.wcvp.build_db --upload  # builds locally + pg_dump + upload to S3
```

### Preview (gallformers-preview.fly.dev)

| Item | Details |
|------|---------|
| **wcvp database** | `wcvp` database on the same Fly Postgres cluster |
| **tdwg_to_places.json** | Bundled in release |
| **Config** | Derived from `DATABASE_URL` in `config/runtime.exs` |

**Loading data**: pg_restore via fly proxy from the S3 dump artifact.

### Production (gallformers.fly.dev)

| Item | Details |
|------|---------|
| **wcvp database** | `wcvp` database on the gallformers-db Fly Postgres cluster |
| **tdwg_to_places.json** | Bundled in release |
| **Config** | Derived from `DATABASE_URL` in `config/runtime.exs` |

**Loading data**: pg_restore via fly proxy from the S3 dump artifact.

## Configuration

Repo.WCVP is configured per-environment:

- **dev/test**: `config/dev.exs` / `config/test.exs` — database name, local Postgres credentials
- **prod**: `config/runtime.exs` — derived from `DATABASE_URL` by replacing the database name with `wcvp`

The database is NOT managed by Ecto migrations. Tables are created and populated by the build task (`mix gallformers.wcvp.build_db`).

## Updating WCVP Data

When WCVP source data needs to be refreshed (new Kew release, corrections, etc.):

```bash
# 1. Download latest CSV files from Kew
mix gallformers.wcvp.download

# 2. Build into local wcvp database + pg_dump + upload to S3
mix gallformers.wcvp.build_db --upload

# 3. Restore on production via fly proxy
fly proxy 15432:5432 -a gallformers-db
pg_restore --clean --if-exists --no-owner --no-acl \
  -d wcvp -h localhost -p 15432 /tmp/wcvp.dump

# 4. Same for preview if needed
```

## First-Time Setup (New Environment)

For a new Fly Postgres cluster or local dev machine:

```bash
# 1. Create the wcvp database
createdb wcvp          # local
# OR via fly proxy: CREATE DATABASE wcvp;

# 2. Restore data from S3
mix gallformers.wcvp.restore   # local dev
# OR pg_restore via fly proxy for prod/preview
```

## Cutover from SQLite to Postgres

One-time migration procedure. Sequence matters — data must be in Postgres
before deploying the code that expects it there.

### Prerequisites

- [ ] Branch `wcvp-postgres-migration` merged to main
- [ ] CI passing on main
- [ ] Local WCVP data is current (run `mix gallformers.wcvp.download && mix gallformers.wcvp.build_db` if stale)
- [ ] `pg_dump` and `pg_restore` versions match or exceed Fly Postgres version

### Step 1: Build and upload the S3 artifact

On your local machine:

```bash
mix gallformers.wcvp.build_db --upload
```

This builds the wcvp database locally, pg_dumps it, and uploads to S3 at
`public/wcvp.dump`. Verify the upload:

```bash
curl -sI https://gallformers-backups.s3.amazonaws.com/public/wcvp.dump | head -5
# Should show HTTP 200 and a reasonable Content-Length
```

### Step 2: Create the wcvp database on Fly

```bash
fly proxy 15432:5432 -a gallformers-db
```

In another terminal:

```bash
psql -h localhost -p 15432 -U gallformers -d postgres -c "CREATE DATABASE wcvp;"
```

Verify:

```bash
psql -h localhost -p 15432 -U gallformers -d wcvp -c "SELECT 1;"
# Should return 1 (database exists and is connectable)
```

### Step 3: Restore WCVP data into Fly Postgres

Download the dump from S3 first:

```bash
curl -fSL -o /tmp/wcvp.dump https://gallformers-backups.s3.amazonaws.com/public/wcvp.dump
```

Then restore:

```bash
pg_restore --no-owner --no-acl -d wcvp -h localhost -p 15432 -U gallformers /tmp/wcvp.dump
```

Verify:

```bash
psql -h localhost -p 15432 -U gallformers -d wcvp -tAc "SELECT count(*) FROM wcvp_names"
# Should show ~1M+ rows
psql -h localhost -p 15432 -U gallformers -d wcvp -tAc "SELECT value FROM meta WHERE key = 'built_at'"
# Should show a recent ISO 8601 timestamp
```

### Step 4: Deploy the new code

```bash
fly deploy
```

Watch startup logs to confirm Repo.WCVP connects:

```bash
fly logs 2>&1 | timeout 15 cat
# Look for Repo.WCVP startup (no errors about missing database)
```

### Step 5: Verify on production

1. Go to an admin host page (e.g., `/admin/hosts/1`)
2. Confirm the WCVP section loads — search should work, "WCVP data:" date should show
3. Go to Host Range Review (`/admin/host-range`)
4. Confirm "WCVP data:" badge shows with the correct date
5. Try a WCVP search and refresh on a test host

### Step 6: Repeat for preview

```bash
# Same fly proxy + CREATE DATABASE + pg_restore steps, but with:
fly proxy 15432:5432 -a gallformers-preview-db
# (or whatever the preview DB app is named)
```

### Step 7: Clean up old SQLite artifacts

After verifying both environments:

```bash
# Remove WCVP_DATABASE_PATH from Fly secrets (no longer used)
fly secrets unset WCVP_DATABASE_PATH -a gallformers
fly secrets unset WCVP_DATABASE_PATH -a gallformers-preview

# Delete the SQLite file from the Fly volume
# (via fly ssh console or SFTP — the docker-entrypoint.sh no longer downloads it)
fly ssh console -a gallformers -C "rm -f /data/wcvp.sqlite"

# Optionally delete the old S3 SQLite artifact (keep for a week as rollback)
# aws s3 rm s3://gallformers-backups/public/wcvp.sqlite
```

### Rollback

If something goes wrong after deploy:

1. **Quick fix**: Redeploy the previous release (code reverts to SQLite adapter)
2. **Data is safe**: The main gallformers database is untouched — WCVP is a separate database
3. **SQLite file**: Still on the Fly volume at `/data/wcvp.sqlite` until you delete it in Step 7
4. **S3 artifact**: `public/wcvp.sqlite` still on S3 until you delete it in Step 7

The old code expects `WCVP_DATABASE_PATH` env var — if you need to rollback, re-set it:

```bash
fly secrets set WCVP_DATABASE_PATH=/data/wcvp.sqlite -a gallformers
```

## Git and Docker Status

- `.gitignore`: `priv/data/` — WCVP CSV files not committed (build artifacts)
- `.dockerignore`: `priv/repo/data/wcvp/` — excluded from build context
- `docker-entrypoint.sh`: No WCVP steps (data lives in Postgres, not on the volume)

## File Path Resolution

`Wcvp.Tdwg.load/0` reads `tdwg_to_places.json` using `Application.app_dir/2`:

```elixir
Application.app_dir(:gallformers, "priv/repo/data/tdwg_to_places.json")
```

This resolves correctly in both dev (project root) and releases (inside the release lib directory). **Do not use relative paths like `"priv/..."` directly** — they break in releases where the CWD is `/app/` but priv files are nested under `/app/lib/gallformers-<version>/priv/`.

## Troubleshooting

### WCVP data missing

1. Check if the wcvp database exists and has data:
   ```bash
   psql -d wcvp -tAc "SELECT count(*) FROM wcvp_names"
   ```

2. If empty or missing, restore from S3:
   ```bash
   make wcvp-restore   # local dev
   ```

### WCVP button not showing in admin

The "Refresh from POWO-WCVP" button is gated on `@wcvp_available` which calls `Wcvp.Lookup.available?/0`. If the button is missing:

1. Check that Repo.WCVP is in the supervision tree (startup logs)
2. Check that the wcvp database has tables and data
3. Try `Wcvp.Lookup.available?()` from iex

### "No matching species found" error

The refresh handler looks up the host by `wcvp_id` first, then falls back to name search. If neither matches, you get this error. Check that the host name in gallformers matches a WCVP accepted name.

### Crash on refresh button click

If the WCVP lookup succeeds but `build_wcvp_diff` crashes, check that `tdwg_to_places.json` is accessible. In a release, it must be resolved via `Application.app_dir/2`, not a relative path.
