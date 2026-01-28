# S3 bucket for gallformers images (us-east-1)
#
# Replaces the legacy "gallformers" bucket in us-east-2.
# See runbooks/migrate-images-bucket.md for migration procedure.

resource "aws_s3_bucket" "images" {
  bucket = "gallformers-images-us-east-1"

  tags = {
    Project   = var.project
    ManagedBy = "opentofu"
  }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "images_public_read" {
  bucket = aws_s3_bucket.images.id

  # Ensure public access block is applied first so the policy isn't rejected
  depends_on = [aws_s3_bucket_public_access_block.images]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })
}
