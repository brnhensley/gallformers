# V1→V2 Cutover Execution Plan

**Date:** Tuesday, February 4, 2026
**Start Time:** 10:00 AM Eastern
**Operator:** Jeff (solo)
**Estimated Duration:** 1-2 hours active work + 1-2 hours monitoring
**Rollback Window:** 7 days (DO droplet stays running)

## Overview

**Current State:**
- V1 (Next.js) running on DO droplet at 157.245.243.86
- V2 (Phoenix) running on Fly.io at gallformers.fly.dev
- DNS points to DO: gallformers.org → 157.245.243.86
- CloudFront V2 ready at dfd18lb16qtjl.cloudfront.net
- ACM certificate validated: arn:aws:acm:us-east-1:885187511538:certificate/b6597ed2-26c9-4134-9c72-1d7a419c939a
- Database: ~50MB SQLite with orphaned records needing cleanup

**Target State:**
- DNS points to CloudFront V2: gallformers.org → dfd18lb16qtjl.cloudfront.net
- CloudFront routes to Fly.io with maintenance page fallback
- Clean, compacted database on Fly.io
- V1 stays running as rollback option

**Critical Blockers (must be ready by 10 AM):**
- ✅ V1 edit-disable deployed (prevents data loss)
- ⏳ Database upload solution working (custom implementation)
- ⏳ Auth0 callback URLs added (pre-cutover task)

---

## Section 1: Pre-Cutover Preparation (Before 10 AM)

### T-24 hours (Today - February 3)

**1. Lower DNS TTL at DigitalOcean**
- Set TTL to 300 seconds (5 min) for all records:
  - gallformers.org A record
  - www.gallformers.org CNAME
  - gallformers.com A record
  - www.gallformers.com CNAME
- Allows fast rollback if needed
[x] DONE at 1900 ET Feb 3

**2. Document current DNS configuration**
- Screenshot all DNS records at DigitalOcean
[x] DONE at 1905PM ET Feb 3
- Record DO droplet IP: 157.245.243.86
[x] DONE at 1906PM ET Feb 3
- Save for rollback reference

**3. Update Auth0 (gallformers-59gg)**
- Log into Auth0 dashboard
- Add V2 callback URLs:
  - `https://gallformers.org/auth/callback`
  - `https://www.gallformers.org/auth/callback`
  - `https://gallformers.com/auth/callback`
  - `https://www.gallformers.com/auth/callback`
- Add V2 logout URLs (same domains, check Phoenix auth config for exact path)
- **Keep all V1 URLs** - don't remove until V1 shutdown
- Test auth on gallformers.fly.dev
[x] DONE at 1946PM ET Feb 3

**4. Finalize database upload solution**
- Custom Fly.io approach must be tested and ready
- Document the exact commands/steps for tomorrow

**5. Update gallformers-status page (gallformers-c53r)**
- Post scheduled maintenance notice
- "Scheduled maintenance February 4, 10 AM-12 PM Eastern"

### T-0 (Tomorrow morning, before 10 AM start)

**6. Deploy V1 edit-disable**
- Deploy to DO droplet
- Verify editing is blocked on live site
- This prevents data loss during cutover

---

## Section 2: Database Cleanup & Preparation (10:00-10:30 AM)

### Step 1: Create backup on DO droplet
```bash
ssh user@157.245.243.86
cd /mnt/gallformers_data/prisma/
cp gallformers.sqlite gallformers-pre-cutover-backup-2026-02-04.sqlite
ls -lh gallformers*.sqlite  # Verify backup exists
```

### Step 2: Download database to local machine
```bash
scp user@157.245.243.86:/mnt/gallformers_data/prisma/gallformers.sqlite \
  ~/cutover-working/gallformers-v1-raw.sqlite
```

### Step 3: Clean up orphaned records
```bash
cp ~/cutover-working/gallformers-v1-raw.sqlite ~/cutover-working/gallformers-v1-clean.sqlite
sqlite3 ~/cutover-working/gallformers-v1-clean.sqlite < /Users/jeff/dev/gallformers/priv/repo/cleanup_orphaned_records.sql
```

**Script location:** `priv/repo/cleanup_orphaned_records.sql`

**What it cleans up:**
- 218 orphaned gall records (5.6% of total)
- 8,820 orphaned alias records (72.1% of total)
- 1,162 orphaned filter associations (gallcolor, gallshape, galltexture, etc.)

**Verification:** The script includes verification queries that run automatically and show remaining orphan counts (all should be 0).

### Step 4: Run V1→V2 migration
```bash
cp ~/cutover-working/gallformers-v1-clean.sqlite ~/cutover-working/gallformers-v2.sqlite
sqlite3 ~/cutover-working/gallformers-v2.sqlite < /Users/jeff/dev/gallformers/priv/repo/migrate_v1_to_v2.sql
```

