# Runbook: Planned Maintenance

Use this runbook when Gallformers will be intentionally unavailable and should
show the static maintenance page from CloudFront/S3 instead of the live app.

## Purpose

- Serve a maintenance page even if Fly/Phoenix is fully offline
- Make the maintenance window reversible with a single OpenTofu apply
- Keep the outage page reserved for unplanned failures

## Prerequisites

- AWS CLI configured with appropriate credentials
- OpenTofu installed (`tofu` CLI)
- Static maintenance page already uploaded to:
  - `s3://gallformers-images-us-east-1/maintenance/maintenance.html`

If you need to upload or refresh the page:

```bash
aws s3 cp priv/static/maintenance/maintenance.html \
  s3://gallformers-images-us-east-1/maintenance/maintenance.html \
  --content-type "text/html"
```

Verify the object directly:

```bash
curl -s -o /dev/null -w "%{http_code}" \
  https://gallformers-images-us-east-1.s3.us-east-1.amazonaws.com/maintenance/maintenance.html
# Should return 200
```

## Enable Maintenance Mode

Before taking Fly/Phoenix down, switch CloudFront into maintenance mode:

```bash
cd ~/dev/gallformers/infra
tofu plan -var='maintenance_mode_enabled=true'
tofu apply -var='maintenance_mode_enabled=true'
```

This updates the CloudFront distribution so normal site traffic is served from
the S3 maintenance origin instead of Fly.

## Verify Maintenance Mode

Check the page through the production domain:

```bash
curl -sI https://gallformers.org | grep -E "^(HTTP|x-cache)"
curl -s https://gallformers.org | grep "Down for Maintenance"
```

You can also check the CloudFront distribution domain directly:

```bash
curl -s -o /dev/null -w "%{http_code}" \
  https://$(cd ~/dev/gallformers/infra && tofu output -raw v2_distribution_domain)/maintenance.html
```

## Take the App Down

Once maintenance mode is verified, proceed with the planned work. Examples:

```bash
fly apps restart gallformers --skip-health-checks
```

Or for a full shutdown:

```bash
fly scale count 0 -a gallformers
```

## Restore Normal Traffic

When maintenance is complete and the app is healthy again:

```bash
cd ~/dev/gallformers/infra
tofu plan -var='maintenance_mode_enabled=false'
tofu apply -var='maintenance_mode_enabled=false'
```

Then verify the live app is back:

```bash
curl -sI https://gallformers.org | grep -E "^(HTTP|x-cache)"
curl -s https://gallformers.org/health
```

## Notes

- CloudFront maintenance mode is not instant. Expect normal distribution update
  propagation time.
- The unplanned outage page is separate and is controlled by the CloudFront
  `500/502/503/504` custom error responses.
- If maintenance mode is enabled before the static page exists in S3, users
  will get a broken maintenance flow. Verify the S3 object first.
