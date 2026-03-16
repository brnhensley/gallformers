# Private S3 Bucket for Full Database Backups

This document describes the private S3 bucket used for storing full (unsanitized) database backups.

## Overview

| Property | Value |
|----------|-------|
| Bucket name | `gallformers-full-backups` |
| Region | `us-east-1` |
| Access | Private (IAM only) |
| Versioning | Enabled |
| Created | 2026-01-18 |

## Purpose

This bucket stores **full daily pg_dump backups containing all tables including PII** (user emails, etc.). These backups are NOT filtered and should never be made public.

Use cases:
- Disaster recovery (24hr RPO)
- Developer local database (`make download-db` pulls from this bucket)
- Legal/compliance data retention
- Point-in-time recovery with full user context

## Access Control

**IAM Policy**: `LitestreamGallformersBackup` (shared with `gallformers-backups` bucket; name is historical from the SQLite/Litestream era)

**IAM User**: `litestream-gallformers` (name is historical)

The same credentials used for database backups have access to this bucket. No additional secrets are needed.

## Comparison with Other Buckets

| Bucket | Access | Contains PII | Use |
|--------|--------|--------------|-----|
| `gallformers-images-us-east-1` | Public | No | Production images |
| `gallformers-backups` | Mixed | No | Public pg_dump snapshots (filtered, no PII) + legacy Litestream data |
| `gallformers-full-backups` | Private | **Yes** | Full daily pg_dump backups (all tables) |

## GitHub Actions Usage

The daily snapshot workflow (`db-snapshot.yml`) uploads a full pg_dump here:

```yaml
- name: Upload full backup (private)
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.LITESTREAM_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.LITESTREAM_SECRET_ACCESS_KEY }}
    AWS_DEFAULT_REGION: us-east-1
  run: |
    aws s3 cp gallformers.dump s3://gallformers-full-backups/$(date +%Y-%m-%d)/gallformers.dump
```

## Lifecycle Policy (Optional)

To control costs, consider adding a lifecycle rule to expire old backups:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket gallformers-full-backups \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "ExpireOldBackups",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "Expiration": {"Days": 90},
      "NoncurrentVersionExpiration": {"NoncurrentDays": 30}
    }]
  }'
```

## Security Notes

- Never make this bucket public
- Never add a bucket policy allowing public access
- Audit access periodically via CloudTrail
- Consider enabling S3 Object Lock for compliance requirements
