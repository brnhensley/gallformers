# Runbook: Restore Database

## Purpose
Restore the SQLite database from backup after corruption or data loss.

## When to Use
- Migration failed and corrupted data
- Accidental data deletion
- Database file corrupted
- Need to recover to a point-in-time state

## Prerequisites
- `flyctl` CLI installed and authenticated
- Access to Fly.io app `gallformers`
- Access to backup storage (S3 bucket `gallformers-backups`)

## Important
Database restoration will cause **data loss** for any changes made after the backup point. Coordinate with stakeholders before proceeding.

## Understanding the Setup

- Database location: `/data/gallformers.sqlite` (on Fly.io volume)
- Volume persists across deployments
- Backups managed by Litestream (continuous replication)

## Procedure

### 1. Assess the Situation

Determine:
- [ ] What caused the corruption/loss?
- [ ] When did the problem start?
- [ ] What is the acceptable data loss window?

### 2. Stop the Application

Prevent further writes while restoring:

```bash
fly machines list -a gallformers
fly machines stop <MACHINE_ID> -a gallformers
```

### 3. Connect to the Machine

```bash
fly ssh console -a gallformers
```

### 4. Backup Current State

Even if corrupted, preserve the current database for analysis:

```bash
cp /data/gallformers.sqlite /data/gallformers.sqlite.corrupted.$(date +%Y%m%d%H%M%S)
```

### 5. Restore from Litestream

Litestream continuously replicates to S3. Restore to latest:

```bash
# Set credentials (or export as env vars)
export LITESTREAM_ACCESS_KEY_ID=<from fly secrets>
export LITESTREAM_SECRET_ACCESS_KEY=<from fly secrets>

# Restore latest backup
litestream restore -o /data/gallformers.sqlite s3://gallformers-backups/litestream
```

To restore to a specific point in time:

```bash
# Use ISO 8601 timestamp
litestream restore -o /data/gallformers.sqlite \
  -timestamp "2026-01-08T15:30:00Z" \
  s3://gallformers-backups/litestream
```

To list available snapshots/generations:

```bash
litestream snapshots s3://gallformers-backups/litestream
litestream generations s3://gallformers-backups/litestream
```

### 6. Restore from Manual Backup

If restoring from a manual backup file:

```bash
# Copy backup to the machine (from local)
fly ssh sftp shell -a gallformers
put /path/to/backup.sqlite /data/gallformers.sqlite

# Or download from remote storage
curl -o /data/gallformers.sqlite <BACKUP_URL>
```

### 7. Verify Database Integrity

```bash
sqlite3 /data/gallformers.sqlite "PRAGMA integrity_check;"
```

Expected output: `ok`

### 8. Restart Application

Exit SSH session, then:

```bash
fly machines start <MACHINE_ID> -a gallformers
```

### 9. Verify Application

```bash
curl -s -o /dev/null -w "%{http_code}" https://gallformers.fly.dev/health
```

Expected: `200`

Check logs:

```bash
fly logs -a gallformers --no-tail | head -30
```

## Verification Checklist

- [ ] Database integrity check passes
- [ ] Application starts without errors
- [ ] Health endpoint returns 200
- [ ] Data appears correct (spot check key records)

## If Restoration Fails

1. Try an older backup point
2. Check Litestream logs for replication issues
3. If no valid backup available, escalate immediately

## Post-Restoration

1. Document the incident and data loss window
2. Notify affected users if data was lost
3. Investigate root cause
4. Verify backup system is functioning correctly
5. Consider if code rollback is also needed (see [Rollback Deployment](./rollback-deployment.md))
