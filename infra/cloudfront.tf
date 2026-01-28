# CloudFront distribution for gallformers image delivery.
#
# Serves images from the S3 images bucket via CDN. Uses Origin Access Control
# (OAC) so the bucket doesn't need to be public — CloudFront authenticates
# directly with S3.
#
# NOTE: The current S3 bucket policy in s3.tf grants public read access.
# After importing this distribution and the OAC, update the bucket policy to
# grant CloudFront access via the OAC instead of public read. Then enable
# block_public_policy and restrict_public_buckets on the public access block.
# That work is tracked separately.

# -----------------------------------------------------------------------------
# Origin Access Control
# -----------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "images" {
  name                              = "gallformers-images"
  description                       = "OAC for gallformers images bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -----------------------------------------------------------------------------
# Distribution
# -----------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "images" {
  comment         = "gallformers image CDN"
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.images.bucket_regional_domain_name
    origin_id                = "s3-images"
    origin_access_control_id = aws_cloudfront_origin_access_control.images.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-images"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS managed CachingOptimized policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project   = var.project
    ManagedBy = "opentofu"
  }
}
