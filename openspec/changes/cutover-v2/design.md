# Design: V1 to V2 Cutover

## Status

**Repository restructure: COMPLETE** - V2 Phoenix code promoted to root, V1 archived in `v1/`.

## Context

Gallformers v1 runs on a Digital Ocean Droplet (~$25/month) with:
- Next.js application in Docker
- SQLite database on mounted volume (`/mnt/gallformers_data/prisma/gallformers.sqlite`)
- nginx reverse proxy with Let's Encrypt SSL
- Manual deployment via scp + ssh

Gallformers v2 runs on Fly.io with:
- Phoenix 1.8 application with LiveView
- SQLite database on Fly.io persistent volume (`/data/gallformers.sqlite`)
- Automatic SSL via Fly.io
- Automatic deployment via `fly deploy`

DNS is managed through Namecheap for both gallformers.org and gallformers.com.

### Stakeholders

- **Site users**: Need zero disruption, all URLs preserved
- **Admin users**: Need working login and CRUD operations
- **Owner**: Needs confidence in rollback, cost savings

---

## Goals / Non-Goals

### Goals
- Execute cutover with <10 minutes downtime (acceptable: <30 minutes)
- Zero data loss
- Preserve all public URLs
- Enable rollback within 1 hour if issues found
- Complete v1 deprecation (code removal, DO cancellation)

### Non-Goals
- Changing any user-facing functionality (pure infrastructure change)
- Database schema changes during cutover
- Image migration (handled by `add-image-processing` before cutover)
- Adding new features

---

## Decisions

### Decision 1: Cutover Window

**Choice**: Low-traffic window (weekday morning, ~6-8 AM Eastern)

**Rationale**:
- Site analytics show lowest traffic during this window
- Owner available for monitoring
- Business day allows quick response if issues arise

### Decision 2: Database Sync Strategy

**Choice**: Cold sync with maintenance mode

**Process**:
1. Put v1 in maintenance mode (nginx serves static page)
2. Final database backup from DO
3. Upload to Fly.io volume via `fly sftp shell`
4. Verify integrity with checksum comparison
5. DNS switch happens only after verification

**Rationale**:
- SQLite doesn't support live replication easily
- Maintenance mode ensures no writes during sync
- Simple, reliable approach for a database this size (~50MB)

**Alternative considered**: Hot sync with write-ahead log
- More complex, higher risk of corruption
- Not worth complexity for short downtime window

### Decision 3: DNS TTL Preparation

**Choice**: Lower TTL to 300 seconds (5 minutes) 24-48 hours before cutover

**Rationale**:
- Allows faster propagation when DNS changes
- Faster rollback if needed
- Reset to normal TTL (3600s) after successful cutover

### Decision 4: Rollback Strategy

**Choice**: Keep DO Droplet running (but not serving traffic) for 7 days post-cutover

**Process**:
1. After DNS switch, DO continues running but receives no traffic
2. If rollback needed: revert DNS, DO resumes serving
3. After 7 days with no issues: cancel DO Droplet

**Rationale**:
- Cost of 7 extra days (~$6) is cheap insurance
- Instant rollback by DNS revert
- No need to redeploy v1 if issues found

### Decision 5: Auth0 Configuration

**Choice**: Update callback URLs before cutover, keep old URLs temporarily

**Process**:
1. Add Fly.io URLs to Auth0 allowed callbacks (before cutover)
2. Keep DO URLs in allowed list (for rollback capability)
3. Remove DO URLs after 7-day verification period

### Decision 6: Verification Approach

**Choice**: Automated smoke tests + manual spot checks

**Automated**:
- Health endpoint check
- Sample public pages (gall, host, family, genus)
- Sample API endpoints
- Search functionality

**Manual**:
- Admin login flow
- Create/edit/delete operation
- Image display
- Reference article rendering

---

## Cutover Procedure

### T-48 Hours: Preparation

1. [ ] Lower DNS TTL to 300 seconds at Namecheap
2. [ ] Add Fly.io callback URLs to Auth0
3. [ ] Verify v2 staging is fully functional
4. [ ] Prepare maintenance page on DO
5. [ ] Document current DO Droplet IP for rollback reference

### T-0: Cutover Execution

**Phase 1: Freeze (5 minutes)**
1. [ ] Announce maintenance window (if applicable)
2. [ ] Enable maintenance mode on DO: `sudo cp maintenance.html /var/www/html`
3. [ ] Verify maintenance page is served
4. [ ] Note exact timestamp for data verification

**Phase 2: Database Sync (10-15 minutes)**
1. [ ] SSH to DO Droplet
2. [ ] Create final backup: `cp /mnt/gallformers_data/prisma/gallformers.sqlite /mnt/gallformers_data/prisma/gallformers-final-backup.sqlite`
3. [ ] Copy database to local: `scp user@do-ip:/mnt/gallformers_data/prisma/gallformers.sqlite ./`
4. [ ] Compute checksum: `sha256sum gallformers.sqlite`
5. [ ] Upload to Fly.io: `fly sftp shell -a gallformers` then `put gallformers.sqlite /data/gallformers.sqlite`
6. [ ] Verify checksum on Fly.io: `fly ssh console -a gallformers -C "sha256sum /data/gallformers.sqlite"`
7. [ ] Restart Fly.io app to pick up new database: `fly apps restart gallformers`

**Phase 3: Verification (5-10 minutes)**
1. [ ] Verify health endpoint: `curl https://gallformers.fly.dev/health`
2. [ ] Run automated smoke tests against Fly.io URL
3. [ ] Manual spot check: home page, gall page, host page
4. [ ] Verify admin login works
5. [ ] Verify image display (S3 integration)