### Step 5: Compact and sync WAL
```bash
sqlite3 ~/cutover-working/gallformers-v2.sqlite "VACUUM;"
sqlite3 ~/cutover-working/gallformers-v2.sqlite "PRAGMA wal_checkpoint(TRUNCATE);"
```

### Step 6: Verify and checksum
```bash
# Sanity check with Phoenix
DATABASE_PATH=~/cutover-working/gallformers-v2.sqlite iex -S mix phx.server
# Spot check localhost:4000, then shut down (Ctrl+C twice)

# Check file size
ls -lh ~/cutover-working/gallformers-v2.sqlite

# Final checksum
shasum -a 256 ~/cutover-working/gallformers-v2.sqlite > ~/cutover-working/checksum.txt
cat ~/cutover-working/checksum.txt
```

---

## Section 3: Upload Database to Fly.io (10:30-10:45 AM)

**Use the automated Mix task** - it handles all the complexity safely.

### Single command upload & verification

```bash
cd ~/dev/gallformers
mix gallformers.update_prod_db ~/cutover-working/gallformers-v2.sqlite
```

**What this task does:**
1. ✓ Re-validates local database (integrity + species count ≥ 5000)
2. ✓ Creates clean single-file copy (VACUUM + WAL checkpoint)
3. ✓ Asks for confirmation (type 'REPLACE' to continue)
4. ✓ Stops production machine
5. ✓ Updates machine to sleep mode (releases DB lock)
6. ✓ Starts sleeping machine (DB file no longer in use)
7. ✓ Backs up existing database (timestamped: `/data/gallformers-YYYYMMDD-HHMMSS.sqlite.bak`)
8. ✓ Uploads new database via SFTP
9. ✓ Verifies remote database (integrity + species count match)
10. ✓ Clears Litestream backups (forces fresh generation)
11. ✓ Restarts machine normally (reverts to app command)
12. ✓ Checks health endpoint

**Prerequisites:**
- flyctl CLI (authenticated)
- aws CLI (configured)
- sqlite3
- jq

**Expected duration:** ~5-10 minutes

**On success:**
- Shows species count, file size, SHA-256 checksum
- Backup location for rollback if needed
- Health check confirmation

**On failure:**
- Task offers automatic rollback (restores backup)
- Machine left in sleep mode for investigation
- Clear error messages

**After the task completes:**

```bash
# Verify V2 via Fly.io URL
curl -i https://gallformers.fly.dev/health
# Should return 200

# Run smoke tests
mix smoke_test https://gallformers.fly.dev
```

**⚠️ If smoke tests fail, STOP - do not proceed to DNS cutover.**

**See:** `lib/mix/tasks/gallformers/update_prod_db.ex` for implementation details

---

## Section 4: DNS Cutover (10:45-11:00 AM)

### Pre-cutover final checks
```bash
# Verify V2 is healthy on Fly.io
curl -i https://gallformers.fly.dev/health

# Verify CloudFront distribution is accessible
curl -i https://dfd18lb16qtjl.cloudfront.net/health

# Both should return 200 OK
```

### Step 1: Update DNS at DigitalOcean

Log into DigitalOcean → Networking → Domains

**For gallformers.org:**
- Update A record `@` → Point to CloudFront (see note below)
- Update CNAME record `www` → `dfd18lb16qtjl.cloudfront.net`

**For gallformers.com:**
- Update A record `@` → Point to CloudFront (see note below)
- Update CNAME record `www` → `dfd18lb16qtjl.cloudfront.net`

**Note on apex domains:** DigitalOcean may not support ALIAS records. Options:
- If DO supports ALIAS: use `dfd18lb16qtjl.cloudfront.net`
- If not: redirect apex to www (301), or resolve CloudFront IPs and use A records (less ideal - IPs can change)

**Save changes. Record timestamp.**

### Step 2: Monitor DNS propagation
```bash
# Check DNS resolution (may take 1-5 minutes with 300s TTL)
dig gallformers.org +short
dig www.gallformers.org +short
dig gallformers.com +short
dig www.gallformers.com +short

# All should eventually resolve to CloudFront domain or IPs
```

### Step 3: Verify CloudFront traffic
```bash
# Check for CloudFront headers
curl -sI https://gallformers.org | grep -i "x-cache\|via"

# Should see CloudFront indicators:
# x-cache: Hit from cloudfront (or Miss from cloudfront)
# via: 1.1 xxxxx.cloudfront.net (CloudFront)
```

### Step 4: Run smoke tests against production domains
```bash
mix smoke_test https://gallformers.org
mix smoke_test https://www.gallformers.org
mix smoke_test https://gallformers.com
mix smoke_test https://www.gallformers.com

# All should pass
```

