---
status: raw
created: 2026-03-11
updated: 2026-03-11
epic: postgres
blocks: [cead]
needs: [f176]
parent: 4474
---

# Phase 3c: Dev + ops workflow

## Goal

All operational workflows working against Postgres before cutover. No surprises on day one.

## Steps

### 1. Public data distribution — investigation
- As Postgres schema evolves (arrays, JSONB, enums, tsvector, PostGIS), the gap between Postgres and what SQLite can represent widens
- Investigate options for distributing data to researchers, with pros/cons
- SQLite conversion may work initially but become untenable as schema matures
- Other options: pg_dump, CSV, multiple formats, API-only, etc.
- Decision here drives the snapshot pipeline implementation AND the dev workflow
- This is an open question — not yet decided despite parent matter stating ".sqlite"

### 2. Snapshot pipeline
- Replaces current Litestream restore → sanitize → upload workflow
- Implementation depends on distribution format decision from step 1
- Architecture TBD — GitHub Actions can't access Fly private network directly. Likely approach: pg_dump runs on Fly machine, uploads to S3, then GH Actions downloads from S3 for post-processing (conversion, sanitization). Heavily related to the distribution format decision.
- Sanitization step carried over (strip auth tokens, etc.)
- Upload to S3

### 3. Dev workflow
- `make download-db` updated — depends on what artifacts the snapshot pipeline produces
- Other Makefile targets: `make check-db`, `make dump-schema`, `make test-prod-data`
- Prod data tests: need pg_dump/pg_restore instead of file copy

### 4. Fly config (production)
- App and Postgres are separate Fly apps on the same private network — no orchestration needed
- Ecto handles connection retry on startup by default
- fly.toml: remove DATABASE_PATH, add DATABASE_URL reference
- Volume mount stays — still needed for request logs + WCVP sqlite
- Provision production Postgres instance (separate from preview instance)

### 5. Conversion tool: remote support
- Phase 0 conversion tool works against local Postgres
- For cutover, it needs to work against Fly Postgres (remote)
- Options: `fly proxy` to tunnel connection locally, run the tool on a Fly machine, or pg_dump locally then pg_restore to remote
- Decide on approach and verify it works before cutover

## Output
- Public data distribution approach decided and implemented
- Snapshot pipeline working
- Dev workflow functional against Postgres
- Fly config updated
- Conversion tool verified to work against remote Postgres
- Production Postgres instance provisioned

