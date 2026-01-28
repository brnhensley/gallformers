# IAM Policy Cleanup — Apply Plan

Consolidates the s3-upload user's overlapping policies into a single
`GallformersImageUpload` managed policy and removes dead resources.

## What Changed (in OpenTofu definitions)

| Action  | Resource | Notes |
|---------|----------|-------|
| Remove  | `aws_iam_policy.s3_put` | Old managed policy |
| Remove  | `aws_iam_user_policy_attachment.s3_upload_put` | Attachment of old policy |
| Remove  | `aws_iam_user_policy.s3_upload_images` | Inline policy with typo name + dead SQS ref |
| Add     | `aws_iam_policy.gallformers_image_upload` | New consolidated managed policy |
| Add     | `aws_iam_user_policy_attachment.s3_upload_image_upload` | Attachment of new policy |

## New Policy Permissions

`GallformersImageUpload` grants on `gallformers-images-us-east-1`:

- `s3:Put*` and `s3:DeleteObject` on bucket objects (upload/delete images)
- `s3:ListBucket` on the bucket itself (upload UI listing)

## Apply Order

Because this creates new resources and destroys old ones, apply in two passes
to avoid a window where s3-upload has no permissions.

### Step 1 — Create new policy (add-only)

Before removing old resources from state, apply just the new policy:

```bash
tofu apply -target=aws_iam_policy.gallformers_image_upload \
           -target=aws_iam_user_policy_attachment.s3_upload_image_upload
```

Verify in the AWS console:
- `GallformersImageUpload` policy exists
- It is attached to the `s3-upload` user

### Step 2 — Remove old resources from state

The old resources still exist in AWS but are no longer in the `.tf` files.
Remove them from state so tofu doesn't try to destroy AWS resources that
may still be in use during the transition:

```bash
tofu state rm aws_iam_policy.s3_put
tofu state rm aws_iam_user_policy_attachment.s3_upload_put
tofu state rm aws_iam_user_policy.s3_upload_images
```

### Step 3 — Verify clean plan

```bash
tofu plan
```

Should show no changes (everything in state matches the `.tf` files).

### Step 4 — Delete old AWS resources manually

Once you've confirmed image upload and deletion work with the new policy:

1. Detach `s3-put` from `s3-upload` in the IAM console
2. Delete the `s3-put` managed policy
3. Delete the `GallfomersImagesPolicy` inline policy from `s3-upload`

### Step 5 — Test

- Upload an image via the admin UI
- Delete an image via the admin UI
- Verify images are publicly accessible via CloudFront / direct S3 URL

## Rollback

If image uploads break after Step 1:

1. Re-attach the old `s3-put` policy to `s3-upload` in the IAM console
   (it still exists in AWS)
2. The inline policy was never removed from AWS, so it's still active
3. Investigate what went wrong with the new policy

If you completed Step 4 (manual deletion) and need to rollback:

1. Restore the old policy definitions in `iam.tf` (revert the git commit)
2. Run the old import commands from `iam_import.sh` (check git history)
3. `tofu apply` to recreate the old resources
