---
status: raw
created: 2026-03-11
updated: 2026-03-11
epic: postgres
blocks: [f176]
needs: [b036]
parent: 4474
---

# Phase 3a: Postgres infrastructure research + provisioning

## Goal

A running Fly Postgres instance with backups, properly sized and configured, ready for the soak period.

Note: this project will ultimately need THREE Postgres instances: local (dev/test), preview (soak), and production. This phase provisions the preview instance. Production is provisioned before cutover.

## Research Questions

### Provisioning
- `fly postgres create` (Fly's managed-ish) vs fully DIY Dockerfile — what does each give us?
- What Postgres version? (latest stable, probably 16 or 17)
- Connection string setup — private network DNS, Fly secrets

### Machine sizing
- Current app machine: shared-cpu 2 cores, 1GB RAM
- Postgres needs: shared_buffers, work_mem, maintenance_work_mem for 140MB DB
- What's the minimum viable Fly machine spec?
- How much headroom for growth?

### Data volume
- 140MB DB today. Growth rate? (check recent DB size history)
- WAL files, indexes, temp space, pg_dump staging area
- Recommended volume size with headroom
- Volume resize process if needed

### Monitoring
- Fly dashboard: machine-level metrics (CPU, RAM, disk) — sufficient?
- Postgres-internal: pg_stat_statements, connection count, slow queries
- Do we need additional tooling or is Fly + health check enough?
- Alerting — Fly auto-restarts, but how do we know it happened?

### Updates + maintenance
- Minor version patches — how does the container image get updated?
- Major version upgrades (pg_upgrade vs dump/restore)
- Security patch responsibility
- Vacuum/analyze — does autovacuum suffice at this scale?

### Connectivity + failure modes
- Ecto connection pool — sufficient or do we need PgBouncer?
- App behavior when Postgres machine restarts — does Ecto reconnect gracefully?
- Volume full — what happens? How do we prevent it?
- `release_command` for migrations — now works since DB isn't on a forked volume

### Backups
- pg_dump cron to S3 — implementation options on Fly (cron in the Postgres machine? separate machine? external? Fly machines don't have cron by default)
- Cron interval decision
- Retention policy
- Restore procedure — documented and tested
- Reuse existing S3 bucket + IAM or new?

## Steps

1. Research all questions above (Fly docs, community examples, Phoenix deployment guides)
2. Decide on machine spec, volume size, Postgres version
3. Provision Fly Postgres machine (for preview/soak)
4. Configure backups
5. Test restore procedure
6. Load data via conversion tool
7. Verify app can connect and query

## Output
- Running Fly Postgres instance with real data (preview)
- Backups running and restore-tested
- Documented answers to all research questions
- Connection config ready for preview deploy

