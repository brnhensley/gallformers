# PostgreSQL Migration Cutover

Procedures for loading data into Fly Postgres and cutting production over from SQLite.

## Architecture Overview

| Environment | App | Database | DB App |
|-------------|-----|----------|--------|
| Local dev | N/A | `gallformers_dev` (local Postgres) | N/A |
| Preview | `gallformers-preview` | Fly Postgres | `gallformers-preview-db` (post-cutover) |
| Production | `gallformers` | SQLite on volume (current) | N/A |
| Production (post-cutover) | `gallformers` | Fly Postgres | `gallformers-db` (repurposed from preview) |

The data pipeline is automated by `scripts/pg-load.sh`. See the script for details.

## Production Cutover (Phase 4)

This section is a high-level plan. The exact commands will be refined during rehearsal on the preview environment.

### Pre-cutover (weeks before)

1. **Repurpose `gallformers-db` for production:**
   - Detach from preview: `fly postgres detach gallformers-preview -a gallformers-db` (verify detach works beforehand — low risk, can reattach)
   - Disable auto-stop on `gallformers-db` — production must stay running
   - Attach to production: `fly postgres attach gallformers-db --app gallformers` (creates user, database, sets DATABASE_URL — save the credentials from the output)
   - Set GitHub secrets: `gh secret set PG_PASSWORD`, `gh secret set PG_USERNAME`, `gh secret set PG_DBNAME`
   - Update local `.env` with production credentials (PG_PROD_* vars)
   - Clean up orphaned Litestream secrets: `fly secrets unset LITESTREAM_ACCESS_KEY_ID LITESTREAM_SECRET_ACCESS_KEY -a gallformers`
2. **Rehearse** the full cutover procedure on preview at least once.
3. **Announce** maintenance window on Discord and the site maintenance banner.

### Litestream health check (before cutover)

Before putting the site in read-only mode, verify litestream is healthy. A bad state means a corrupt or stale restore.

1. **Check for a single generation:**
   ```bash
   aws s3 ls s3://gallformers-backups/litestream/generations/
   ```

2. **Verify a recent snapshot exists:**
   ```bash
   aws s3 ls s3://gallformers-backups/litestream/generations/<gen-id>/snapshots/
   ```
   Should be within the last 24h (snapshot-interval is 24h).

3. **Check WAL segment count is reasonable:**
   ```bash
   aws s3 ls s3://gallformers-backups/litestream/generations/<gen-id>/wal/ --recursive | wc -l
   ```
   Should be in the hundreds, not thousands. If 8000+, snapshots may not be working — investigate before proceeding.

4. **If anything looks wrong:** Do NOT proceed. A deploy restarts litestream and forces a new snapshot — that may be sufficient to fix it.

### Cutover procedure

| Step | Action | Verify |
|------|--------|--------|
| 1 | Run litestream health check (above) | Snapshot recent, WAL count reasonable |
| 2 | Put site in read-only mode (auth plug flag) | Admin pages reject writes |
| 3 | Wait for in-flight requests to drain (~1 min) | Check fly logs |
| 4 | Run `scripts/pg-load.sh -e .env` | Choose option 2 (Litestream) |
| | Script handles: litestream restore → convert → pg_dump → proxy → pg_restore → stage secret → deploy | Each step has interactive confirmation |
| 5 | Soak test under real traffic | Browse pages, search, maps, keys. Check Fly dashboard. Tail logs. |
| 6 | If something is wrong — rollback (see below) | |
| 7 | Turn off read-only mode | Writes now go to Postgres |
| 8 | Turn off maintenance banner | |

The pg-load script uses debug-level litestream logging so WAL replay progress is visible. It stages the DATABASE_URL secret without restarting, then deploys — one restart total.

### Rollback plan

At any point before step 7 (enabling writes), rollback is zero-data-loss:

Run
```bash
fly releases -a gallformers --image
```
to find the previous release image name (DOCKER IMAGE column).

Then run
```bash
fly deploy --image <previous-release-image>   # Reverts to SQLite-backed release
```

The SQLite database on the volume is untouched. Litestream continues replicating. No data is lost because the site was in read-only mode the entire time.

**After writes are enabled on Postgres** (step 7), rollback means losing any new writes since cutover. This is why the soak period in read-only mode matters.

**Keep rollback capability for 7 days** after cutover:
- Do NOT delete SQLite from the volume
- Do NOT remove Litestream secrets
- Do NOT remove Litestream infrastructure

### Post-cutover cleanup (after soak period)

Only after 7+ days of stable operation:

1. Delete SQLite file from the volume (volume stays for WCVP, boundaries, request logs)
2. Remove Litestream secrets: `fly secrets unset LITESTREAM_ACCESS_KEY_ID LITESTREAM_SECRET_ACCESS_KEY -a gallformers`
3. Update OpenTofu definitions in `infra/` to remove Litestream S3 paths and IAM user
4. `tofu apply` and commit infra changes

## Ongoing Operations

### Refresh preview data

```bash
scripts/pg-load.sh -e .env
```

Choose option 1 (S3 download) for routine refreshes.

### Connect to preview Postgres for debugging

```bash
# Terminal 1: open proxy
fly proxy 15432:5432 -a gallformers-db

# Terminal 2: connect with psql
psql --host=localhost --port=15432 \
  --username=gallformers_preview \
  --dbname=gallformers_preview
```

### Connect to production Postgres for debugging (post-cutover)

```bash
# Terminal 1: open proxy
fly proxy 15432:5432 -a gallformers-db

# Terminal 2: connect with psql
psql --host=localhost --port=15432 \
  --username=<prod-username> \
  --dbname=<prod-database>
```

Credentials are in the `DATABASE_URL` secret on the `gallformers` app.

**Reminder:** CLAUDE.md prohibits querying the production database directly via `fly ssh console` with `rpc` or `eval`. Use `fly proxy` + local psql instead.

### Check Fly Postgres health

```bash
fly status -a gallformers-db              # Preview
fly status -a gallformers-db         # Production (post-cutover)
fly machine list -a gallformers-db        # Machine state
fly checks list -a gallformers-db         # Health checks
```

### Fly Postgres backups

Fly Postgres (postgres-flex) includes barman for automated backups, but this has not been verified yet. Before production cutover, confirm:

```bash
fly postgres barman check -a gallformers-db
fly postgres barman backup list -a gallformers-db
```

Verify these work before production cutover.
