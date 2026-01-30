# OpenTofu & V2 Cutover Plan

**Date:** 2026-01-28
**Status:** Draft
**Epic:** `gallformers-nq4j`

## Overview

Three workstreams need to be coordinated:

1. **OpenTofu Foundation** — Get infrastructure-as-code working for all AWS resources
2. **S3 Image Migration** — Move images from us-east-2 to us-east-1
3. **V2 Cutover** — Switch gallformers.org from V1 (Digital Ocean) to V2 (Fly.io via CloudFront)

These workstreams overlap and share dependencies. This document defines the safe execution order.

## Current Production State

```
gallformers.org (DNS) → Digital Ocean → V1 (Next.js)
                                         └── images via CloudFront → S3 (us-east-2)

gallformers.fly.dev → Fly.io → V2 (Phoenix)
                                 └── images via same CloudFront → same S3
```

- **V1 is live** at gallformers.org on a Digital Ocean droplet (~$25/month)
- **V2 is staged** at gallformers.fly.dev on Fly.io
- Both use the same CloudFront distribution (`E3B3XXYW8G4SB2`) and S3 bucket for images
- V1 database: SQLite on DO mounted volume (`/mnt/gallformers_data/prisma/gallformers.sqlite`, ~50MB)
- V2 database: SQLite on Fly.io persistent volume (`/data/gallformers.sqlite`)
- DNS managed at Namecheap for gallformers.org and gallformers.com
- Auth managed via Auth0

## Target Production State

```
gallformers.org (DNS) → CloudFront (V2) → Fly.io → V2 (Phoenix)
                         └── maintenance page from S3 on 502/503/504

images served via → CloudFront (images) → S3 (us-east-1)
```

## Key Constraints

1. **Do not change two things at once.** The S3 migration and V2 cutover both affect production. If something breaks, you need to know which change caused it.
2. **Complete and verify each phase before starting the next.**
3. **Everything possible that does not risk V1 should be done before the cutover.**

## Phased Execution Plan

### Phase 1: OpenTofu Foundation

**Risk to V1: None.** This phase sets up tooling and investigates prerequisites. Nothing in production changes.

| Bead | Task | Status |
|------|------|--------|
| `gbcn` | Set up OpenTofu project structure and state backend | Done |
| `plg7` | Create OpenTofu state bucket in S3 | Open |
| `87a8` | Set up AWS credentials for OpenTofu operations | Open |
| `r1kb` | Investigate static.gallformers.org references | Done |

**Details:**

- **State bucket** (`plg7`): Create `gallformers-terraform-state` bucket manually in AWS console. This is the bootstrap step — OpenTofu can't manage the bucket it stores state in. Enable versioning and encryption.
- **Credentials** (`87a8`): Decide how operators authenticate to AWS for OpenTofu commands. Options: existing `jeff` user, dedicated `opentofu-admin` user, or IAM Identity Center (SSO).
- **static.gallformers.org** (`r1kb`): Investigation determined that it is totally unused and a dead domain.

### Phase 2: Import Existing Resources & S3 Migration

**Risk to V1: Low.** `tofu import` is read-only. The S3 migration updates the CloudFront origin, but CloudFront's cache provides a buffer and the old bucket stays as fallback.

| Bead | Task | Status | Blocked by |
|------|------|--------|------------|
| `fa91` | Import IAM users and policies | Done | — |
| `1akk` | Migrate images bucket to us-east-1 | In Progress | — |
| `bfuu` | Import S3 buckets | Open | `1akk` |
| `6vkv` | Import CloudFront distribution (images) | Open | `1akk` |

**Details:**

- **S3 migration** (`1akk`): Create new `gallformers-images-us-east-1` bucket, sync all ~6,500 images, then update the existing CloudFront distribution's origin to point to the new bucket. CloudFront's cache provides a buffer during the switch. Keep the old bucket as a fallback for 30 days.
- **Import S3** (`bfuu`): After migration, import the new bucket and the backup buckets (`gallformers-backups`, `gallformers-full-backups`) into OpenTofu state.
- **Import CloudFront** (`6vkv`): Import the existing images CloudFront distribution (`E3B3XXYW8G4SB2`) after the S3 migration so the origin is already correct.

**Verification:** After all imports, run `tofu plan` and confirm zero changes. If there's drift, resolve it before proceeding.

### Phase 3: Cleanup & Hardening

