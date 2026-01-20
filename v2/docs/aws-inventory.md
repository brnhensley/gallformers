# AWS Resource Inventory

Current state of AWS resources used by Gallformers, for potential management via OpenTofu.

**Last updated**: 2026-01-20
**AWS Account ID**: `885187511538`

## Region Strategy

**Decision**: All AWS resources use `us-east-1` (N. Virginia) to match Fly.io's `iad` datacenter for low latency.

| Resource | Current Region | Target Region | Migration Needed |
|----------|---------------|---------------|------------------|
| `gallformers` (images) | us-east-2 | us-east-1 | Yes |
| `gallformers-dev` | us-east-2 | us-east-1 | Yes (or deprecate) |
| `gallformers-backups` | us-east-1 | us-east-1 | No |
| `gallformers-full-backups` | us-east-1 | us-east-1 | No |
| CloudFront | Global | Global | Update origin after bucket migration |
| Lambda (planned) | N/A | us-east-1 | N/A |

## S3 Buckets

### `gallformers` (Images - Production)

| Property | Value |
|----------|-------|
| Region | `us-east-2` (migrating to `us-east-1`) |
| Purpose | Production image storage |
| Access | **Public read** via bucket policy |
| Versioning | **Not enabled** |
| Public Access Block | Disabled (allows public access) |

**Bucket Policy:**
```json
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowPublicRead",
      "Effect": "Allow",
      "Principal": {"AWS": "*"},
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::gallformers/*"
    }
  ]
}
```

**CORS Configuration** (for browser-based presigned URL uploads):
```json
{
  "CORSRules": [
    {
      "AllowedOrigins": [
        "https://gallformers.org",
        "https://gallformers.com",
        "https://gallformers.fly.dev",
        "http://localhost:4000"
      ],
      "AllowedMethods": ["PUT", "GET"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3600
    }
  ]
}
```

**Usage:**
- Stores all gall/species images in multiple sizes (original, small, medium, large, xlarge)
- Served via CloudFront CDN
- Writes via `s3-upload` IAM user (`S3_PUT_AWS_ACCESS_KEY_ID`)
- Reads are public (no IAM needed)

### `gallformers-dev` (Images - Development)

| Property | Value |
|----------|-------|
| Region | `us-east-2` |
| Purpose | Development image storage |
| Access | Unknown (likely private) |
| Versioning | Unknown |

**Usage:**
- Referenced in `.env.local-docker`
- For local/dev image uploads
- **Consider deprecating** - may not be actively used

### `gallformers-backups` (Database Backups - Sanitized)

| Property | Value |
|----------|-------|
| Region | `us-east-1` |
| Purpose | Litestream backups + **sanitized** public DB snapshots |
| Access | Mixed: Private (Litestream) + Public (`public/` prefix) |
| Versioning | Enabled |

**Paths:**
- `s3://gallformers-backups/litestream` - Continuous Litestream replication (private)
- `s3://gallformers-backups/public/gallformers.sqlite` - Daily sanitized snapshot (public read, PII removed)

**Public URL:** `https://gallformers-backups.s3.amazonaws.com/public/gallformers.sqlite`

**Bucket Policy:**
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

### `gallformers-full-backups` (Database Backups - Full/Private)

| Property | Value |
|----------|-------|
| Region | `us-east-1` |
| Purpose | Full unsanitized database backups (contains PII) |
| Access | Private only |
| Versioning | Enabled |

**Created:** 2026-01-18

## CloudFront Distributions

### Images CDN

| Property | Value |
|----------|-------|
| Distribution ID | `E3B3XXYW8G4SB2` |
| Domain | `dhz6u1p7t6okk.cloudfront.net` |
| Origin | `gallformers.s3.amazonaws.com` |
| Purpose | CDN for image delivery |

**Note:** Origin will need updating after image bucket migration to us-east-1.

## IAM Users

### `jeff`

| Property | Value |
|----------|-------|
| Created | 2015-07-30 |
| Purpose | Admin/billing access |
| Attached Policies | `AWSBillingReadOnlyAccess` (AWS managed) |

### `litestream-gallformers`

| Property | Value |
|----------|-------|
| Created | 2026-01-08 |
| Purpose | Database backup access (Fly.io + GitHub Actions) |
| Attached Policies | `LitestreamGallformersBackup` |

**Credentials stored in:**
- Fly.io secrets: `LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY`
- GitHub Actions secrets: `LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY`

### `s3-upload`

| Property | Value |
|----------|-------|
| Created | 2021-01-03 |
| Purpose | Image uploads to S3 |
| Attached Policies | `s3-put` |
| Inline Policies | `GallfomersImagesPolicy` (note: typo in name) |

**Credentials stored in:**
- V1 app: `S3_PUT_AWS_ACCESS_KEY_ID`, `S3_PUT_AWS_SECRET_ACCESS_KEY`
- V2 app: Same env vars

## IAM Policies

### `LitestreamGallformersBackup` (v3)

