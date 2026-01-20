# Backup Strategy for Gallformers V2

This document defines the backup and recovery strategy for the v2 SQLite database.

## Overview

The backup strategy has two components:

1. **Continuous replication** via Litestream to private S3 (disaster recovery)
2. **Daily public snapshot** via GitHub Actions (development/research)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Fly.io Machine                                              │
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │ Go API      │◄───│ Litestream   │───►│ S3 (private)  │  │
│  │ (SQLite)    │    │ (wrapper)    │    │ /backups/     │  │
│  └─────────────┘    └──────────────┘    └───────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                                                 │
                                                 ▼
                              ┌──────────────────────────────┐
                              │ GitHub Actions (daily)       │
                              │ - Restore from Litestream    │
                              │ - Upload to S3 (public)      │
                              └──────────────────────────────┘
                                                 │
                                                 ▼
                              ┌──────────────────────────────┐
                              │ S3 (public)                  │
                              │ /public/gallformers.sqlite   │
                              └──────────────────────────────┘
                                                 │
                                                 ▼
                              ┌──────────────────────────────┐
                              │ Developers                   │
                              │ make download-db             │
                              └──────────────────────────────┘
```

## Litestream Configuration

### How It Works

Litestream wraps the application process and continuously streams SQLite WAL (Write-Ahead Log) changes to S3. This provides:

- **Near-zero RPO**: Changes replicated within seconds
- **Point-in-time recovery**: Restore to any moment
- **No code changes**: Works with any SQLite application

### Dockerfile Changes

```dockerfile
# Add to runtime stage
FROM alpine:3.19
RUN apk add --no-cache ca-certificates sqlite

# Install Litestream
ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-amd64.tar.gz /tmp/litestream.tar.gz
RUN tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz && rm /tmp/litestream.tar.gz

WORKDIR /app
COPY --from=api-builder /app/gallformers-api /app/gallformers-api
COPY litestream.yml /etc/litestream.yml

EXPOSE 8080
CMD ["litestream", "replicate", "-exec", "/app/gallformers-api"]
```

### litestream.yml

```yaml
dbs:
  - path: /data/gallformers.sqlite
    replicas:
      - type: s3
        bucket: gallformers-backups
        path: litestream
        region: us-east-1
        access-key-id: ${LITESTREAM_ACCESS_KEY_ID}
        secret-access-key: ${LITESTREAM_SECRET_ACCESS_KEY}
```

### Required Secrets

```bash
fly secrets set \
  LITESTREAM_ACCESS_KEY_ID=<aws-access-key> \
  LITESTREAM_SECRET_ACCESS_KEY=<aws-secret-key> \
  -a gallformers-v2
```

## S3 Bucket Setup

### Private Backup Bucket

Create bucket `gallformers-backups` (or similar) with:

- **Region**: us-east-1 (same as Fly.io iad region for low latency)
- **Versioning**: Enabled (recommended)
- **Lifecycle**: Delete old versions after 30 days (optional, cost control)
- **Access**: Private (IAM credentials only)

### Public Snapshot Path

Within the same bucket or a separate public bucket:

- **Path**: `public/gallformers.sqlite`
- **Access**: Public read via bucket policy or pre-signed URL

Example bucket policy for public read on specific prefix:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadSnapshots",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::gallformers-backups/public/*"
    }
  ]
}
```

## Daily Public Snapshot

### GitHub Actions Workflow

```yaml
name: Database Snapshot

on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM UTC
  workflow_dispatch:      # Manual trigger

jobs:
  snapshot:
    runs-on: ubuntu-latest
    steps:
      - name: Install Litestream
        run: |
          wget https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-amd64.tar.gz
          tar -xzf litestream-v0.3.13-linux-amd64.tar.gz
          sudo mv litestream /usr/local/bin/

      - name: Restore latest backup
        env:
          LITESTREAM_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          LITESTREAM_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          litestream restore -o gallformers.sqlite \
            s3://gallformers-backups/litestream

      - name: Upload public snapshot
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: us-east-1
        run: |
          aws s3 cp gallformers.sqlite s3://gallformers-backups/public/gallformers.sqlite
```

### Public Download URL

After setup, the database will be available at:

```
https://gallformers-backups.s3.amazonaws.com/public/gallformers.sqlite
```

Or via CloudFront if CDN is configured.

## Local Development

Update `v2/Makefile` to download from public URL:

```makefile
DB_URL ?= https://gallformers-backups.s3.amazonaws.com/public/gallformers.sqlite

download-db:
	@echo "Downloading production database..."
	curl -L -o data/gallformers.sqlite $(DB_URL)
	@echo "Database downloaded to data/gallformers.sqlite"
```

## Recovery Procedures

### Restore to Latest

```bash
litestream restore -o /data/gallformers.sqlite s3://gallformers-backups/litestream
```

### Restore to Point-in-Time

```bash
litestream restore -o /data/gallformers.sqlite \
  -timestamp "2024-01-15T10:30:00Z" \
  s3://gallformers-backups/litestream
```

### Full Recovery Runbook

See [Restore Database Runbook](../runbooks/restore-database.md) for step-by-step procedures.

## Cost Estimate

- **S3 Storage**: ~$0.023/GB/month (database is small, likely <$1/month)
- **S3 Requests**: Litestream batches writes, minimal cost
- **Data Transfer**: S3 to Fly.io egress on restore only

Total estimated cost: **<$1/month**

## Implementation Checklist

- [ ] Create S3 bucket with appropriate permissions
- [ ] Create IAM user with S3 access
- [ ] Add `litestream.yml` to v2/
- [ ] Update Dockerfile to install Litestream
- [ ] Add Litestream secrets to Fly.io
- [ ] Create GitHub Actions workflow for daily snapshot
- [ ] Update Makefile with download-db target
- [ ] Test backup by checking S3 for replicated data
- [ ] Test restore procedure
- [ ] Update restore-database runbook with Litestream commands
