# Database Backup Runbook

This document describes the automated backup process for the Gallformers database, including PII handling and how to access backups.

## Overview

Gallformers uses a two-tier backup strategy:

1. **Litestream** - Continuous replication to S3 (near real-time)
2. **Daily snapshots** - GitHub Actions workflow creating point-in-time snapshots

## Backup Locations

| Bucket | Path | Access | Contents |
|--------|------|--------|----------|
| `gallformers-backups` | `/litestream/` | Private | Litestream continuous replication |
| `gallformers-backups` | `/public/gallformers.sqlite` | Public | Daily sanitized snapshot (no PII) |
| `gallformers-full-backups` | `/{date}/gallformers.sqlite` | Private | Daily full backup (contains PII) |

All buckets are in AWS region `us-east-1`.

## Daily Snapshot Workflow

The GitHub Actions workflow (`.github/workflows/db-snapshot.yml`) runs daily at 6 AM UTC:

1. **Restore from Litestream** - Downloads the latest database state from Litestream replication
2. **Upload full backup** - Copies the complete database (with PII) to `gallformers-full-backups`
3. **Sanitize user data** - Removes all personally identifiable information from the users table
4. **Upload public snapshot** - Uploads the sanitized database to `gallformers-backups/public/`

### Manual Trigger

The workflow can be triggered manually from GitHub Actions if an immediate snapshot is needed.

## PII Sanitization

The daily snapshot sanitizes the `users` table before creating the public download. The following fields are modified:

| Field | Sanitization |
|-------|-------------|
| `display_name` | Set to NULL |
| `nickname` | Set to NULL |
| `inaturalist_url` | Set to NULL |
| `social_url` | Set to NULL |
| `personal_url` | Set to NULL |
| `auth0_id` | Replaced with `redacted-{id}` |

The `show_on_about` flag and timestamps are preserved as they are not PII.

## Downloading Backups

### Public Snapshot (Sanitized)

The sanitized daily snapshot is publicly accessible:

```bash
# Direct download
curl -O https://gallformers-backups.s3.amazonaws.com/public/gallformers.sqlite

# Via AWS CLI
aws s3 cp s3://gallformers-backups/public/gallformers.sqlite ./gallformers.sqlite

# Via v2 Makefile (recommended for development)
cd v2 && make download-db
```

### Full Backup (Contains PII)

Full backups require AWS credentials with access to the `gallformers-full-backups` bucket.

**Who can access full backups:**
- Project maintainers with AWS access
- Authorized researchers (contact maintainers)

**To download a full backup:**

```bash
aws s3 ls s3://gallformers-full-backups/  # List available dates
aws s3 cp s3://gallformers-full-backups/2026-01-18/gallformers.sqlite ./gallformers.sqlite
```

## Litestream Configuration

Litestream runs as a sidecar process on Fly.io, providing continuous replication:

- **Replication frequency**: Near real-time (every few seconds)
- **Retention**: Managed by Litestream generations
- **Location**: `s3://gallformers-backups/litestream/`

To restore from Litestream:

```bash
litestream restore -o gallformers.sqlite s3://gallformers-backups/litestream
```

See [database-recovery.md](database-recovery.md) for full recovery procedures.

## Monitoring

### Checking Snapshot Sizes

Healthy snapshots should be approximately 5-6MB. Very small snapshots (~300 bytes) indicate corruption:

```bash
aws s3 ls s3://gallformers-backups/public/ --human-readable
aws s3 ls s3://gallformers-full-backups/ --recursive --human-readable | tail -10
```

### GitHub Actions History

Check the workflow run history for any failures:

```bash
gh run list --workflow=db-snapshot.yml --limit=10
```

## Related Documentation

- [database-recovery.md](database-recovery.md) - Recovery procedures for corrupted databases
- [deploy.md](deploy.md) - Deployment procedures
- Root CLAUDE.md - AWS infrastructure overview
- v2/docs/backup-setup.md - S3/IAM configuration details
