# Runbook: Rollback Deployment

## Purpose
Revert the application to a previous known-good release.

## When to Use
- Deployment introduced a breaking bug
- Application crashes after deployment
- Critical functionality broken after release
- Diagnosis confirmed bad code (see [Diagnose Deployment Issue](./diagnose-deployment-issue.md))

## Prerequisites
- `flyctl` CLI installed and authenticated
- Access to Fly.io app `gallformers`
- Known-good release version (or will identify in Step 1)

## Important
This runbook rolls back **code only**. Database changes persist across deployments. If the database is corrupted, see [Restore Database](./restore-database.md) first.

## Procedure

### 1. Identify Target Release

List recent releases:

```bash
fly releases -a gallformers
```

Output example:
```
VERSION STABLE  TYPE    STATUS    DESCRIPTION                  USER             DATE
v15     true    release succeeded Deploy image                 user@example.com 2024-01-08T10:00:00Z
v14     true    release succeeded Deploy image                 user@example.com 2024-01-07T15:00:00Z
v13     true    release succeeded Deploy image                 user@example.com 2024-01-05T09:00:00Z
```

Record the target version: `v____`

### 2. Get Target Image

```bash
fly releases show v<TARGET_VERSION> -a gallformers
```

Record the image reference: `registry.fly.io/gallformers:deployment-________________`

### 3. Execute Rollback

```bash
fly deploy --image registry.fly.io/gallformers:deployment-<ID> -a gallformers
```

Wait for deployment to complete.

### 4. Verify Rollback

Run health check:

```bash
curl -s -o /dev/null -w "%{http_code}" https://gallformers.fly.dev/health
```

Expected: `200`

Check logs for clean startup:

```bash
fly logs -a gallformers --no-tail | head -50
```

Verify no errors in recent log output.

### 5. Confirm Application Functionality

- [ ] Health endpoint returns 200
- [ ] Homepage loads
- [ ] Key functionality works (search, species pages)

## Verification Checklist

- [ ] `fly status -a gallformers` shows healthy machines
- [ ] Health check returns 200
- [ ] No error patterns in logs
- [ ] User-reported issue resolved

## Rollback Failed?

If rollback deployment fails:

1. Try direct machine update:
   ```bash
   fly machines list -a gallformers
   fly machines update <MACHINE_ID> --image registry.fly.io/gallformers:deployment-<ID> -a gallformers
   ```

2. If still failing, see [Incident Response](./incident-response.md)

## Post-Rollback

1. Communicate resolution to affected users if applicable
2. Create issue to investigate root cause
3. Fix forward—do not redeploy broken code
