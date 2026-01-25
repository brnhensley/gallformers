# Runbook: Reset Production Database

## Purpose

Replace the production database with a completely new database file. This is different from [restoring from backup](./restore-database.md), which recovers from Litestream's continuous replication.

## When to Use

- **Initial deployment**: Bootstrapping a new production environment
- **Major data migration**: Replacing the database with a transformed/migrated version
- **Development reset**: Replacing production with a sanitized or test dataset
- **Disaster recovery**: When Litestream backups are unavailable or corrupted

## When NOT to Use

- **Point-in-time recovery**: Use [Restore Database](./restore-database.md) instead
- **Recovering recent data**: Litestream has continuous backups; use restore
- **Routine maintenance**: This is a destructive operation

## Prerequisites

- AWS CLI configured with credentials for `gallformers-backups` bucket
- GitHub access to run workflows on `gallformers` repository
- The replacement database file, validated and ready

## Important

This operation **replaces all production data**. There is no undo unless you kept the old volume (default behavior). Coordinate with stakeholders before proceeding.

## Understanding the Workflow

The reset workflow uses a **volume-swap approach**:

1. Creates a new Fly.io volume
2. Populates it with your database via a temporary machine
3. Clones the production machine with the new volume attached
4. Waits for health checks to pass
5. Verifies database content (species count)
6. Destroys the old machine
7. Clears Litestream state for fresh replication
8. Archives the source file from S3

**Benefits:**
- Zero downtime (old machine serves traffic until new one is ready)
- Automatic rollback if health checks fail
- Old volume preserved for manual rollback

## Procedure

### 1. Prepare the Database File

The database must meet these requirements:

- [ ] Valid SQLite database (passes `PRAGMA integrity_check`)
- [ ] Contains `species` table with 5000+ records (sanity check)
- [ ] Schema compatible with current application migrations
- [ ] No WAL or SHM files (should be a clean single-file database)

Validate locally:

```bash
sqlite3 your-database.sqlite "PRAGMA integrity_check;"
# Expected: ok

sqlite3 your-database.sqlite "SELECT COUNT(*) FROM species;"
# Expected: 5000+ (current production has ~5800)
```

If your database has WAL mode enabled, checkpoint it first:

```bash
sqlite3 your-database.sqlite "PRAGMA wal_checkpoint(TRUNCATE);"
```

### 2. Upload to S3

Use the Makefile target:

```bash
make upload-reset-db FILE=/path/to/your-database.sqlite
```

This uploads to `s3://gallformers-backups/reset/gallformers.sqlite`.

Verify the upload:

```bash
aws s3 ls s3://gallformers-backups/reset/
```

### 3. Run the Workflow

1. Go to **GitHub Actions** → **Reset Production Database**
2. Click **Run workflow**
3. Confirm the S3 path (default: `s3://gallformers-backups/reset/gallformers.sqlite`)
4. Choose whether to keep the old volume for rollback (recommended: `true`)
5. Type `RESET` in the confirmation field
6. Click **Run workflow**

### 4. Monitor Execution

The workflow takes approximately 3-5 minutes. Watch for:

1. **Verify prerequisites** - Checks Fly access, confirms single machine
2. **Download and validate** - Downloads DB, checks integrity and species count
3. **Create new volume** - Creates empty volume in same region
4. **Populate volume** - One-off machine downloads DB from S3 to volume
5. **Clone machine** - Creates new machine with new volume
6. **Wait for healthy** - Polls until health checks pass (up to 5 min)
7. **Verify content** - SSH check of species count
8. **Clear Litestream** - Removes old backup generations
9. **Destroy old machine** - Removes previous machine
10. **Archive source** - Moves S3 file to `processed/` folder

### 5. Verify Success

After the workflow completes:

```bash
# Check health endpoint
curl -s https://gallformers.fly.dev/health

# Check machine status
flyctl status -a gallformers

# Verify data (spot check)
flyctl ssh console -a gallformers -C "sqlite3 /data/gallformers.sqlite 'SELECT COUNT(*) FROM species;'"
```

## Rollback Procedures

The rollback procedure depends on when the failure occurred.

### Scenario A: Workflow failed before clone completed

**Symptoms:** Workflow errored during volume creation or population steps.

**State:** New volume may exist, but no new machine was created.

**Recovery:**

