# PostgreSQL Migration — Post-Cutover Reference

Production was cut over from SQLite to Postgres on 2026-03-16. Soak period verified stable through 2026-03-25.

## Architecture

| Environment | App | Database | DB App |
|-------------|-----|----------|--------|
| Local dev | N/A | `gallformers_dev` (local Postgres) | N/A |
| Preview | `gallformers-preview` | Fly Postgres | `gallformers-preview-db` (to be provisioned) |
| Production | `gallformers` | Fly Postgres | `gallformers-db` |

## Post-Cutover Cleanup

- [x] Cutover executed (2026-03-16)
- [x] 7-day soak verified stable (2026-03-25)
- [x] Code cleanup: deleted `litestream-preview.yml`, `scripts/pg-load.sh`, removed SQLite from Dockerfile
- [ ] Delete SQLite file from production volume (`/data/gallformers.sqlite`)
- [ ] Delete Litestream data from S3: `aws s3 rm s3://gallformers-backups/litestream/ --recursive`
- [ ] Update infra code: rename IAM user/policy from Litestream-era names, update S3 comments
- [ ] `tofu apply` to apply infra changes
- [ ] Rename GitHub Actions secrets from `LITESTREAM_*` to `BACKUP_AWS_*` (optional, cosmetic)
- [ ] Provision `gallformers-preview-db` for preview environment

The production volume stays — it holds WCVP data, boundaries, and request logs.

## Ongoing Operations

### Local dev database

```bash
make download-db    # Downloads latest pg_dump from S3, restores into gallformers_dev
```

### Connect to production Postgres

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
fly status -a gallformers-db
fly machine list -a gallformers-db
fly checks list -a gallformers-db
```

### Fly Postgres backups

```bash
fly postgres barman check -a gallformers-db
fly postgres barman backup list -a gallformers-db
```

### Daily snapshots

The GitHub Actions workflow `db-snapshot.yml` runs daily at 6 AM UTC:
1. `fly proxy` to production Postgres
2. Full pg_dump → `gallformers-full-backups` (private, all tables)
3. Filtered pg_dump → `gallformers-backups/public/` (public, excludes PII/analytics)

IAM user `litestream-gallformers` provides S3 access (name is historical from SQLite era).