**✅ Cutover complete. Record end timestamp and downtime duration.**

---

## Section 5: Post-Cutover Monitoring & Verification (11:00 AM-1:00 PM)

### Immediate verification (first 15 minutes)

**1. Run automated smoke tests**
```bash
# Test all production domains
mix smoke_test https://gallformers.org
mix smoke_test https://www.gallformers.org
mix smoke_test https://gallformers.com
mix smoke_test https://www.gallformers.com

# All tests must pass before continuing
# If any fail, investigate immediately
```

**2. Monitor Fly.io logs**
```bash
fly logs -a gallformers

# Watch for:
# - Successful requests (200s)
# - No error spikes (500s, database errors)
# - LiveView connections working
# - Normal traffic patterns
```

**3. Check Fly.io metrics dashboard**
```bash
fly dashboard -a gallformers

# Monitor:
# - CPU usage (should be normal, <50%)
# - Memory usage (should be stable)
# - Request rate (traffic flowing)
# - Response times (should be fast)
```

**4. Manual functional testing**
- Browse to https://gallformers.org
- Verify homepage loads with LiveView connected
- Test search functionality
- Browse to a gall page, host page, species page
- Verify images load from CloudFront
- Test admin login via Auth0
- Verify admin can view (but not edit - disabled in V1 deploy)

### 30-minute checkpoint

**5. Review error rates**
```bash
# Check for any error patterns in logs
fly logs -a gallformers | grep -i error

# Acceptable: occasional 404s, old bookmarks
# Not acceptable: 500s, database errors, auth failures
```

**6. Verify CloudFront caching behavior**
```bash
# Check that static assets are cached
curl -sI https://gallformers.org/assets/app.css | grep -i "x-cache"
# Should show "Hit from cloudfront" after first request

# Check that dynamic pages are NOT cached
curl -sI https://gallformers.org/ | grep -i "x-cache"
# Should show "Miss from cloudfront" or no x-cache header
```

### 1-hour checkpoint

**7. Test full user workflows**
- Browse multiple galls, hosts, species
- Test search with various queries
- Test identification tool (if applicable)
- Verify all images display correctly
- Test external links, source citations

**8. Check for any user reports**
- Monitor Discord for issues
- Check email for error reports

### Decision point (1-2 hours)

**If all green:**
- ✅ No error spikes in logs
- ✅ Normal CPU/memory usage
- ✅ All core functionality working
- ✅ Images loading correctly
- ✅ Auth working
- ✅ No user complaints

→ **Declare cutover successful**
→ Continue passive monitoring for rest of day
→ DO droplet stays running for 7-day rollback window

**If critical issues:**
→ **Execute rollback** (Section 6)

---

## Section 6: Rollback Procedure (If Needed)

**Full details:** See `runbooks/v2-cutover-rollback.md`

### Quick rollback (if critical issues in V2)

**Step 1: Stop V2 app (optional but recommended)**
```bash
fly scale count 0 --app gallformers
# Prevents new data creation during rollback
```

**Step 2: Revert DNS at DigitalOcean**

Log into DigitalOcean → Networking → Domains

**For gallformers.org:**
- Change A record `@` → `157.245.243.86`
- Change CNAME record `www` → `157.245.243.86` (or remove CNAME, use A record)

**For gallformers.com:**
- Change A record `@` → `157.245.243.86`
- Change CNAME record `www` → `157.245.243.86`

**Save changes.**

**Step 3: Wait for DNS propagation**
```bash
# Check DNS (5-15 minutes with 300s TTL)
dig gallformers.org +short
# Should return 157.245.243.86
```

**Step 4: Verify V1 is serving traffic**
```bash
curl -i https://gallformers.org
# Should return 200 OK from V1 (DO droplet)

# Verify a few pages work
curl -i https://gallformers.org/galls/1
```

**Step 5: Re-enable editing on V1 (if needed)**
```bash
# Redeploy V1 without edit-disable
# Or manually revert the edit-disable code
```

**⚠️ Data loss warning:**
- Any data created in V2 after cutover will be lost
- Export V2 database before rollback if needed:
```bash
fly ssh console -a gallformers -C "sqlite3 /data/gallformers.sqlite .dump" > v2-post-cutover-dump.sql
```

**Rollback window: 7 days** (DO droplet stays running)

---

## Section 7: Post-Success Tasks

### After declaring cutover successful (12:00-1:00 PM)

**Immediate:**

**1. Update status page**
- Post "Maintenance complete, all systems operational"
- Update monitoring endpoints to point to V2

**2. Re-enable editing on V2**
- Revert the edit-disable change
- Deploy updated V2 code
- Verify admin can create/edit/delete records

