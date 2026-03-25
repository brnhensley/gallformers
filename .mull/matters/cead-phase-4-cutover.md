---
status: active
created: 2026-03-11
updated: 2026-03-25
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
- [x] Post-cutover soak verified (9 days stable, confirmed 2026-03-25)
- [x] Code cleanup: deleted litestream-preview.yml, scripts/pg-load.sh, V1 migration scripts, removed SQLite from Dockerfile
- [x] Doc cleanup: updated runbook, infra docs, WCVP runbook (removed stale SQLite cutover section)
- [x] Services cleanup: converted boundaries and source-ingestion Python scripts from sqlite3 to psycopg
- [ ] Delete SQLite file from production volume (/data/gallformers.sqlite)
- [ ] Delete Litestream data from S3 (gallformers-backups/litestream/)
- [ ] Provision gallformers-preview-db for preview environment

