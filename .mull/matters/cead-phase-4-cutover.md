---
status: active
created: 2026-03-11
updated: 2026-03-16
epic: postgres
needs: [1858]
parent: 4474
---

# Phase 4: Cutover

## Goal

Production running on Postgres. Clean, rehearsed, monitored.

## Runbook

All cutover procedures, checklists, and rollback plans are in `runbooks/postgres-cutover.md`. That is the single source of truth for the cutover process.

## Status

- [x] Production Postgres provisioned (repurpose gallformers-db)
- [x] Cutover rehearsed on preview
- [x] Cutover executed (2026-03-16)
- [ ] Post-cutover soak verified (7-day window, ends ~2026-03-23)
- [ ] Cleanup completed (SQLite, Litestream secrets, IAM, S3, pg-load script)
- [ ] Preview Postgres re-provisioned (gallformers-preview-db)
