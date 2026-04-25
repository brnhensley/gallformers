# IAM users and policies for gallformers infrastructure.
#
# Users:
#   - litestream-gallformers: S3 backup access for GitHub Actions (daily pg_dump snapshots).
#     Name is historical from the SQLite/Litestream era.
#   - s3-upload: Image uploads to S3
#
# The jeff IAM user is a personal admin account and is NOT managed here.
# Access keys are NOT managed by OpenTofu — they stay in secrets management.

# -----------------------------------------------------------------------------
# IAM Users
# -----------------------------------------------------------------------------

resource "aws_iam_user" "litestream_gallformers" {
  name = "litestream-gallformers"

  tags = {
    Project   = var.project
    ManagedBy = "opentofu"
  }
}

resource "aws_iam_user" "s3_upload" {
  name = "s3-upload"

  tags = {
    Project   = var.project
    ManagedBy = "opentofu"
  }
}

# -----------------------------------------------------------------------------
# Managed Policies
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "litestream_gallformers_backup" {
  name = "LitestreamGallformersBackup"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LitestreamBackups"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          "arn:aws:s3:::gallformers-backups",
          "arn:aws:s3:::gallformers-backups/*",
          "arn:aws:s3:::gallformers-full-backups",
          "arn:aws:s3:::gallformers-full-backups/*",
        ]
      }
    ]
  })

  tags = {
    Project   = var.project
    ManagedBy = "opentofu"
  }
}

resource "aws_iam_policy" "gallformers_image_upload" {
  name = "GallformersImageUpload"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ApplicationBucketObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:Put*",
          "s3:DeleteObject",
        ]
        Resource = [
          "${aws_s3_bucket.images.arn}/*",
          "${aws_s3_bucket.private.arn}/*",
        ]
      },
      {
        Sid    = "ApplicationBucketList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.images.arn,
          aws_s3_bucket.private.arn,
        ]
      }
    ]
  })

  tags = {
    Project   = var.project
    ManagedBy = "opentofu"
  }
}

# -----------------------------------------------------------------------------
# Policy Attachments
# -----------------------------------------------------------------------------

resource "aws_iam_user_policy_attachment" "litestream_gallformers_backup" {
  user       = aws_iam_user.litestream_gallformers.name
  policy_arn = aws_iam_policy.litestream_gallformers_backup.arn
}

resource "aws_iam_user_policy_attachment" "s3_upload_image_upload" {
  user       = aws_iam_user.s3_upload.name
  policy_arn = aws_iam_policy.gallformers_image_upload.arn
}