**Risk to V1: Low.** IAM policy changes could affect image uploads if done incorrectly. Verify upload functionality after applying.

| Bead | Task | Status | Blocked by |
|------|------|--------|------------|
| `111t` | Clean up legacy IAM policies (update bucket ARNs) | Open | `1akk` |
| `9l6l` | Configure S3 CORS for presigned image uploads | Open | `1akk` |
| `wy87` | Write OpenTofu operations runbook | Open | — |

**Details:**

- **IAM cleanup** (`111t`): Consolidate `s3-upload` user's overlapping policies into a single `GallformersImageUpload` policy. Remove dead SQS reference. Update bucket ARNs to reference the new us-east-1 bucket. See the bead for detailed apply ordering.
- **S3 CORS** (`9l6l`): Configure CORS on the images bucket to allow presigned URL uploads from gallformers.org, gallformers.fly.dev, and localhost:4000. Required for the admin image upload UI to work.
- **Runbook** (`wy87`): Document how to use OpenTofu in this project — init, plan, apply, import workflow, credential setup, safety procedures.

**Verification:** After IAM changes, test image upload and deletion from the V2 admin UI. After CORS, test presigned upload from localhost.

### Phase 4: V2 Pre-staging

**Risk to V1: None.** Everything in this phase creates new resources or updates external configs. The V2 CloudFront distribution will exist but receive no traffic until DNS changes. V1 continues serving gallformers.org unchanged.

| Bead | Task | Status | Blocked by |
|------|------|--------|------------|
| `xk5x` | Create and validate ACM certificate | Open | — |
| `59gg` | Update Auth0 callback URLs for V2 | Open | — |
| `9mtv` | Create V2 CloudFront distribution + maintenance page | In Progress | `bfuu`, `xk5x` |
| `pliz` | Test V2 CloudFront distribution before cutover | Open | `9mtv` |
| `okhy` | Create automated smoke test script | Open | — |
| `xj17` | Set up Fly.io monitoring and alerting | Open | — |
| `c53r` | Update gallformers-status page for V2 | Open | — |
| `mooa` | Write and test V2 cutover rollback procedure | Open | — |

**Details:**

- **ACM certificate** (`xk5x`): Request a certificate in us-east-1 covering `gallformers.org`, `www.gallformers.org`, `gallformers.com`, `www.gallformers.com`. Use DNS validation — add CNAME records at Namecheap. Validation usually completes in minutes but can take up to 72 hours. **Start this early.**
- **Auth0** (`59gg`): Add V2 callback/logout URLs to Auth0. Keep all V1 URLs — don't remove them until V1 is shut down. This is additive and safe.
- **V2 CloudFront** (`9mtv`): Create a new CloudFront distribution with Fly.io (`gallformers.fly.dev`) as origin. Configure custom error responses to serve a maintenance page from S3 on 502/503/504. Upload the maintenance page. Apply via OpenTofu. The distribution will be accessible via its CloudFront domain (e.g., `dXXXXXXX.cloudfront.net`) but will NOT serve gallformers.org traffic yet.
- **Testing** (`pliz`): Access V2 through the CloudFront domain. Verify pages load, LiveView connects, images display, search works, auth works. Test the maintenance page by stopping the Fly.io machine and confirming the page appears within 10 seconds.
- **Smoke tests** (`okhy`): Create an automated script to verify critical V2 paths — health endpoint, sample pages, search, static assets. Used before and after cutover.
- **Alerting** (`xj17`): Configure Fly.io alerts for CPU, memory, 5xx error rate, and health check failures. Set up notification channel. Replaces V1's Lambda-based downdetector.
- **Status page** (`c53r`): Update https://github.com/jeffdc/gallformers-status to monitor V2 infrastructure. Announce the scheduled maintenance window on the status page before cutover day.
- **Rollback procedure** (`mooa`): Write a detailed runbook covering: trigger criteria (when to rollback vs. fix forward), exact rollback steps, data loss implications, post-rollback state, and the 7-day rollback window. Test the Namecheap DNS revert flow before cutover day. Located at `runbooks/v2-cutover-rollback.md`.

**Verification:** All testing happens via the CloudFront-assigned domain. V1 is untouched.

### Phase 5: V2 Cutover

**Risk: High — this replaces V1.** Once DNS is switched, gallformers.org serves V2. V1 stops receiving traffic.

