---
status: planned
created: 2026-03-11
updated: 2026-03-15
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

- [ ] Production Postgres provisioned (repurpose gallformers-db)
- [ ] Cutover rehearsed on preview
- [ ] Cutover executed
- [ ] Post-cutover soak verified
- [ ] Cleanup completed (SQLite, Litestream secrets, IAM, S3, pg-load script)
- [ ] Preview Postgres re-provisioned (gallformers-preview-db)

## Open questions

- How long should the read-only soak period be before enabling writes? Hours? A day?
- Rollback window: how long do we keep the ability to roll back to SQLite?

