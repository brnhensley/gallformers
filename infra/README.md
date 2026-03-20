# Gallformers Infrastructure (OpenTofu)

Infrastructure as Code for Gallformers AWS resources using OpenTofu.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ AWS (us-east-1)                                                             │
│                                                                             │
│  ┌─────────────────────┐     ┌─────────────────────┐     ┌───────────────┐ │
│  │ S3: images          │────►│ CloudFront          │────►│ Users (CDN)   │ │
│  │ (gallformers-       │     │ Origin Access       │     │               │ │
│  │  images-us-east-1)  │     │ Control             │     │               │ │
│  │ PUBLIC READ         │     │                     │     │               │ │
│  └─────────────────────┘     └─────────────────────┘     └───────────────┘ │
│          ▲                                                                  │
│          │ (s3:Put*)                                                        │
│          │                                                                  │
│  ┌───────┴──────────────┐                                                   │
│  │ IAM: s3-upload       │                                                   │
│  │ Policy: GallformersImageUpload                                           │
│  └──────────────────────┘                                                   │
│                                                                             │
│  ┌──────────────────────┐     ┌──────────────────────┐                     │
│  │ S3: gallformers-     │     │ S3: gallformers-     │                     │
│  │     backups          │     │     full-backups     │                     │
│  │ (public pg_dump)     │     │ (private, has PII)   │                     │
│  │                      │     │                      │                     │
│  └──────────┬───────────┘     └──────────┬───────────┘                     │
│             │                            │                                  │
│             └────────────┬────────────────┘                                 │
│                          │                                                  │
│                          ▼                                                  │
│          ┌──────────────────────────────┐                                   │
│          │ IAM: litestream-gallformers  │◄──── GitHub Actions (snapshots)  │
│          │ Policy: LitestreamGallforms  │                                   │
│          │         Backup               │                                   │
│          └──────────────────────────────┘                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Region Strategy

All AWS resources are deployed to **`us-east-1`** (N. Virginia) to match Fly.io's `iad` datacenter for low latency.

## Resources

### S3 Buckets

#### gallformers-images-us-east-1
- **Purpose:** Production images (original, small, medium, large, xlarge)
- **Access:** Public read via CloudFront CDN only (Origin Access Control)
- **Versioning:** Enabled
- **Upload:** `s3-upload` IAM user (Fly.io/V2 app secrets)

#### gallformers-backups
- **Purpose:** Public database snapshots
  - `public/*` - Daily pg_dump snapshots (public read, excludes PII/analytics/internal content)
  - `litestream/*` - Legacy Litestream backups (to be removed after post-cutover soak period)
- **Access:** Public read for `public/*` prefix, private otherwise
- **Versioning:** Enabled
- **Public URL:** https://gallformers-backups.s3.amazonaws.com/public/gallformers.dump

#### gallformers-full-backups
- **Purpose:** Full daily pg_dump backups (all tables, includes PII)
- **Access:** Fully private (no public access)
- **Versioning:** Enabled
- **Used by:** GitHub Actions (daily snapshot workflow) and `make download-db`

### CDN

- **CloudFront distribution** - Serves images via Origin Access Control (OAC), no public S3 access needed

### IAM

- **`s3-upload`** - Image uploads to S3 (credentials in Fly.io/V2 app secrets)
- **`litestream-gallformers`** - Database backups (credentials in GitHub Actions secrets). Name is historical — to be renamed during post-cutover cleanup.

## Deployment

```bash
# Plan changes
tofu plan

# Apply changes
tofu apply

# Import existing resources
tofu import aws_s3_bucket.images gallformers-images-us-east-1
```

## Next Steps

See project matter tracker for tracked infrastructure work.

Key runbooks:
- [backup-setup.md](../docs/backup-setup.md) - S3/IAM configuration details
