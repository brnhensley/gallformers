# Rollback Strategy for Gallformers V2

This document outlines how to identify bad deployments and roll back to a previous working state.

## Identifying Bad Deployments

### Health Check Failures

The API exposes a health endpoint that should return 200 OK:

```bash
curl https://gallformers-v2.fly.dev/health
```

A failed health check indicates the application is not starting correctly or cannot connect to its database.

### Checking Logs

View recent logs to identify errors:

```bash
# Stream live logs
fly logs -a gallformers-v2

# View recent logs
fly logs -a gallformers-v2 --no-tail
```

Look for:
- Panic/crash messages
- Database connection errors
- HTTP 5xx error patterns
- Migration failures

### Checking App Status

```bash
# Overall app status
fly status -a gallformers-v2

# Machine-level status
fly machines list -a gallformers-v2
```

### User Reports

Users may report issues before monitoring catches them. Common symptoms:
- Pages not loading
- Data not saving
- Unexpected error messages

## Rollback Commands

### Step 1: List Recent Releases

```bash
fly releases -a gallformers-v2
```

This shows recent deployments with their image IDs and timestamps. Identify the last known good release.

### Step 2: Roll Back to Previous Image

**Option A: Redeploy specific image (recommended)**

```bash
# Deploy the specific image from a previous release
fly deploy --image registry.fly.io/gallformers-v2:deployment-<id> -a gallformers-v2
```

**Option B: Update machine directly**

For faster rollback without going through the full deploy pipeline:

```bash
# Get machine ID
fly machines list -a gallformers-v2

# Update machine to previous image
fly machines update <machine-id> --image registry.fly.io/gallformers-v2:deployment-<id> -a gallformers-v2
```

### Step 3: Verify Rollback

```bash
# Check health
curl https://gallformers-v2.fly.dev/health

# Check logs for startup
fly logs -a gallformers-v2

# Verify app status
fly status -a gallformers-v2
```

## Database Considerations

### SQLite Persistence

The SQLite database is stored on a Fly.io volume at `/data/gallformers.sqlite`. This volume persists across deployments, meaning:

- Code rollbacks do not affect database state
- Database changes (migrations, data modifications) survive deployments
- Rolling back code does not undo database changes

### When Database Is Corrupted

If a migration or data change corrupted the database:

1. **Identify the issue**: Check logs for migration errors or data corruption symptoms
2. **Restore from backup**: Follow the backup restoration procedure (see backup-strategy.md when available)
3. **Then roll back code**: After restoring data, roll back the code if needed

### Code Rollback vs Data Rollback

| Scenario | Action |
|----------|--------|
| Bad code, database unchanged | Roll back code only |
| Failed migration | Restore database from backup, then roll back code |
| Bad data inserted | Restore database from backup (code may be fine) |
| Both code and data issues | Restore database first, then roll back code |

### Migration Rollback Considerations

If a migration ran but needs to be undone:

1. **If migration is reversible**: Write and run a down migration manually
2. **If migration is irreversible**: Restore database from backup

Future enhancement: Implement migration versioning with explicit down migrations.

## Emergency Procedures

### Complete Service Failure

If the app is completely down and unresponsive:

```bash
# Stop all machines
fly machines stop -a gallformers-v2 --select

# Start with previous image
fly machines update <machine-id> --image registry.fly.io/gallformers-v2:deployment-<id> -a gallformers-v2
fly machines start <machine-id> -a gallformers-v2
```

### Rollback During Active Incident

1. Communicate status (if applicable)
2. Identify the bad release: `fly releases -a gallformers-v2`
3. Roll back immediately: `fly deploy --image <previous-image> -a gallformers-v2`
4. Verify recovery: `curl https://gallformers-v2.fly.dev/health`
5. Investigate root cause after service is restored

## Prevention

To minimize rollback scenarios:

- Test migrations on a copy of production data before deploying
- Use preview deployments for testing (`preview` label on PRs)
- Monitor health checks and logs after each deployment
- Keep deployments small and incremental
- Maintain database backups on a regular schedule

## Quick Reference

```bash
# View releases
fly releases -a gallformers-v2

# Roll back to specific release
fly deploy --image registry.fly.io/gallformers-v2:deployment-<id> -a gallformers-v2

# Check health
curl https://gallformers-v2.fly.dev/health

# View logs
fly logs -a gallformers-v2

# App status
fly status -a gallformers-v2
```
