# CloudFront V2 Cutover

Cuts over the gallformers.org domain from pointing directly at Fly.io to pointing
at the CloudFront V2 distribution (with maintenance page failover).

**Prerequisites:**
- AWS CLI configured with appropriate credentials
- OpenTofu installed (`tofu` CLI)
- Access to Namecheap DNS management for gallformers.org and gallformers.com

## 1. Upload Maintenance Page to S3

```bash
aws s3 cp priv/static/maintenance/maintenance.html \
  s3://gallformers-images-us-east-1/maintenance/maintenance.html \
  --content-type "text/html"
```

Verify the upload:

```bash
aws s3 ls s3://gallformers-images-us-east-1/maintenance/
```

Verify the page loads directly from S3 (the bucket has public read):

```bash
curl -s -o /dev/null -w "%{http_code}" \
  https://gallformers-images-us-east-1.s3.us-east-1.amazonaws.com/maintenance/maintenance.html
# Should return 200
```

## 2. Apply OpenTofu

This creates the CloudFront distribution and ACM certificate. The certificate
starts in `PENDING_VALIDATION` status.

```bash
cd infra
tofu plan    # Review changes
tofu apply   # Create resources
```

Note the outputs:
- `v2_distribution_domain` — the CloudFront domain (e.g., `d1234abcdef.cloudfront.net`)
- `v2_acm_validation_records` — DNS records needed for certificate validation

## 3. Complete ACM Certificate DNS Validation

The `tofu apply` output shows the required DNS validation records. For each
domain, create a CNAME record in Namecheap:

| Type  | Host (Name)              | Value (Target)                          |
|-------|--------------------------|-----------------------------------------|
| CNAME | `_abc123.gallformers.org` | `_abc123.acm-validations.aws.` |
| CNAME | `_abc123.gallformers.com` | `_abc123.acm-validations.aws.` |

**Note:** The exact record names and values come from the `tofu apply` output.
There may be fewer records than domains if AWS deduplicates (e.g., `www.` and
apex may share a validation record).

In Namecheap:
1. Go to Domain List > gallformers.org > Manage > Advanced DNS
2. Add each CNAME record (strip the domain suffix from the Host field — Namecheap
   appends it automatically)
3. Repeat for gallformers.com

Wait for validation to complete (usually 5-30 minutes):

```bash
aws acm describe-certificate \
  --certificate-arn "$(cd infra && tofu output -raw v2_acm_certificate_arn)" \
  --query 'Certificate.Status'
# Should return "ISSUED"
```

Then run `tofu apply` again so the `aws_acm_certificate_validation` resource
completes:

```bash
cd infra
tofu apply
```

## 4. Test CloudFront Distribution (Pre-Cutover)

Before changing DNS, verify the distribution works using the CloudFront domain
directly:

```bash
# Should return the Fly.io app (may show host mismatch — that's expected)
curl -s -o /dev/null -w "%{http_code}" \
  https://$(cd infra && tofu output -raw v2_distribution_domain)/
```

Verify the maintenance page is accessible:

```bash
curl -s -o /dev/null -w "%{http_code}" \
  https://$(cd infra && tofu output -raw v2_distribution_domain)/maintenance.html
# Should return 200
```

## 5. Update DNS (Cutover)

In Namecheap, update DNS records for all four domains to point to CloudFront.

**For apex domains** (gallformers.org, gallformers.com), use an ALIAS/ANAME or
CNAME flattening record if supported. In Namecheap, use a URL redirect or CNAME:

| Domain             | Type  | Host | Value                               |
|--------------------|-------|------|-------------------------------------|
| gallformers.org    | ALIAS | @    | `<distribution>.cloudfront.net`     |
| gallformers.org    | CNAME | www  | `<distribution>.cloudfront.net`     |
| gallformers.com    | ALIAS | @    | `<distribution>.cloudfront.net`     |
| gallformers.com    | CNAME | www  | `<distribution>.cloudfront.net`     |

Replace `<distribution>.cloudfront.net` with the actual value from
`tofu output v2_distribution_domain`.

**Note:** Namecheap may not support ALIAS records for apex domains. If not,
options include:
- Use Namecheap's URL redirect (301) from apex to www, then CNAME www to CloudFront
- Transfer DNS to Route 53 or Cloudflare (both support ALIAS/CNAME flattening)

Allow DNS propagation time (minutes to hours depending on TTL).

## 6. Verify Cutover

Once DNS has propagated:

```bash
# Verify the site loads through CloudFront
curl -sI https://gallformers.org | grep -E "^(HTTP|server|x-cache)"

# x-cache header should show "Miss from cloudfront" or "Hit from cloudfront"
```

## 7. Test Maintenance Page Failover

Stop the Fly.io app temporarily:

```bash
fly apps restart gallformers --skip-health-checks
# Or for a full stop:
fly scale count 0 -a gallformers
```

Then verify the maintenance page appears:

```bash
curl -s https://gallformers.org | grep "Down for Maintenance"
# Should match
```

Restart the app:

```bash
fly scale count 1 -a gallformers
# Or if you used restart, it should recover automatically
```

Verify normal traffic resumes. The 10-second error cache TTL means the
maintenance page may persist for up to 10 seconds after the app recovers.

## Rollback

If something goes wrong, revert DNS to point directly at Fly.io:

| Domain             | Type  | Host | Value                    |
|--------------------|-------|------|--------------------------|
| gallformers.org    | ALIAS | @    | `gallformers.fly.dev`    |
| gallformers.org    | CNAME | www  | `gallformers.fly.dev`    |
| gallformers.com    | ALIAS | @    | `gallformers.fly.dev`    |
| gallformers.com    | CNAME | www  | `gallformers.fly.dev`    |

This bypasses CloudFront entirely and restores direct Fly.io access.

The CloudFront distribution can remain in place (it won't receive traffic
once DNS is reverted) and can be re-enabled later by pointing DNS back.
