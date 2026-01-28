# CloudFront distribution for the Gallformers V2 app.
#
# Sits in front of Fly.io and serves a static maintenance page from S3
# when the origin returns 502, 503, or 504. This is a full app proxy —
# the default behavior passes all HTTP methods through and does NOT cache.
# Only /assets/* is cached.
#
# Separate from the images CDN in cloudfront.tf.

# -----------------------------------------------------------------------------
# ACM Certificate (must be us-east-1 for CloudFront)
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "v2" {
  domain_name = "gallformers.org"

  subject_alternative_names = [
    "www.gallformers.org",
    "gallformers.com",
    "www.gallformers.com",
  ]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project   = var.project
    ManagedBy = "opentofu"
  }
}

# DNS validation records must be created manually in Namecheap.
# See runbooks/cloudfront-v2-cutover.md for the procedure.
#
# After creating the DNS records, run `tofu apply` again and this
# resource will wait for validation to complete.
resource "aws_acm_certificate_validation" "v2" {
  certificate_arn = aws_acm_certificate.v2.arn
}

# -----------------------------------------------------------------------------
# Distribution
# -----------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "v2" {
  comment         = "Gallformers V2 CDN with maintenance failover"
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"

  aliases = [
    "gallformers.org",
    "www.gallformers.org",
    "gallformers.com",
    "www.gallformers.com",
  ]

  # --- Origins ---

  # Primary: Fly.io app
  origin {
    domain_name        = "gallformers.fly.dev"
    origin_id          = "flyio"
    connection_timeout = 10

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }
  }

  # Secondary: S3 maintenance page
  # origin_path prepends /maintenance to requests, so /maintenance.html
  # resolves to s3://gallformers-images-us-east-1/maintenance/maintenance.html
  origin {
    domain_name = aws_s3_bucket.images.bucket_regional_domain_name
    origin_id   = "s3-maintenance"
    origin_path = "/maintenance"
  }

  # --- Default behavior (dynamic app — no caching) ---

  default_cache_behavior {
    target_origin_id       = "flyio"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS managed CachingDisabled policy
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AWS managed AllViewerExceptHostHeader policy — forwards all viewer
    # headers, cookies, and query strings to the origin except Host.
    # Fly.io sees Host: gallformers.fly.dev and routes correctly.
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  # --- Static assets (cached aggressively) ---

  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    target_origin_id       = "flyio"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS managed CachingOptimized policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # --- Maintenance page (served from S3) ---
  # This behavior exists so custom error responses can resolve
  # /maintenance.html from the S3 origin instead of the Fly.io origin.

  ordered_cache_behavior {
    path_pattern           = "/maintenance.html"
    target_origin_id       = "s3-maintenance"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS managed CachingOptimized policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # --- Custom error responses (maintenance page fallback) ---
  # When Fly.io returns 502/503/504, CloudFront serves the maintenance
  # page from S3 with a 503 status. The 10-second cache TTL balances
  # quick recovery with avoiding load on a struggling origin.

  custom_error_response {
    error_code            = 502
    response_page_path    = "/maintenance.html"
    response_code         = 503
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 503
    response_page_path    = "/maintenance.html"
    response_code         = 503
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 504
    response_page_path    = "/maintenance.html"
    response_code         = 503
    error_caching_min_ttl = 10
  }

  # --- SSL ---

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.v2.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Project   = var.project
    ManagedBy = "opentofu"
  }
}