| Bead | Task | Status | Blocked by |
|------|------|--------|------------|
| `3kso` | User communication (maintenance banner) | Open | — |
| `8bgb` | Sync production database from DO to Fly.io | Open | — |
| `iqrd` | DNS cutover to CloudFront for V2 launch | Open | all of the above |

**Prerequisites (all must be complete before cutover day):**
- [ ] V2 CloudFront distribution created and tested (`9mtv`, `pliz`)
- [ ] ACM certificate issued and validated (`xk5x`)
- [ ] Auth0 callback URLs updated (`59gg`)
- [X] static.gallformers.org investigated and resolved (`r1kb`)
- [ ] Maintenance page verified working
- [ ] Smoke test script created and tested (`okhy`)
- [X] Fly.io monitoring/alerting active (`xj17`)
- [ ] User communication started — banner on V1 site T-7 days (`3kso`)
- [ ] Status page updated for V2 and maintenance announced (`c53r`)
- [ ] Rollback procedure written, tested, and DO Droplet IP documented (`mooa`)
- [ ] Database sync dry run completed (`8bgb`)

**Cutover day procedure (target: weekday morning, 6-8 AM Eastern):**

**T-48 hours:**
1. Lower DNS TTL to 300 seconds at Namecheap
2. Document current DNS records (screenshot)
3. Document current DO Droplet IP for rollback

**T-0: Cutover execution**

Phase A — Freeze V1 (5 min):
1. Enable maintenance mode on DO (nginx serves static page)
2. Verify maintenance page is served
3. Record cutover start timestamp

Phase B — Database sync (10-15 min):
1. Create final backup on DO
2. Download database to local machine
3. Compute SHA-256 checksum
4. Run Ecto migrations if needed
5. Upload to Fly.io volume via `fly sftp shell`
6. Verify checksum on Fly.io
7. Restart Fly.io app

Phase C — Pre-DNS verification (5-10 min):
1. Verify health endpoint on `gallformers.fly.dev`
2. Run smoke tests against Fly.io URL
3. Manual spot check: home page, gall page, host page, admin login, images

Phase D — DNS switch (5 min):
1. Update Namecheap DNS for all four domains to point to CloudFront distribution
2. Preserve any existing non-A records (TXT, etc.)
3. Wait for propagation (check with `dig gallformers.org`)

Phase E — Post-DNS verification (10 min):
1. Run smoke tests against `gallformers.org`
2. Test admin login via production URL
3. Monitor Fly.io logs: `fly logs -a gallformers`
4. Record cutover end timestamp and total downtime

**Rollback:** Follow `runbooks/v2-cutover-rollback.md` (`mooa`). Summary: revert DNS to DO Droplet IP, wait for propagation (~5 min with 300s TTL), verify V1 is serving. DO Droplet stays running for 7 days post-cutover. **Important:** any data created in V2 after cutover will be lost on rollback — export the V2 database before reverting.

**Downtime target:** <10 minutes ideal, <30 minutes acceptable.

### Phase 6: Post-Cutover Monitoring

**T+1 hour:**
- Review Fly.io metrics dashboard
- Check for error spikes in logs
- Verify search functionality
- Test admin create/edit/delete cycle

**T+24 hours:**
- Review overnight logs
- Check for external referrer 404s
- Verify all admin operations

**T+7 days:**
- Final verification — all functionality working
- Document any issues encountered

### Phase 7: Cleanup

**Risk: None.** Post-cutover cleanup. No rush on any of these.

| Bead | Task | Status | Blocked by |
|------|------|--------|------------|
| `jqac` | Shut down V1 Digital Ocean droplet | Open | `iqrd` |
| `94kv` | Delete AWS Lambda downdetector | Open | `iqrd` |
| `kfk1` | Deprecate old `gallformers` S3 bucket (us-east-2) | Open | `1akk` |
| `uo7k` | Deprecate `gallformers-dev` S3 bucket | Open | — |
| `uuou` | Remove `v1/` directory from repository | Open | `jqac` |

**Details:**

