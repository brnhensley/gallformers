#!/usr/bin/env bash
#
# Import existing IAM resources into OpenTofu state.
#
# Prerequisites:
#   - AWS credentials configured for account 885187511538
#   - tofu init already run in infra/
#
# Usage:
#   Run each command individually (or the whole script) from the infra/ directory.
#   Review `tofu plan` output after importing to check for drift.

set -euo pipefail

cd "$(dirname "$0")"

ACCOUNT_ID="885187511538"

# --- IAM Users ---

# litestream-gallformers: DB backup access used by Fly.io and GitHub Actions
tofu import aws_iam_user.litestream_gallformers litestream-gallformers

# s3-upload: Image uploads to the gallformers S3 bucket
tofu import aws_iam_user.s3_upload s3-upload

# --- Managed Policies ---

# LitestreamGallformersBackup: S3 access to backup buckets
tofu import aws_iam_policy.litestream_gallformers_backup \
  "arn:aws:iam::${ACCOUNT_ID}:policy/LitestreamGallformersBackup"

# s3-put: S3 write/delete access to the gallformers images bucket
tofu import aws_iam_policy.s3_put \
  "arn:aws:iam::${ACCOUNT_ID}:policy/s3-put"

# --- Policy Attachments ---

# litestream-gallformers <- LitestreamGallformersBackup
tofu import aws_iam_user_policy_attachment.litestream_gallformers_backup \
  "litestream-gallformers/arn:aws:iam::${ACCOUNT_ID}:policy/LitestreamGallformersBackup"

# s3-upload <- s3-put
tofu import aws_iam_user_policy_attachment.s3_upload_put \
  "s3-upload/arn:aws:iam::${ACCOUNT_ID}:policy/s3-put"

# --- Inline Policies ---

# GallfomersImagesPolicy on s3-upload (note: typo in name matches AWS)
# After import, run `tofu state show aws_iam_user_policy.s3_upload_images`
# to verify the policy document and update iam.tf to match.
tofu import aws_iam_user_policy.s3_upload_images \
  "s3-upload:GallfomersImagesPolicy"