- **ARN:** `arn:aws:iam::885187511538:policy/LitestreamGallformersBackup`
- **Attached to:** `litestream-gallformers`
- **Last updated:** 2026-01-18

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LitestreamBackups",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::gallformers-backups",
        "arn:aws:s3:::gallformers-backups/*",
        "arn:aws:s3:::gallformers-full-backups",
        "arn:aws:s3:::gallformers-full-backups/*"
      ]
    }
  ]
}
```

### `s3-put`

- **ARN:** `arn:aws:iam::885187511538:policy/s3-put`
- **Attached to:** `s3-upload`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:Put*"],
      "Resource": ["arn:aws:s3:::gallformers/*"]
    }
  ]
}
```

### `GallfomersImagesPolicy` (inline on s3-upload)

**Note:** Typo in policy name ("Gallfomers" not "Gallformers")

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:Put*"],
      "Resource": ["arn:aws:s3:::gallformers/*"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::gallformers"]
    },
    {
      "Effect": "Allow",
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:*:885187511538:gallformers_create_images"
    }
  ]
}
```

**Note:** The SQS queue `gallformers_create_images` no longer exists - this is legacy. Can be removed when migrating to OpenTofu.

## Other Resources

### Lambda Functions

**None exist currently.** Planned for image processing per `openspec/changes/add-image-processing/`.

### SQS Queues

**None exist currently.** The `gallformers_create_images` queue referenced in IAM policy is legacy/deleted.

## Planned Resources (Not Yet Created)

### Lambda: Image Processing

Per `openspec/changes/add-image-processing/design.md`:

| Property | Planned Value |
|----------|---------------|
| Runtime | Node.js 20.x (ARM64) |
| Region | `us-east-1` |
| Memory | 512MB |
| Timeout | 60 seconds |
| Trigger | S3 event on `v2/originals/` prefix |

**Environment variables needed:**
- `S3_BUCKET` - Target bucket (`gallformers`)
- `S3_REGION` - `us-east-1`
- `API_BASE_URL` - Fly.io URL for callbacks
- `LAMBDA_CALLBACK_KEY` - Shared secret for API auth

**IAM role needed:**
- `s3:GetObject` on `gallformers` bucket (read originals)
- `s3:PutObject` on `gallformers` bucket (write processed images)

**S3 changes needed:**
- CORS configuration for presigned URL uploads from browser

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ AWS Account 885187511538 (us-east-1)                                        │
│                                                                             │
│  ┌─────────────────┐     ┌─────────────────────┐     ┌───────────────┐     │
│  │ S3: gallformers │────►│ CloudFront          │────►│ Users         │     │
│  │ (images)        │     │ E3B3XXYW8G4SB2      │     │               │     │
│  │ PUBLIC READ     │     │ dhz6u1p7t6okk...    │     │               │     │
│  └─────────────────┘     └─────────────────────┘     └───────────────┘     │
│          ▲                                                                  │
│          │ (s3:Put*)             ┌─────────────────┐                       │
│          │                       │ Lambda (planned)│                       │
│          │                       │ image-processor │                       │
│  ┌───────┴─────────┐             └────────┬────────┘                       │
│  │ IAM: s3-upload  │                      │ (S3 trigger)                   │
│  │ Policy: s3-put  │◄─────────────────────┘                                │
│  └─────────────────┘                                                        │
│                                                                             │
│  ┌─────────────────────┐     ┌─────────────────────┐                       │
│  │ S3: gallformers-    │     │ S3: gallformers-    │                       │
│  │     backups         │     │     full-backups    │                       │
│  │  /litestream/       │     │  (private, has PII) │                       │
│  │  /public/ (no PII)  │     │                     │                       │
│  └──────────┬──────────┘     └──────────┬──────────┘                       │
│             │                           │                                   │
│             └───────────┬───────────────┘                                   │
│                         │                                                   │
│                         ▼                                                   │
│             ┌───────────────────────────┐                                   │
│             │ IAM: litestream-          │◄──── Fly.io (Litestream)         │
│             │      gallformers          │◄──── GitHub Actions (snapshots)  │
│             │ Policy: Litestream...     │                                   │
│             └───────────────────────────┘                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Cleanup Opportunities

When implementing OpenTofu, consider:

1. **Remove legacy SQS reference** from `GallfomersImagesPolicy`
2. **Fix policy name typo** - `GallfomersImagesPolicy` → `GallformersImagesPolicy`
3. **Consolidate s3-upload policies** - merge `s3-put` and inline policy into one
4. **Enable versioning** on `gallformers` bucket for safety
5. **Deprecate `gallformers-dev`** if not actively used

## Next Steps

1. [x] Look up missing info in AWS console
2. [x] Document AWS Account ID
3. [ ] Migrate `gallformers` bucket to us-east-1 (or create new + migrate data)
4. [ ] Update CloudFront origin after bucket migration
5. [ ] Decide fate of `gallformers-dev` bucket
6. [ ] Create OpenTofu configuration to manage these resources
7. [ ] Import existing resources into OpenTofu state
