# Database Recovery Runbook (V2 - Fly.io)

This runbook documents how to recover the production database when it becomes corrupted or needs to be replaced.

## Background

V2 uses SQLite with Litestream for continuous replication to S3. This creates complexity when replacing the database file because:

1. **SQLite WAL mode**: SQLite stores uncommitted transactions in a Write-Ahead Log (WAL) file. Copying just the `.sqlite` file without the `-wal` and `-shm` files can result in data loss.

2. **Litestream generations**: Litestream tracks database state in "generations". If it detects a different database file, it starts a new generation and begins replicating from scratch - potentially overwriting good backups with bad state.

## Symptoms of Database Corruption

- App logs show `no such table: gall` or similar errors
- Homepage fails to load with 500 errors
- Litestream S3 shows tiny snapshots (~300 bytes instead of ~6MB)

## Recovery Procedure

### 1. Download a known-good database

From the v2/ directory:

```bash
make download-db
```

This downloads the daily S3 snapshot from the V1 backup system.

### 2. Run migrations locally

```bash
mix ecto.migrate
```

Verify the database is intact:

```bash
sqlite3 priv/gallformers.sqlite "SELECT COUNT(*) FROM gall; SELECT COUNT(*) FROM species; SELECT COUNT(*) FROM host;"
```

Expected output: ~3800 galls, ~5700 species, ~8000 hosts.

### 3. Stop the production machine

**Critical**: The app MUST be stopped before replacing the database, otherwise Litestream will start a new generation with corrupted state.

```bash
fly machine stop <machine-id>
```

Get the machine ID from `fly status`.

### 4. Start the machine briefly to delete old files

```bash
fly machine start <machine-id>
```

Wait a few seconds, then delete the old database files one at a time:

```bash
fly ssh console -C "rm /data/gallformers.sqlite"
fly ssh console -C "rm /data/gallformers.sqlite-shm"
fly ssh console -C "rm /data/gallformers.sqlite-wal"
```

Verify deletion:

```bash
fly ssh console -C "ls /data/"
```

Should only show `lost+found`.

### 5. Upload the new database via SFTP

```bash
fly sftp put /full/path/to/v2/priv/gallformers.sqlite /data/gallformers.sqlite
```

Note: `fly sftp put` requires absolute paths and won't overwrite existing files.

### 6. Restart the machine

```bash
fly machine restart <machine-id>
```

Wait for health checks to pass:

```bash
fly status
```

### 7. Verify recovery

Check the logs for any database errors:

```bash
fly logs --no-tail | tail -50
```

Visit https://gallformers.fly.dev and spot-check key pages.

## Diagnosing Issues

### Check Litestream generations

```bash
aws s3 ls s3://gallformers-backups/litestream/generations/ --recursive | tail -30
```

Look for:
- **Healthy snapshots**: ~5-6MB (full database)
- **Corrupted snapshots**: ~300 bytes (empty database)

A sudden drop in snapshot size indicates when corruption occurred.

### Check what tables exist in prod

```bash
fly ssh console -C "sqlite3 /data/gallformers.sqlite '.tables'"
```

## Root Causes to Avoid

1. **Uploading database while app is running**: Litestream sees the change and starts a new generation, potentially with incomplete data.

2. **Copying only .sqlite file**: Missing WAL/SHM files can mean missing data that hasn't been checkpointed.

3. **Mixing WAL files from different database states**: SQLite will either ignore the WAL or corrupt the database.

## Prevention

- Always stop the app before replacing the database
- Delete ALL database files (.sqlite, -wal, -shm) before uploading new ones
- Verify the new database has expected table counts before restarting
- Monitor Litestream snapshot sizes after database changes

## Related

- [deploy.md](deploy.md) - Standard deployment procedures
- V2 CLAUDE.md - Database location and configuration details