**Phase 4: DNS Switch (5 minutes)**
1. [ ] Update Namecheap DNS (ALIAS records → gallformers.fly.dev):
   - gallformers.org (ALIAS)
   - gallformers.com (ALIAS)
   - www.gallformers.org (CNAME)
   - www.gallformers.com (CNAME)
   - **Note**: Preserve any existing non-A records (TXT, etc.)
2. [ ] Run `fly certs add` for all four domains
   - **Note**: Brief SSL errors possible (1-5 min) until certs provision
3. [ ] Wait for propagation (check with `dig gallformers.org`)

**Phase 5: Post-Switch Verification (10 minutes)**
1. [ ] Verify production URL works: `curl https://gallformers.org`
2. [ ] Re-run smoke tests against production URL
3. [ ] Test admin login via production URL
4. [ ] Monitor for errors in Fly.io logs: `fly logs -a gallformers`

### T+1 Hour: Initial Monitoring

1. [ ] Check Fly.io metrics for error rates
2. [ ] Review any user reports
3. [ ] Verify search functionality working
4. [ ] Spot check additional pages

### T+24 Hours: Day-After Check

1. [ ] Review overnight logs
2. [ ] Check for any broken links (external referrers)
3. [ ] Verify admin operations still working

### T+7 Days: Cleanup

1. [ ] Remove DO callback URLs from Auth0
2. [ ] Reset DNS TTL to 3600 seconds
3. [ ] Cancel DO Droplet
4. [ ] Remove v1 code from repository (see below)

---

## Rollback Procedure

**If issues discovered within 7 days:**

1. Revert DNS at Namecheap to DO Droplet IP
2. Wait for propagation (~5-15 minutes with 300s TTL)
3. Verify DO site is serving traffic
4. Disable maintenance mode on DO if still enabled
5. Document issues for investigation
6. Plan fix and re-attempt cutover

**Rollback timeline**: <15 minutes to restore service

---

## V1 Code Removal

### Current Status: RESTRUCTURE COMPLETE

The repository has already been restructured:
- ✅ V2 Phoenix code promoted from `v2/` to repository root
- ✅ V1 Next.js code archived in `v1/` subdirectory
- ✅ CI workflows renamed (CI-V1, Sec-V1)
- ✅ Auxiliary services moved to `services/` directory

### Remaining Cleanup (after 7-day verification period)

After successful cutover and 7-day verification:

```
v1/                       # DELETE - entire V1 archive
```

### Current Repository Structure

```
gallformers/
├── assets/              # V2 frontend assets
├── config/              # Phoenix configuration
├── lib/                 # V2 Elixir application code
│   ├── gallformers/     # Business logic (contexts)
│   └── gallformers_web/ # Web layer (LiveViews)
├── priv/                # Static files, database, migrations
├── test/                # V2 tests
├── services/            # Auxiliary services
├── v1/                  # ARCHIVED - V1 Next.js code (delete after cutover)
├── openspec/            # Specifications
└── .beads/              # Issue tracking
```

---

## Risks / Trade-offs

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Database corruption during sync | Low | High | Checksum verification, keep DO backup |
| DNS propagation delays | Medium | Medium | Lower TTL beforehand, 7-day rollback window |
| Auth0 callback issues | Low | Medium | Add URLs before cutover, test beforehand |
| Unknown v2 bugs discovered | Medium | Medium | 7-day parallel operation, instant rollback |
| S3 image issues | Low | Medium | Images unchanged, only serving app changes |
| Search indexing issues | Low | Low | FTS index included in SQLite file |

---

## Resolved Questions

### 1. DNS Configuration

**Decision**: ALIAS record at Namecheap pointing to `gallformers.fly.dev`

| Option | Verdict |
|--------|---------|
| A/AAAA records | Rejected - requires manual update if Fly.io IPs change |
| CNAME | Rejected - cannot use at apex domain (gallformers.org) |
| ALIAS record | **Selected** - works at apex, auto-follows IP changes, Namecheap supports it |

Configuration at Namecheap (all four domains must work, matching v1 behavior):
- **gallformers.org**: ALIAS record → `gallformers.fly.dev`
- **gallformers.com**: ALIAS record → `gallformers.fly.dev`
- **www.gallformers.org**: CNAME → `gallformers.fly.dev`
- **www.gallformers.com**: CNAME → `gallformers.fly.dev`

After DNS update, run `fly certs add` for all four domains to provision SSL certificates. Brief SSL errors (1-5 min) may occur until certs provision.

### 2. Monitoring/Alerting

**Decision**: Yes - set up Fly.io alerts before cutover

Pre-cutover alerting setup:
- CPU utilization alert (>80% sustained)
- Memory utilization alert (>80%)
- HTTP 5xx error rate alert (>1% of requests)
- Health check failure alert

Configure via Fly.io dashboard or `fly alerts` CLI. Consider integrating with Slack for notifications.

### 3. User Communication

**Decision**: Yes - notify users of maintenance window

Communication plan:
- **T-7 days**: Post notice on site (banner) announcing scheduled maintenance
- **T-1 day**: Reminder post/banner
- **During maintenance**: Static maintenance page explains "brief maintenance, back shortly"
- **After cutover**: Remove banner, optionally post "maintenance complete" update

Channels:
- Site banner (primary)
- iNaturalist gallformers project journal post (if active community there)
- No email blast needed (low-traffic site, short window)