- **V1 shutdown** (`jqac`): Wait at least 7 days after cutover. Take final backup of V1 database and any data. Shut down (don't delete) the droplet. After 30 more days, delete it. Check for cron jobs or services that need migrating first. Cost savings: ~$25/month.
- **Lambda cleanup** (`94kv`): Disable the `gallformers_downdetector` Lambda. After 7-day verification, delete function, IAM role, CloudWatch log group, and EventBridge rules.
- **Old S3 bucket** (`kfk1`): Keep for 30 days after migration as fallback. Verify nothing references it. Then empty and delete. Note: the `gallformers` bucket name becomes globally available after deletion.
- **Dev bucket** (`uo7k`): Inventory contents, decide if anything is needed, delete.
- **V1 code** (`uuou`): After DO shutdown, delete `v1/` directory from repo. Update any CI workflows. Code remains in git history.

**Additional cleanup (part of existing beads):**
- Remove V1 callback URLs from Auth0 (part of `59gg` follow-up)
- Reset DNS TTL to 3600 seconds (part of `iqrd` follow-up)

## Dependency Graph

```
Phase 1              Phase 2              Phase 3         Phase 4                  Phase 5        Phase 7
───────              ───────              ───────         ───────                  ───────        ───────

gbcn ✓ ──┬──► 1akk ──┬──► bfuu ──► 9mtv ──► pliz ──┐
         │           ├──► 6vkv            ▲          │
         │           ├──► 111t            │          │
         │           ├──► 9l6l    xk5x ──►┘          │
         │           └──► kfk1                       │
         │                                           │
         ├──► plg7            wy87   59gg ──────────►├──► iqrd ──┬──► jqac ──► uuou
         ├──► 87a8                                   │           │
         │                           r1kb ──────────►│           ├──► 94kv
         │                           okhy ──────────►│           │
         └──► fa91 ✓                 xj17 ──────────►│           │
                                     c53r ──────────►│           │
                                     mooa ──────────►│           │
                                     3kso ──────────►│           │
                                     8bgb ──────────►┘           │
                                                                 │
                                     uo7k                        │
```

## All Beads Reference

| Bead | Phase | Pri | Title | Status |
|------|-------|-----|-------|--------|
| `nq4j` | — | P4 | (EPIC) Implement OpenTofu for AWS Infrastructure | Open |
| `gbcn` | 1 | P4 | Set up OpenTofu project structure and state backend | **Done** |
| `plg7` | 1 | P4 | Create OpenTofu state bucket in S3 | Open |
| `87a8` | 1 | P4 | Set up AWS credentials for OpenTofu operations | Open |
| `r1kb` | 1 | P3 | Investigate static.gallformers.org references | Open |
| `fa91` | 2 | P4 | Import IAM users and policies | **Done** |
| `1akk` | 2 | P4 | Migrate images bucket to us-east-1 | In Progress |
| `bfuu` | 2 | P4 | Import S3 buckets | Open |
| `6vkv` | 2 | P4 | Import CloudFront distribution (images) | Open |
| `111t` | 3 | P4 | Clean up legacy IAM policies | Open |
| `9l6l` | 3 | P4 | Configure S3 CORS for presigned image uploads | Open |
| `wy87` | 3 | P4 | Write OpenTofu operations runbook | Open |
| `xk5x` | 4 | P3 | Create and validate ACM certificate | Open |
| `59gg` | 4 | P3 | Update Auth0 callback URLs for V2 | Open |
| `9mtv` | 4 | P3 | Create V2 CloudFront distribution + maintenance page | In Progress |
| `pliz` | 4 | P3 | Test V2 CloudFront distribution before cutover | Open |
| `okhy` | 4 | P3 | Create automated smoke test script | Open |
| `xj17` | 4 | P3 | Set up Fly.io monitoring and alerting | Open |
| `c53r` | 4 | P3 | Update gallformers-status page for V2 | Open |
| `mooa` | 4 | P2 | Write and test V2 cutover rollback procedure | Open |
| `3kso` | 5 | P3 | Plan and execute user communication | Open |
| `8bgb` | 5 | P2 | Sync production database from DO to Fly.io | Open |
| `iqrd` | 5 | P3 | DNS cutover to CloudFront for V2 launch | Open |
| `jqac` | 7 | P4 | Shut down V1 Digital Ocean droplet | Open |
| `94kv` | 7 | P4 | Delete AWS Lambda downdetector | Open |
| `kfk1` | 7 | P4 | Deprecate old gallformers S3 bucket | Open |
| `uo7k` | 7 | P4 | Deprecate gallformers-dev S3 bucket | Open |
| `uuou` | 7 | P4 | Remove v1/ directory from repository | Open |
