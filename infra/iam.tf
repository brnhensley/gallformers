# IAM users and policies for gallformers infrastructure.
#
# Users:
#   - litestream-gallformers: DB backup access (Fly.io + GitHub Actions)
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

resource "aws_iam_policy" "s3_put" {
  name = "s3-put"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:Put*",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::gallformers/*",
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

resource "aws_iam_user_policy_attachment" "s3_upload_put" {
  user       = aws_iam_user.s3_upload.name
  policy_arn = aws_iam_policy.s3_put.arn
}

# -----------------------------------------------------------------------------
# Inline Policies
# -----------------------------------------------------------------------------

# Inline policy on s3-upload with a legacy typo in the name ("Gallfomers" not
# "Gallformers"). Imported as-is — consolidation and renaming tracked in
# gallformers-111t.
#
# TODO: After running `tofu import`, run `tofu state show` on this resource to
# get the actual policy document from AWS. Update the policy JSON below to match
# and eliminate plan drift.
resource "aws_iam_user_policy" "s3_upload_images" {
  name = "GallfomersImagesPolicy"
  user = aws_iam_user.s3_upload.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::gallformers/*",
        ]
      }
    ]
  })
}
