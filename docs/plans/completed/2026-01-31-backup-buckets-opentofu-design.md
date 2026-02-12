# Design: Add Backup S3 Buckets to OpenTofu

**Date:** 2026-01-31
**Issue:** gallformers-c0ei
**Status:** Approved

## Goal

Bring the two manually-created backup S3 buckets (`gallformers-backups` and `gallformers-full-backups`) under infrastructure-as-code management using OpenTofu, while preserving their existing configuration and data.

## Current State

### Buckets (created manually per docs/backup-setup.md)

**gallformers-backups:**
- Region: us-east-1
- Versioning: Enabled
- Public access: Mixed (public read for `public/*` prefix only)
- Bucket policy: Allows public GetObject for `arn:aws:s3:::gallformers-backups/public/*`
- Contents:
  - `litestream/` - Continuous DB backups (private)
  - `public/` - Daily sanitized snapshots (public)
- No lifecycle rules configured
- No tags

**gallformers-full-backups:**
- Region: us-east-1
- Versioning: Enabled
- Fully private (no public access)
- No bucket policy
- Contents: Full unsanitized DB backups with PII
- No lifecycle rules configured
- No tags

### OpenTofu State

The buckets are NOT currently in OpenTofu state, but:
- The `litestream-gallformers` IAM user already references both buckets in `infra/iam.tf` (lines 53-56)
- The IAM policy grants access to both buckets
- Only the S3 bucket resources themselves are missing

## Design

### Resources to Add

Add to `infra/s3.tf` following the same pattern as the existing `gallformers-images-us-east-1` bucket:

#### gallformers-backups (6 resources)

```hcl
resource "aws_s3_bucket" "backups"
resource "aws_s3_bucket_versioning" "backups"
resource "aws_s3_bucket_public_access_block" "backups"
resource "aws_s3_bucket_policy" "backups_public_snapshots"
```

Configuration details:
- Versioning: Enabled
- Public access block: `block_public_policy = false` (allow the public policy)
- Bucket policy: Public read for `public/*` prefix only

#### gallformers-full-backups (3 resources)

```hcl
resource "aws_s3_bucket" "full_backups"
resource "aws_s3_bucket_versioning" "full_backups"
resource "aws_s3_bucket_public_access_block" "full_backups"
```

Configuration details:
- Versioning: Enabled
- Public access block: All settings = true (fully private)
- No bucket policy

### Implementation Process

**Step 1: Add resource definitions to infra/s3.tf**
- Define all resources matching current AWS configuration exactly
- Add comments explaining purpose and access patterns
- Follow existing code style (see images bucket for reference)

**Step 2: Import existing resources into OpenTofu state**

```bash
cd infra

# gallformers-backups
tofu import aws_s3_bucket.backups gallformers-backups
tofu import aws_s3_bucket_versioning.backups gallformers-backups
tofu import aws_s3_bucket_public_access_block.backups gallformers-backups
tofu import aws_s3_bucket_policy.backups_public_snapshots gallformers-backups

# gallformers-full-backups
tofu import aws_s3_bucket.full_backups gallformers-full-backups
tofu import aws_s3_bucket_versioning.full_backups gallformers-full-backups
tofu import aws_s3_bucket_public_access_block.full_backups gallformers-full-backups
```

**Step 3: Verify with tofu plan**
- Run `tofu plan`
- Expected output: "No changes. Your infrastructure matches the configuration."
- If changes are detected, adjust resource definitions to match AWS exactly

**Step 4: Update infra/README.md**
- Add the two new buckets to the S3 Buckets table
- Document their purpose and access patterns

## What We're NOT Adding (Yet)

These features are not currently configured on the buckets, so we won't add them:

- **Lifecycle rules** - Docs show them as "optional", not currently configured
- **Tags** - Existing buckets have no tags
- **Encryption** - Not explicitly configured
- **CORS** - Not needed for backup buckets
- **Logging** - Not currently enabled

Any of these can be added later as separate infrastructure improvements.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Import command fails | Manually verify resource exists in AWS first |
| Plan shows unexpected changes | Review AWS config vs. resource definition, adjust code to match |
| State file corruption | OpenTofu backend uses S3 with locking (configured in main.tf) |
| Breaking existing backups | Import is read-only - no changes to AWS until after verification |

## Success Criteria

- [ ] All 7 resources successfully imported into OpenTofu state
- [ ] `tofu plan` shows no changes
- [ ] Litestream backups continue working (no interruption)
- [ ] Public snapshots remain accessible at existing URLs
- [ ] infra/README.md updated with new buckets

## Future Enhancements

After this import is complete, consider:
- Add lifecycle rules to delete old non-current versions (cost savings)
- Add server-side encryption (AES-256 or KMS)
- Add tags for cost allocation (Project=gallformers, ManagedBy=opentofu)
- Add bucket logging to track access patterns
