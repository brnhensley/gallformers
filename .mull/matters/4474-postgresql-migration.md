---
status: refined
created: 2026-02-13
updated: 2026-02-18
epic: platform
relates: [1501, 9ca2, cd9d]
---

# PostgreSQL migration

Feasibility research complete (docs/plans/2026-02-12-sqlite-to-postgres-research.md). ~10-14 day effort. Enables parallel tests, MVCC for concurrent admin access, richer data types for geographic expansion. Decision pending — if yes, should happen early in Phase 1 to unblock everything after.

Hosting analysis (2026-02-14): Compared Neon Free, Fly self-managed, and Fly Managed Postgres (MPG) for our scale (~20MB DB, 20k daily page views, ceiling ~100MB/100k views). Fly self-managed (~$2/mo) is the clear winner — MPG ($38/mo min) is massive overkill, Neon Free has cold start risk after 5min idle. Self-managed gives same-datacenter latency, no cold starts, simple pg_dump-to-S3 backups reusing existing infra. Neon Free still useful for zero-cost dev/staging validation during migration.

Monitoring assessment (2026-02-14): Operational overhead of adding a Postgres machine is low. Fly's built-in Grafana dashboards cover the PG machine automatically (CPU, memory, disk, network) — no setup needed. Existing /health endpoint already tests DB connectivity via SELECT 1. Fly auto-restarts crashed machines. New failure mode (app up, DB down) exists but is covered by health check + auto-restart. No alerting today for the app either — that's a separate concern independent of this migration. Minimal additions needed: pg_dump cron to S3 for backups, optionally an external uptime ping on /health.

Portable data distribution (2026-02-14): SQLite's single-file portability is a real loss. Options for public data snapshots: (1) SQL dump (pg_dump --inserts) — works with any Postgres, larger files, requires psql. (2) CSV export — universal, compact, works with Excel/Python/R/anything. (3) SQLite conversion — snapshot workflow does pg_dump → load into throwaway SQLite → upload. Consumers get same .sqlite artifact as today, never know backend changed. Low maintenance for a stable schema, conversion takes seconds at 20MB. (4) Parquet/JSON — data science friendly, language-specific tooling. Could publish multiple formats from the same workflow. SQLite conversion is the most seamless for existing consumers; CSV adds the widest reach.

Performance assessment (2026-02-14): Fly volumes are local NVMe, not network-attached — so SQLite today is app process → local NVMe with zero network hop. Postgres adds: Fly private network round-trip (~0.1-0.5ms same iad region) + PG protocol overhead per query. However, entire 20MB DB fits in Postgres shared_buffers (RAM), so after warmup neither side hits disk. Estimated ~0.5-2ms total added latency for a typical 3-5 query page load — invisible against ~50-200ms total page render. Postgres may actually gain time on complex joins due to better query planner. Bulk operations (imports) would compound per-query overhead but still milliseconds not seconds. MVCC also eliminates read-blocking during writes, which is a concurrent access win. Net: negligible performance impact at this scale.

Revised hosting analysis with durability (2026-02-14): Durability changes the calculus significantly. Fly self-managed ($2/mo) only offers daily volume snapshots (24h RPO) unless you DIY WAL-G, which is fiddly and unsupported. Neon's architecture replicates WAL across AZs + S3 (11 nines durability) built into the platform, even on free tier. Neon Free: $0, 6h PITR, cold starts after 5min idle (rarely hit at 20k daily views during active hours). Neon Launch: ~$1-5/mo, 7-30d PITR, can disable auto-suspend to eliminate cold starts. Both give Litestream-equivalent or better durability with zero ops. Remaining concern: network latency if Neon's nearest region isn't co-located with Fly iad. Need to verify Neon regions and test latency.

Neon region check (2026-02-14): Neon offers aws-us-east-1 (N. Virginia) — same region as Fly's iad datacenter. Not same-infrastructure like Fly private network, but same geographic region. Expected latency ~1-3ms per query (cross-provider within same AZ area) vs sub-ms within Fly. For 3-5 queries per page load, adds ~5-15ms total — still invisible to users against overall page render time.

Cold start analysis (2026-02-14): Cold starts are likely a non-issue in practice. Ecto maintains a persistent connection pool (10 connections in production). As long as the app holds any connection open to Neon, the DB won't suspend. Fly health check runs every 30s doing SELECT 1 through that pool — so Neon would effectively never auto-suspend while the app is running. The only cold start scenario is if the app itself goes down and restarts, at which point the ~500ms DB wake-up is invisible next to the app's own boot time. This means even Neon Free tier may work without cold start issues, eliminating the main argument for paying for Launch tier's disable-auto-suspend feature.

Why Postgres — grounded analysis (2026-02-14):

