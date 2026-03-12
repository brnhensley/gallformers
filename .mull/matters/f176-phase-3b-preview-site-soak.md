---
status: raw
created: 2026-03-11
updated: 2026-03-11
epic: postgres
blocks: [1858]
needs: [1c9b]
parent: 4474
---

# Phase 3b: Preview site soak

## Goal

Confidence that Postgres on Fly works reliably under real operational conditions before committing to cutover.

## Steps

### 1. Deploy to preview site
- Modify preview Dockerfile/entrypoint to connect to Fly Postgres instead of baked-in SQLite
- WCVP repo still uses SQLite (downloaded at build time, same as today)
- Deploy integration branch to preview app

### 2. Exercise operational scenarios
- Admin work: edit hosts, run WCVP syncs, manage range data
- Background tasks: analytics rollup, any scheduled jobs
- Search: verify FTS quality with real data
- Browse: spot-check public pages, species pages, keys
- Bulk operations: the write-heavy operations that caused SQLite incidents

### 3. Observe
- Postgres machine behavior: restarts, memory usage, disk usage
- App reconnection after Postgres restart (does it recover gracefully?)
- Query performance: any noticeable slowdowns vs SQLite?
- Background task behavior under concurrent admin writes (MVCC in action)
- Duration: days to weeks, not hours

### 4. Restore-test backups
- Delete data from soak Postgres
- Restore from pg_dump backup
- Verify data integrity
- Do this more than once

## What we're looking for
- **Operational surprises** — failure modes we didn't anticipate
- **Performance** — queries that are slower than expected at 140MB
- **Reliability** — does it just keep working, or does it need babysitting?
- **Backup confidence** — can we actually restore when needed?

## Exit criteria
- No unresolved operational issues
- Comfortable that the system is reliable
- Backup restore tested and documented
- Ready to proceed to cutover