**3. Post communication**
- Discord announcement: "V2 cutover complete, site running on new infrastructure"
- Thank users for patience

### T+24 hours (Wednesday, February 5)

**4. Review overnight logs**
```bash
fly logs -a gallformers --since=24h | grep -i error
# Check for any issues during off-hours traffic
```

**5. Verify all functionality**
- Test admin CRUD operations
- Verify search indexing working
- Check image uploads (if re-enabled)
- Verify external integrations (if any)

**6. Run data audit**
```bash
mix audit.schema_fields
# Check data completeness (gallformers-3rtg)
```

### T+7 days (Tuesday, February 11)

**7. Final verification checkpoint**
- Review week's logs for patterns
- Verify no user complaints
- Check Fly.io metrics for stability

**8. Document any issues encountered**
- Create GitHub issues for any bugs found
- Note any performance improvements needed

### Future cleanup (no rush - P4 tasks)

- **gallformers-7yep:** Remove V1 callback URLs from Auth0 (after 7+ days)
- **gallformers-jqac:** Shut down DO droplet (after 7+ days, take final backup first)
- **gallformers-94kv:** Delete AWS Lambda downdetector
- **gallformers-d18u:** Remove legacy IAM policies
- **gallformers-uuou:** Remove v1/ directory from repo (after DO shutdown)
- **gallformers-1f19:** Migrate DNS from DigitalOcean to Namecheap (optional, lower priority)

**Reset DNS TTL:**
After 7 days of stability, increase TTL back to 3600 seconds (1 hour) for better caching.

---

## Quick Reference

**Key URLs:**
- V1 (current): https://gallformers.org → 157.245.243.86
- V2 (Fly.io): https://gallformers.fly.dev
- V2 (CloudFront): https://dfd18lb16qtjl.cloudfront.net

**Key commands:**
```bash
# Smoke tests
mix smoke_test <url>

# Fly.io monitoring
fly logs -a gallformers
fly status -a gallformers
fly dashboard -a gallformers

# DNS checks
dig gallformers.org +short

# CloudFront verification
curl -sI https://gallformers.org | grep -i "x-cache"
```

**Rollback trigger:** Critical functionality broken, cannot fix forward in <1 hour

**Support contacts:** Solo operation - no external support

**Runbooks:**
- Full rollback procedure: `runbooks/v2-cutover-rollback.md`
- CloudFront operations: `runbooks/cloudfront-v2-cutover.md`

---

## Timeline Summary

| Time | Phase | Duration |
|------|-------|----------|
| T-24h | Pre-cutover prep (DNS TTL, Auth0, status page) | 30 min |
| T-0 | Deploy V1 edit-disable | 10 min |
| 10:00 AM | Database cleanup & migration | 30 min |
| 10:30 AM | Upload to Fly.io & verify | 15 min |
| 10:45 AM | DNS cutover | 15 min |
| 11:00 AM | Immediate verification | 15 min |
| 11:15 AM | 30-min checkpoint | 15 min |
| 12:00 PM | 1-hour checkpoint | 30 min |
| 12:30 PM | Decision: success or rollback | - |
| 1:00 PM | Post-success tasks (if successful) | 30 min |

**Total estimated downtime:** 15-30 minutes (during DNS propagation)

---

## Checklist

### Pre-cutover (T-24h)
- [ ] DNS TTL lowered to 300s at DigitalOcean
- [ ] DNS records documented (screenshots)
- [ ] Auth0 V2 callback URLs added
- [ ] Database upload solution tested and ready
- [ ] Status page updated with maintenance notice
- [ ] V1 edit-disable deployed and verified

### Cutover day (10:00 AM)
- [ ] Database downloaded from DO
- [ ] Orphaned records cleaned up
- [ ] V1→V2 migration applied
- [ ] Database compacted and WAL synced
- [ ] Database verified locally
- [ ] Database uploaded to Fly.io
- [ ] Upload checksum verified
- [ ] Fly.io app restarted
- [ ] Health checks passing on Fly.io
- [ ] DNS updated at DigitalOcean
- [ ] DNS propagation confirmed
- [ ] Smoke tests passing on all domains
- [ ] CloudFront headers verified

### Post-cutover monitoring
- [ ] Smoke tests passing (immediate)
- [ ] Fly.io logs clean (no errors)
- [ ] Metrics normal (CPU, memory, requests)
- [ ] Manual testing passed
- [ ] 30-min checkpoint passed
- [ ] 1-hour checkpoint passed
- [ ] Decision: success or rollback

### Post-success
- [ ] Status page updated
- [ ] Editing re-enabled on V2
- [ ] Communication posted (Discord)
- [ ] T+24h logs reviewed
- [ ] T+7d verification complete
- [ ] DNS TTL reset to 3600s