(1) PostGIS — the biggest win. Current geo model is place names in a table with no coordinates or spatial queries. Range = union of host place codes minus exclusions. Works for US/Canada (~50 places) but Western Hemisphere expansion (matter 1db6, blocked on 4143) needs hundreds of subdivisions across 46 countries, distance queries, spatial containment, potentially reverse geocoding from iNat coordinates. PostGIS gives ST_Contains, ST_Distance, spatial GIN indexes. Difference between building spatial logic in app code vs using the right tool.

(2) FTS — more capable, less ops burden. Current: 13 manual sync call sites, FTS5 virtual table, raw SQL, two-tier fallback (FTS5→LIKE), bm25 ranking. Every species create/rename/alias needs explicit update_species_fts call. Postgres: triggers auto-sync tsvector (eliminates all 13 sync calls), setweight for ranked fields, phrase search, configurable stemming for Latin names, pg_trgm for fuzzy/typo-tolerant search replacing LIKE fallback entirely.

(3) JSONB — audit trail. Matter ede2 (Audit trail) is on docket. SQLite would store JSON as unqueryable text. JSONB: store before/after snapshots, query with jsonb_path_query, index specific keys, build undo/rollback from stored snapshots.

(4) Ecto friction deleted — 43 fragment lower/LIKE → ilike. GROUP_CONCAT → string_agg. Gallformers.Migration module (148 lines) deleted entirely. Migration linter deleted. safe_recreate_table macro deleted. group_by workarounds → DISTINCT ON. FTS manual sync (13 call sites) → triggers.

(5) Parallel tests — 58 test files forced async:false, ~1000 tests serial. DataCase/ConnCase raise on async:true. Postgres enables concurrent tests, estimated 4-8x speedup.

(6) MVCC — concurrent admin writes without Database busy errors. iNat bulk imports no longer block other writes.

(7) Richer types — arrays, enums (DB-enforced taxoncode/place type/abundance), date ranges for seasonality, pgvector for future embedding search.

NOT strong reasons: query planner (queries too simple to matter), connection pooling (not needed at this concurrency), raw performance (SQLite actually faster for read-heavy single-node).

Decision recommendation (2026-02-14): Defer production migration. Do Phase 1 validation now. Set trigger for full migration.

Rationale: 10-14 days is significant and the forcing function hasn't arrived. SQLite + Litestream works (/bin/zsh.15/mo, 5s RPO, zero ops). Hemisphere expansion (the main PostGIS driver) is Phase 2, blocked on 4143 and 5b3d, both raw. Keys (85c0) is active work. Hosting decision isn't clean — Neon always-on is ~$19/mo not $5, Fly self-managed has durability gap requiring unsupported WAL-G, Fly MPG is $38/mo overkill.

Phase 1 now (1-2 days, zero risk, zero cost): Spin up Neon free tier, dev branch, swap adapter, run test suite against Postgres. Answers: how much breaks, FTS quality side-by-side, real Fly→Neon latency, actual CU-hour burn rate. De-risks eventual migration.

Trigger for full migration: When maps rework (4143) moves from raw to active. PostGIS becomes real need at that point. Migration should be validated and ready to execute before hemisphere expansion begins.

Hosting lean: Neon Launch over Fly self-managed (durability story too good vs DIY WAL-G), but don't commit until Phase 1 reveals actual CU-hour consumption. If always-on Neon is truly $19/mo, reconsider Fly self-managed + WAL-G or even Fly MPG at $38/mo (only 2x more, zero ops).

Accelerators that would move timeline up: 4143 going active, second contributor joining (parallel tests), data loss scare, hitting a feature where JSONB/PostGIS saves a week of workarounds.

Revised timeline and approach (2026-02-14): User estimates 5-7 days, not 10-14. Maps/range expansion work expected within a month. This collapses the defer-until-trigger recommendation — the trigger is essentially here. Revised plan: finish active Keys work → migrate to Postgres (5-7 days) → start maps rework with PostGIS available from day one.

Integration branch strategy: Do all work on an integration branch. Deploy a second Fly system from that branch to shake out issues in a real environment before cutover. This also solves matter 9ca2 (branch preview deploys) — standing up the infrastructure for branch-based deployments during the migration gives us that capability going forward.

Cutover plan: For 20MB the data transfer is seconds. Pipeline: (1) maintenance mode on SQLite system, (2) final Litestream flush, (3) export SQLite → Postgres (pgloader reads SQLite directly, or generate SQL), (4) load into Postgres, (5) verify row counts and spot check, (6) switch Fly deployment to Postgres-backed app, (7) verify production. Steps 3-5 under a minute at this size. Total downtime window under 5 minutes if rehearsed. Can rehearse unlimited times on integration deployment.

Key verification during integration: FTS indexes rebuilt correctly, all associations intact, no encoding issues with diacritical marks in species names, search quality parity.