```bash
# List volumes
flyctl volumes list -a gallformers

# Delete the orphaned reset volume (if it exists)
flyctl volumes destroy vol_xxx -a gallformers
```

Production is unaffected; the original machine is still running.

### Scenario B: Workflow failed after clone, before old machine destroyed

**Symptoms:** Workflow errored during health check or verification. Automatic rollback may have destroyed the new machine.

**State:** Two machines may exist, or only the original remains.

**Recovery:**

```bash
# Check machine state
flyctl machines list -a gallformers

# If two machines exist, destroy the NEW one (check creation time)
flyctl machine destroy <NEW_MACHINE_ID> -a gallformers --force

# Delete the new volume
flyctl volumes list -a gallformers
flyctl volumes destroy <NEW_VOLUME_ID> -a gallformers
```

### Scenario C: Workflow completed but new database is wrong

**Symptoms:** App is running but data is incorrect, missing, or corrupted.

**Prerequisites:** You kept the old volume (workflow default: `keep_old_volume=true`).

**State:** New machine running with new volume. Old volume still exists.

**Recovery:**

```bash
# List current state
flyctl machines list -a gallformers
flyctl volumes list -a gallformers

# Identify the OLD volume (check creation date - it's the older one)
# Example: vol_abc123 (old), vol_xyz789 (new/current)

# Get current machine ID
CURRENT_MACHINE=$(flyctl machines list -a gallformers --json | jq -r '.[0].id')
OLD_VOLUME="vol_abc123"  # The older volume from the list

# Clone current machine with the OLD volume to restore
flyctl machine clone $CURRENT_MACHINE -a gallformers \
  --attach-volume "$OLD_VOLUME:/data" \
  --region iad

# Wait for the restored machine to be healthy
flyctl machines list -a gallformers
# Verify the new machine shows "started" and health checks pass

# Once healthy, destroy the bad machine
flyctl machine destroy $CURRENT_MACHINE -a gallformers --force

# Clear Litestream state (important - prevents mixing backup generations)
aws s3 rm s3://gallformers-backups/litestream/ --recursive

# Clean up the bad volume
flyctl volumes list -a gallformers
flyctl volumes destroy <BAD_VOLUME_ID> -a gallformers
```

### Scenario D: Workflow completed, old volume was deleted, need to restore

**Symptoms:** You chose `keep_old_volume=false` and now need to go back.

**Recovery:** Use the [Restore Database](./restore-database.md) runbook to restore from Litestream backups. Note that Litestream state was cleared, so you'll need to restore from the backup generations that existed before the reset.

If Litestream backups are unavailable, check for the original database in processed files:

```bash
aws s3 ls s3://gallformers-backups/reset/processed/
```

## Verification Checklist

After reset or rollback:

- [ ] Health endpoint returns 200
- [ ] Species count matches expected
- [ ] Sample pages load correctly (e.g., `/species`, `/hosts`)
- [ ] Admin functions work (if applicable)
- [ ] Litestream is replicating (check logs after a few minutes)

## Cleanup

After confirming the reset is successful and stable (recommend waiting 24 hours):

```bash
# Delete the old volume if you kept it
flyctl volumes list -a gallformers
flyctl volumes destroy <OLD_VOLUME_ID> -a gallformers

# Archived source files are kept in S3 for reference
aws s3 ls s3://gallformers-backups/reset/processed/
```

## Troubleshooting

### Workflow hangs on "Wait for healthy"

The machine may be failing to start. Check logs:

```bash
flyctl logs -a gallformers
```

Common causes:
- Database schema incompatible with current migrations
- Database file permissions (should be 644)
- Volume attachment issues

### Species count mismatch

The workflow validates that the species count on the new machine matches what was uploaded. If this fails:

1. Check if the one-off machine properly downloaded the file
2. Verify the S3 file wasn't corrupted during upload
3. Re-upload and try again

### "Expected exactly 1 machine" error

The workflow requires a single-machine deployment. If you have multiple machines:

```bash
flyctl machines list -a gallformers
# Investigate why multiple machines exist and consolidate if appropriate
```

## Related Runbooks

- [Restore Database](./restore-database.md) - Point-in-time recovery from Litestream
- [Rollback Deployment](./rollback-deployment.md) - Rolling back code changes
- [Diagnose Deployment Issue](./diagnose-deployment-issue.md) - General troubleshooting
