# Maintenance Page Design

**Date:** 2025-01-25
**Status:** Draft
**Related:** OpenTofu epic (`gallformers-nq4j`), V1→V2 cutover

## Problem

When Gallformers V2 is deployed or the database is replaced, users see connection refused/timeout errors. This provides a poor experience—users don't know if the site is temporarily down or gone permanently.

## Solution

Add CloudFront as a CDN layer in front of Fly.io. CloudFront will automatically serve a static maintenance page when the origin (Fly.io) returns errors or is unreachable.

## Architecture

```
Current:  Users → Fly.io → (down) → Connection refused

Proposed: Users → CloudFront → Fly.io → (down) → Maintenance page from S3
```

When Fly.io returns 502, 503, 504, or times out, CloudFront intercepts the error and serves a cached maintenance page from S3.

## CloudFront Configuration

| Setting | Value |
|---------|-------|
| Origin | `gallformers.fly.dev` |
| Origin Protocol | HTTPS only |
| Viewer Protocol | Redirect HTTP to HTTPS |
| Allowed Methods | GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE |
| Cache Policy | CachingDisabled (dynamic), CachingOptimized (`/assets/*`) |
| Alternate Domains | `gallformers.org`, `www.gallformers.org`, `gallformers.com`, `www.gallformers.com` |

### Custom Error Responses

| HTTP Code | Response Page | Cache TTL |
|-----------|---------------|-----------|
| 502 (Bad Gateway) | `/maintenance.html` from S3 | 10 seconds |
| 503 (Service Unavailable) | `/maintenance.html` from S3 | 10 seconds |
| 504 (Gateway Timeout) | `/maintenance.html` from S3 | 10 seconds |

The 10-second TTL balances quick recovery with avoiding load on a struggling server.

## Maintenance Page

**Location:** `s3://gallformers/maintenance/maintenance.html`

**Content:** Based on V1's maintenance page (`v1/maintenance.html`), updated with V2 styling:
- Gallformers logo
- "Gallformers is Down for Maintenance"
- "We will be back soon!"
- "Usually these things take less than 5 minutes."
- Maroon accent color (#661419), clean centered layout
- No external dependencies (works even if Fly.io is completely down)

## Implementation Sequence

### Prerequisites
1. OpenTofu project structure set up (`gallformers-gbcn`)
2. S3 buckets imported into OpenTofu (`gallformers-bfuu`)

### Implementation
1. **Create maintenance page assets**
   - Update V1's maintenance.html with V2 styling
   - Upload to `s3://gallformers/maintenance/`
   - Verify page loads directly from S3

2. **OpenTofu CloudFront module**
   - Define CloudFront distribution
   - Configure Fly.io as origin
   - Set up custom error responses
   - Configure ACM SSL certificate

3. **Cutover (V2 launch)**
   - Apply OpenTofu to create CloudFront distribution
   - Update DNS to point to CloudFront
   - Verify maintenance page by temporarily stopping Fly app

## Testing

**Before cutover:**
- Access maintenance page directly via S3 URL
- Test CloudFront with a test domain first

**During cutover:**
- Stop Fly.io app → confirm maintenance page appears
- Start Fly.io app → confirm normal traffic within ~10 seconds

## Additional Benefits

Beyond maintenance pages, CloudFront provides:
- Edge caching for static assets (CSS, JS, images)
- DDoS protection
- Global edge network (faster for distant users)
- Likely covered by free tier for Gallformers traffic levels

## Cost

CloudFront free tier includes 1 TB data transfer + 10M requests/month. Gallformers traffic should fall within this. Beyond free tier: ~$0.085/GB transfer, ~$0.01/10K requests.
