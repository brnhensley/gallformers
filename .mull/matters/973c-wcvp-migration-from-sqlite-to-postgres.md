---
status: raw
created: 2026-03-15
updated: 2026-03-15
epic: postgres
relates: [4474]
---

# WCVP migration from SQLite to Postgres

## Context

WCVP database is ~700MB SQLite, read-only, containing global plant data. It was kept on SQLite when the main DB migration was planned because the main DB was also SQLite at the time. Now that the main DB is moving to Postgres, the rationale for keeping WCVP on SQLite no longer holds.

## Problem

- 700MB SQLite file is sluggish — single connection, slow first load after deploy
- Pre-warm helps first connection but general query performance is poor
- The data ballooned when we took on all world plant data

## Why move to Postgres

- Connection pooling and concurrent reads (SQLite is single-writer/reader)
- Better query planning and indexing for a 700MB dataset
- Consolidates infrastructure — one database engine instead of two
- Eliminates the ecto_sqlite3 dependency entirely
- No more downloading a 700MB file at build/deploy time

## Sizing concerns

Current Postgres provisioning: shared-cpu-1x, 1GB RAM, 2GB volume.
Main DB is ~140MB. WCVP is ~700MB. Combined ~840MB.

- **Volume**: 2GB should be sufficient for 840MB data + indexes + WAL, but may need to bump to 3-4GB for comfort
- **RAM**: 1GB total is tight. Postgres shared_buffers + OS page cache won't hold 700MB of WCVP data in memory. Hot working set is likely much smaller, but need to evaluate actual query patterns
- May need to bump to 2GB RAM or use a separate Postgres instance for WCVP

## Sequencing

Do this AFTER the main Postgres cutover is complete and stable. Not before.

## Open questions

- Can we trim the WCVP data back to only what's needed (relevant families/regions)?
- What are the actual slow queries — is it the data volume or missing indexes?
- Same Postgres instance (separate database) or separate instance?
- How does the WCVP build pipeline change — currently builds SQLite externally and downloads from S3
- Impact on the `services/usda_plants/` Rust tool that may interact with WCVP

