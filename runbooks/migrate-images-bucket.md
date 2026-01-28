# Migrate Images Bucket to us-east-1

**Purpose**: Move gallformers images from the `gallformers` bucket (us-east-2) to `gallformers-images-us-east-1` (us-east-1) to match Fly.io's `iad` datacenter region.

**Tracking**: gallformers-1akk

## Prerequisites

- AWS CLI configured with credentials that have access to both buckets
- OpenTofu 1.10+ installed
- CloudFront console access (distribution `E3B3XXYW8G4SB2`)

## Pre-flight Checks

1. Verify the source bucket exists and you have access:

   ```bash
   aws s3 ls s3://gallformers/ --region us-east-2 | head -20
   ```

2. Count objects in the source bucket:

   ```bash
   aws s3 ls s3://gallformers/ --region us-east-2 --recursive --summarize | tail -2
   ```

   Record the total object count and size for later verification.

3. Verify the OpenTofu state backend is accessible:

   ```bash
   cd infra/
   tofu init
   tofu plan
   ```

   The plan should show the new bucket resources to create.

## Step 1: Create the New Bucket

```bash
cd infra/
tofu apply
```

Review the plan output carefully. It should create:
- `aws_s3_bucket.images`
- `aws_s3_bucket_versioning.images`
- `aws_s3_bucket_public_access_block.images`
- `aws_s3_bucket_policy.images_public_read`

Confirm and apply.

**Verify**: Check that the bucket exists and the policy is applied:

```bash
aws s3api get-bucket-policy --bucket gallformers-images-us-east-1 --region us-east-1
aws s3api get-bucket-versioning --bucket gallformers-images-us-east-1 --region us-east-1
```

### Rollback

If bucket creation fails, fix the OpenTofu config and re-apply. No data is at risk yet.

## Step 2: Sync Objects

Copy all objects from the old bucket to the new one:

```bash
aws s3 sync s3://gallformers s3://gallformers-images-us-east-1 \
  --source-region us-east-2 \
  --region us-east-1
```

This preserves Content-Type and other metadata. For ~6,500 images at multiple sizes, expect this to take several minutes.

**Verify**: Compare object counts:

```bash
# Source
aws s3 ls s3://gallformers/ --region us-east-2 --recursive --summarize | tail -2

# Destination
aws s3 ls s3://gallformers-images-us-east-1/ --region us-east-1 --recursive --summarize | tail -2
```

Both counts should match exactly.

**Spot-check**: Verify a few images are accessible via direct S3 URL:

```bash
curl -I "https://gallformers-images-us-east-1.s3.us-east-1.amazonaws.com/path/to/known-image.jpg"
```

Should return `200 OK`.

### Rollback

If sync fails partway through, re-run the same `aws s3 sync` command. It's idempotent and will only copy missing/changed objects.

## Step 3: Update CloudFront Origin

1. Open the CloudFront console: https://console.aws.amazon.com/cloudfront/
2. Select distribution `E3B3XXYW8G4SB2`
3. Go to **Origins** tab
4. Edit the S3 origin:
   - Change **Origin domain** from `gallformers.s3.us-east-2.amazonaws.com` to `gallformers-images-us-east-1.s3.us-east-1.amazonaws.com`
5. Save changes
6. Wait for the distribution to deploy (status changes from "Deploying" to "Deployed")

**Note**: CloudFront deployment typically takes 5-15 minutes. During deployment, existing cached content continues to serve normally.

### Rollback

Change the origin back to `gallformers.s3.us-east-2.amazonaws.com` and wait for redeployment.

## Step 4: Verify Images Through CloudFront

1. Check a few known image URLs through the CloudFront domain:

   ```bash
   # Replace with actual CloudFront domain and known image paths
   curl -I "https://d-CLOUDFRONT-DOMAIN/path/to/known-image.jpg"
   ```

   Should return `200 OK` with `X-Cache: Miss from cloudfront` (first request) or `Hit from cloudfront` (cached).

2. Open the gallformers.org site and verify images load on:
   - Species detail pages (multiple image sizes)
   - Browse/search results (thumbnails)
   - Home page

3. Check browser dev tools Network tab for any 404s or errors on image requests.

### Rollback

If images aren't loading, revert the CloudFront origin (Step 3 rollback) and investigate.

## Step 5: Decommission Old Bucket

**Wait 30 days** after successful migration before deleting the old bucket. This provides a fallback window.

After 30 days with no issues:

1. Verify the old bucket is no longer referenced anywhere:

   ```bash
   # Check no CloudFront origins point to it
   aws cloudfront get-distribution-config --id E3B3XXYW8G4SB2 | grep gallformers.s3
   ```

2. Empty and delete the old bucket:

   ```bash
   aws s3 rm s3://gallformers --region us-east-2 --recursive
   aws s3api delete-bucket --bucket gallformers --region us-east-2
   ```

### Rollback

If you need the old bucket back within the 30-day window, just revert the CloudFront origin. The old bucket still has all the data.

## Summary Checklist

```
[ ] Pre-flight: Verified source bucket and counted objects
[ ] Step 1: Created new bucket via tofu apply
[ ] Step 1: Verified bucket policy and versioning
[ ] Step 2: Synced all objects
[ ] Step 2: Verified object counts match
[ ] Step 3: Updated CloudFront origin
[ ] Step 3: Waited for CloudFront deployment
[ ] Step 4: Verified images load through CloudFront
[ ] Step 4: Verified images load on gallformers.org
[ ] Step 5: (30 days later) Deleted old bucket
```
