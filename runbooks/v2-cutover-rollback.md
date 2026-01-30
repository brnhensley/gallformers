# V2 Cutover Rollback Procedure

**Purpose**: Revert from V2 (Fly.io + CloudFront) back to V1 (Digital Ocean Droplet) if the cutover fails or uncovers critical issues.

**When to Use**: Only when V2 exhibits critical, unfixable issues that require immediate service restoration. See [Trigger Criteria](#trigger-criteria) for decision guidance.

**Risk Level**: Low - rollback is designed for quick DNS reversion. However, any data created in V2 AFTER the cutover will be lost.

---

## Trigger Criteria: When to Rollback vs. Push Forward

Use this decision tree to determine if rollback is appropriate:

```
Issue discovered during/after V2 cutover
    │
    ├─ ALL pages broken (500 errors, timeouts, app offline)?
    │  └─ YES → ROLLBACK IMMEDIATELY
    │
    ├─ Most of the site works but one admin page broken?
    │  └─ YES → FIX FORWARD (try rolling back V2 code only first)
    │
    ├─ Images not loading (CloudFront/S3 issue)?
    │  └─ YES → FIX FORWARD (images are unchanged by rollback)
    │
    ├─ V1 site was broken BEFORE cutover?
    │  └─ YES → DO NOT ROLLBACK (would just restore the broken state)
    │
    └─ Uncertain? Ask: "Can we fix this in <1 hour by pushing code?"
       ├─ YES → FIX FORWARD
       └─ NO → ROLLBACK
```

**Decision Authority**: Senior dev or maintainer. If unsure, rollback is the safer choice—we can re-attempt cutover after fixing issues.

---

## Prerequisites

Before you execute this runbook, ensure:

- [ ] You have access to Namecheap (manage DNS for gallformers.org and gallformers.com)
- [ ] You have the DO Droplet IP saved: `157.245.243.86`
- [ ] You have access to SSH into the DO Droplet (for verification)
- [ ] You have the V1 database snapshot that was captured before cutover
- [ ] You understand that any data created in V2 AFTER cutover will be lost (see [Data Loss](#data-loss-implications))

---

## Rollback Steps

### Step 1: Stop the V2 App (Optional but Recommended)

Prevent new data writes to V2 while we're rolling back DNS:

```bash
fly scale count 0 --app gallformers
```

This ensures no one accidentally creates data in V2 after we've decided to rollback. (The app won't receive traffic anyway once DNS is reverted, but this is defensive.)

**Time**: ~30 seconds

---

### Step 2: Revert DNS at Namecheap

This is the critical step. You're changing DNS to point back to the V1 droplet.

#### For `gallformers.org`:

1. Log into [Namecheap](https://www.namecheap.com)
2. Go to **Domains → My Domains**
3. Click **Manage** on `gallformers.org`
4. Click **Advanced DNS** tab
5. Find the DNS record pointing to CloudFront (usually an ALIAS or CNAME record like `d3b.cloudfront.net` or similar)

   **For the apex `@` record (bare domain):**
   - Change from: CloudFront ALIAS → `157.245.243.86`
   - Record type: ALIAS (Namecheap will auto-convert to ANAME if needed)

   **For the `www` record:**
   - Change from: CloudFront CNAME → `157.245.243.86`
   - Record type: CNAME

6. Save changes

#### For `gallformers.com`:

7. Repeat steps 2-6 for `gallformers.com`

**⚠️ Important**: Verify you're editing the correct records. If you update the WRONG records (e.g., image CDN records), traffic might not reach the site.

**Time**: ~2-3 minutes (actual DNS change is instant, but allow time for careful UI navigation)

---

### Step 3: Wait for DNS Propagation

DNS changes propagate globally. Since we set TTL to 300 seconds before cutover, propagation should be fast:

- **Best case**: 30 seconds
- **Normal case**: 2-5 minutes
- **Worst case**: 15 minutes (some resolvers are slow)

During this time, some users may still hit V2 (CloudFront). This is okay—they'll gradually shift to V1.

**Time**: 5-15 minutes (use this time to prepare verification steps)

---

### Step 4: Verify DNS Reversion

Check that DNS is now pointing to the DO Droplet (not CloudFront):

```bash
# Should resolve to the DO Droplet IP
dig gallformers.org +short

# Expected output:
# 157.245.243.86
```

Repeat for other domains:
```bash
dig www.gallformers.org +short
dig gallformers.com +short
dig www.gallformers.com +short
```

**All four should return `157.245.243.86`.**

If you still see CloudFront DNS (like `d3b.cloudfront.net`), wait another minute and retry. Your local DNS cache might be stale.

---

### Step 5: Verify V1 Site is Serving Traffic

Test that the V1 site is actually receiving and responding to requests:

```bash
curl -i https://gallformers.org

# Expected:
# HTTP/1.1 200 OK
# (HTML content follows)
```

This confirms:
- DNS has propagated
- The DO Droplet is online
- The web server (nginx + Docker container) is running
- Certificates are valid

**If you get a 502 or 503**: The V1 site may have crashed. See [Troubleshooting](#troubleshooting).

---

### Step 6: Verify Images Are Still Loading

Images are served by a separate CloudFront distribution (unaffected by rollback). Test that they load:

```bash
# Visit a page that displays galls or species with images
curl -i https://gallformers.org/galls/1 -L | grep "<img"

# Or manually visit a page and check the browser console for image errors
```

Images should load without CloudFront errors. (They're still on the existing images CDN, unchanged by this rollback.)

---

### Step 7: Verify Admin Login Works on V1

The V1 site shares Auth0 credentials with V2. Verify that admin login still works:

1. Visit `https://gallformers.org` (the V1 site)
2. Click **Login**
3. Enter your Auth0 credentials
4. Confirm you're logged in and can access the admin dashboard

**If login fails**: Auth0 may have cached the V2 URL. Clear Auth0 login sessions and retry. This is rare.

---

### Step 8: Disable V2 CloudFront Distribution (Optional)

Once DNS is successfully reverted, no traffic is going to V2 CloudFront. You can disable the distribution to save costs:

```bash
# List distributions to find the V2 app distribution
aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Status]' --output table

# Disable the V2 distribution (replace with actual ID):
aws cloudfront delete-distribution --id E3XXXXX --etag "<etag>"
```

Alternatively, leave it running for 7 days (cheap insurance if we need to re-enable it quickly).

**Cost impact**: ~$0.50/day to keep it running. 7 days = ~$3.50.

**Decision**: Keep it running unless asked to delete.

---

## Data Loss Implications

**Critical**: Any data created in V2 AFTER the cutover will be lost when you rollback.

### What Gets Lost

- New gall entries created in V2
- Edits to existing entries made in V2
- New user accounts created in V2
- Images uploaded to V2
- Admin actions (glossary edits, etc.) in V2

### What Gets Preserved

- All data from V1 (pre-cutover snapshot)
- Images from the shared S3 bucket (unchanged)
- Auth0 user accounts (unchanged)

### Recovery Options

1. **If little data was created**: Accept the loss (data was created during a failed cutover attempt anyway)

2. **If significant data was created**: Export V2 database before deleting:
   ```bash
   # SSH into Fly.io and export the V2 database
   fly ssh console -a gallformers
   # Inside the machine:
   sqlite3 /data/gallformers.sqlite ".dump" > /tmp/gallformers_v2_post_cutover.sql
   # Download it
   ```
   Then manually re-enter critical data into V1, or use this backup for forensic analysis post-incident.

3. **Litestream backups**: Litestream may have captured snapshots of the V2 database. If so, the V2 data can be recovered later for forensics, but we won't restore it as the production database.

---

## Post-Rollback Tasks

### Immediately After Rollback (while system is still in incident mode)

- [ ] **Create incident report** as a GitHub issue in the gallformers repo with tags `incident` and `v2-cutover`:
  ```
  Title: V2 Cutover Rollback - [Brief description of what went wrong]

  Content:
  - When cutover was initiated
  - When rollback was triggered
  - What symptoms caused the rollback decision
  - Which users were affected (all? partial?)
  - Data loss assessment
  - Immediate vs. future remediation
  ```

- [ ] **Notify users** via GitHub Discussions or Mastodon (if outage was visible):
  ```
  "We experienced an issue during maintenance and have reverted to the previous site. The site is now fully operational. We'll investigate and try again soon."
  ```

- [ ] **Document what went wrong** - capture:
  - V2 app logs (to diagnose the failure)
  - Fly.io metrics (CPU, memory, request rate at time of failure)
  - Any error messages or stack traces

### Within 24 Hours

- [ ] **Post-incident review**:
  - Why did V2 fail?
  - Was it a code issue? Infrastructure issue? Database issue?
  - Could we have caught it in staging/E2E tests?

- [ ] **Plan remediation**:
  - Fix the issue in code or infrastructure
  - Add tests to catch similar issues
  - Schedule a re-attempt

### Within 7 Days (before DO Droplet is deprovisioned)

- [ ] **Attempt cutover again** (after fixes are in place) OR
- [ ] **Decide not to cutover** (if V1 is stable and V2 isn't ready)

If you don't re-attempt within 7 days, the DO Droplet will be shut down and rollback will no longer be instant (would require re-deploying V1).

---

## Infrastructure State After Rollback

After a successful rollback, here's what's running:

| Component | State | Notes |
|-----------|-------|-------|
| **V1 (DO Droplet)** | Running, serving traffic | gallformers.org, gallformers.com point here |
| **V2 (Fly.io)** | Stopped or idle (scale: 0) | No traffic. Can be restarted later. |
| **V2 CloudFront** | Running (disabled if step 8 completed) | No traffic, no cost (or ~$0.50/day if enabled) |
| **Images CloudFront** | Running | Serving images as normal (unchanged) |
| **Auth0** | Active | Both V1 and V2 URLs registered (fine, only V1 is active) |
| **DNS (Namecheap)** | Pointing to 157.245.243.86 (V1) | gallformers.org/com pointing to DO Droplet |

---

## Testing the Rollback (Before Cutover Day)

Do this 1-2 days before the planned cutover to verify the rollback process works:

### Test 1: Verify DO Droplet IP

```bash
# Make sure this IP is correct
dig gallformers.org +short
# Should NOT resolve to this yet (cutover hasn't happened)

# But verify you can SSH to it
ssh <user>@157.245.243.86
# Should connect successfully
```

### Test 2: Verify Namecheap UI Navigation

You'll be in a panic during actual rollback, so practice the UI path:

1. Log into Namecheap
2. Go to Domains → My Domains
3. Find and click gallformers.org
4. Click "Advanced DNS"
5. Locate the ALIAS/CNAME records that will change during cutover
6. **Write down the field names and current values** so you know exactly what to change

### Test 3: Run a Dry-Run DNS Check

Before cutover, verify your local DNS tools work:

```bash
# Install dig if needed (on macOS: already installed)
dig gallformers.org +short

# Try different resolvers
dig @8.8.8.8 gallformers.org +short
dig @1.1.1.1 gallformers.org +short

# All should return the current IP at cutover time
```

### Test 4: Verify V1 Site is Still Healthy

```bash
# These should all work on V1
curl -i https://gallformers.org
curl -i https://gallformers.org/galls/1
curl -i https://gallformers.org/species

# Admin should still work
# (can't test login without an account, but check the page loads)
```

---

## Troubleshooting

### DNS Still Points to CloudFront After 15 Minutes

**Symptom**: `dig gallformers.org` still shows CloudFront domain, not 157.245.243.86

**Causes**:
- You edited the wrong DNS records (e.g., edited image CDN instead of site DNS)
- Namecheap didn't save your changes (check for error messages)
- Your local DNS cache is stale

**Solutions**:
1. Verify you edited the correct records at Namecheap (see Step 2)
2. Clear your local DNS cache:
   ```bash
   # macOS
   sudo dscacheutil -flushcache
   sudo killall -HUP mDNSResponder
   ```
3. Try a different DNS resolver:
   ```bash
   dig @8.8.8.8 gallformers.org +short
   ```

### V1 Site Returns 502 or 503

**Symptom**: `curl https://gallformers.org` returns HTTP 502 or 503

**Cause**: The DO Droplet or Docker container isn't running

**Solutions**:
1. SSH into the DO Droplet:
   ```bash
   ssh <user>@157.245.243.86
   ```
2. Check if Docker container is running:
   ```bash
   sudo docker ps
   ```
3. If not running, restart it:
   ```bash
   sudo docker-compose up -d
   ```
4. Check logs:
   ```bash
   sudo docker logs <container_id>
   ```

If the droplet itself is offline, you'll need to restore it from a backup (separate runbook: [Restore V1 from Backup](https://github.com/gallformers/gallformers/docs/v1-restore-procedure.md)).

### Images Still Don't Load After Rollback

**Symptom**: Images show broken image icons or fail to load

**Cause**: Images CDN is separate from the rollback. This is a different issue.

**Solutions**:
1. This is NOT caused by the rollback (images CDN is unchanged)
2. Check if images S3 bucket is accessible:
   ```bash
   aws s3 ls s3://gallformers/
   ```
3. Check CloudFront (images) distribution is active:
   ```bash
   aws cloudfront list-distributions --query 'DistributionList.Items[?Id==`E3B3XXYW8G4SB2`].[Status]'
   # Should return "Deployed" or "InProgress"
   ```

### Auth0 Login Fails

**Symptom**: Login page appears but Auth0 redirect fails or shows "Invalid redirect URI"

**Cause**: Auth0 may have cached the V2 URL in session cookies

**Solutions**:
1. Clear browser cookies and cache
2. Try a private/incognito window
3. Verify Auth0 console still has V1 URL registered (should, this was set up before cutover)

---

## Related Runbooks

- [Rollback Deployment](./rollback-deployment.md) - Rollback V2 code only (not DNS)
- [CloudFront V2 Cutover](./cloudfront-v2-cutover.md) - The original cutover procedure (contains rollback section you're executing)
- [Incident Response](./incident-response.md) - Post-rollback incident documentation

---

## Quick Reference

**DO Droplet IP**: `157.245.243.86`

**Rollback in 60 seconds** (if DNS already propagated):
1. Log into Namecheap
2. Change gallformers.org ALIAS from CloudFront → 157.245.243.86
3. Change gallformers.com ALIAS from CloudFront → 157.245.243.86
4. Wait 30 seconds
5. Test: `curl https://gallformers.org`

**Rollback window**: 7 days from cutover (after that, DO Droplet is gone)
