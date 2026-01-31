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
│  │ (sanitized snapshots)│     │ (private, has PII)   │                     │
│  │ + Litestream backups │     │                      │                     │
│  └──────────┬───────────┘     └──────────┬───────────┘                     │
│             │                            │                                  │
│             └────────────┬────────────────┘                                 │
│                          │                                                  │
│                          ▼                                                  │
│          ┌──────────────────────────────┐                                   │
│          │ IAM: litestream-gallformers  │◄──── Fly.io (Litestream)         │
│          │ Policy: LitestreamGallforms  │◄──── GitHub Actions (snapshots)  │
│          │         Backup               │                                   │
│          └──────────────────────────────┘                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Region Strategy

All AWS resources are deployed to **`us-east-1`** (N. Virginia) to match Fly.io's `iad` datacenter for low latency.

**Migration note:** The legacy `gallformers` image bucket was in `us-east-2`. The new `gallformers-images-us-east-1` bucket is the authoritative location. See [migrate-images-bucket.md](../runbooks/migrate-images-bucket.md) for the migration procedure.

## Resources

### S3 Buckets

- **`gallformers-images-us-east-1`** - Production images (original, small, medium, large, xlarge)
- **`gallformers-backups`** - Litestream replication + sanitized public DB snapshots
- **`gallformers-full-backups`** - Full database backups (private, contains PII)

### CDN

- **CloudFront distribution** - Serves images via Origin Access Control (OAC), no public S3 access needed

### IAM

- **`s3-upload`** - Image uploads to S3 (credentials in Fly.io/V2 app secrets)
- **`litestream-gallformers`** - Database backups (credentials in Fly.io secrets + GitHub Actions secrets)

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

See [Beads](../.beads/) for tracked infrastructure work (issues tagged with `infra`).

Key runbooks:
- [migrate-images-bucket.md](../runbooks/migrate-images-bucket.md) - Migrate images from us-east-2 to us-east-1
- [backup-setup.md](../docs/backup-setup.md) - S3/IAM configuration details
