# SQLite to PostgreSQL Migration: Feasibility & Impact Research

> **Date**: 2026-02-12
> **Status**: In-progress research
> **Purpose**: Comprehensive analysis of migrating from SQLite to PostgreSQL — covering code, infrastructure, operations, costs, and trade-offs.

## Context

Gallformers runs on SQLite with Litestream replication to S3. The database is ~27MB (≈5,800 species) hosted on a single Fly.io machine (shared-cpu-1x, 512MB RAM, 1GB volume). This document evaluates whether switching to PostgreSQL is worthwhile and what it would take.

---

## 1. Current SQLite Integration Inventory

SQLite is not just the database — it's the foundation for backup, deployment, operations, and testing.

### Code Touchpoints

| Area | Count | Details |
|------|-------|---------|
| Adapter config | 5 files | `repo.ex`, `config/{dev,test,runtime,config}.exs` |
| `fragment("lower(?) LIKE ?")` | 46 occurrences in 19 files | Workaround for missing `ilike` |
| FTS5 raw SQL queries | 7 queries in 3 files | `search.ex`, `species.ex` — MATCH, bm25() |
| FTS sync calls | 13 call sites | Manual `update_species_fts/1`, `delete_species_fts/1` |
| PRAGMA statements | 8+ sites | Migration module, runbooks, Makefile, GitHub Actions |
| Raw SQL in migrations | 6 migrations | SQLite-specific syntax |
| Migration module | 1 (`Gallformers.Migration`) | `safe_recreate_table` — works around 3 interacting SQLite constraints |
| Migration linter | 1 (`mix migrations.lint`) | Enforces use of `Gallformers.Migration` |

### Infrastructure Touchpoints

| Area | Files | Details |
|------|-------|---------|
| Dockerfile | 1 | Installs `sqlite` package + Litestream binary |
| docker-entrypoint.sh | 1 | Litestream restore, pre-migration backup, `litestream replicate -exec` wrapper |
| litestream.yml | 1 | 5-second S3 sync config |
| fly.toml | 1 | `DATABASE_PATH` env var, volume mount, 30s kill timeout for Litestream flush |
| Makefile | 8 targets | `download-db`, `upload-reset-db`, `check-db`, `dump-schema`, `test-db`, `test-prod-data` |
| GitHub Actions | 2 workflows | CI (test DB setup with `sqlite3`), daily snapshot (Litestream restore + sanitize) |
| OpenTofu/IAM | 2 files | `litestream-gallformers` IAM user, S3 bucket paths |
| Runbooks | 4-5 | Restore, reset, fly-operations, incident response — all assume file-based DB |
| Fly secrets | 2 | `LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY` |

### Test Infrastructure

| Area | Detail |
|------|--------|
| Serial execution | `max_cases: 1` in test_helper.exs (SQLite single-writer) |
| `async: false` enforced | DataCase + ConnCase raise on `async: true` |
| Test DB setup | `ecto.load` from `structure.sql` + `sqlite3 < test_seeds.sql` |
| Prod data tests | File copy: `cp gallformers.sqlite gallformers_test.sqlite` |
| WAL config | `journal_mode: :wal`, `busy_timeout: 5000` in test config |
| Test file count | 61 files, ~1,000 tests, all serial |

---

## 2. What Changes

### 2.1 Code Changes

#### Low Effort (mechanical)

**Adapter swap** — 5 files:
- `mix.exs`: `ecto_sqlite3` → `postgrex`
- `repo.ex`: `Ecto.Adapters.SQLite3` → `Ecto.Adapters.Postgres`
- `config/dev.exs`: `database: path` → `username/password/hostname/database`
- `config/test.exs`: same pattern, remove `journal_mode`, `busy_timeout`
- `config/runtime.exs`: `DATABASE_PATH` → `DATABASE_URL` with `url:` config

**ilike uplift** — 19 files, 46 occurrences:
```elixir
# Before (SQLite)
where: fragment("lower(?) LIKE ?", s.name, ^"%#{String.downcase(q)}%")

# After (PostgreSQL)
where: ilike(s.name, ^"%#{q}%")
```
Mechanical find/replace. Some may also gain `DISTINCT ON` where `group_by` was used as workaround.

**Remove SQLite workarounds** — delete/simplify:
- `lib/gallformers/migration.ex` (safe_recreate_table module) — delete entirely
- `lib/mix/tasks/migrations/lint.ex` (migration linter) — delete or simplify
- All existing migrations using `safe_recreate_table` — would work with standard `Ecto.Migration`
- `busy_timeout` config in all environments
- `journal_mode: :wal` config

#### Medium Effort

**Full-text search migration** (the biggest code change):

Current: SQLite FTS5 virtual table (`species_fts`) with `MATCH`, `bm25()`, porter stemmer, prefix indexes.

Target: PostgreSQL `tsvector` column on `species` table with GIN index, `@@` operator, `ts_rank()`.

| Aspect | SQLite FTS5 | PostgreSQL |
|--------|-------------|------------|
| Table | `CREATE VIRTUAL TABLE species_fts USING fts5(...)` | `ALTER TABLE species ADD COLUMN fts_vector tsvector` |
| Index | Built into virtual table | `CREATE INDEX ... USING GIN(fts_vector)` |
| Query | `WHERE species_fts MATCH 'q* alba*'` | `WHERE fts_vector @@ to_tsquery('english', 'q:* & alba:*')` |
| Ranking | `ORDER BY bm25(species_fts)` | `ORDER BY ts_rank(fts_vector, query)` |
| Prefix search | `prefix='2 3'` in table def | `:*` suffix in tsquery terms |
| Stemming | `tokenize='porter unicode61'` | Dictionary-based (english config) |
| Sync | Manual: 13 app-level call sites | Database triggers (automatic) |

Files to modify:
- `lib/gallformers/search.ex` — 4 FTS raw SQL queries
- `lib/gallformers/species.ex` — 3 FTS queries + `update_species_fts/1`, `delete_species_fts/1`, `rebuild_species_fts/0`, `sanitize_fts_query/1`

The two-layer ranking system (bm25 + custom `Search.Ranking`) can stay — just swap bm25 for ts_rank underneath.

**Migration to create the new FTS infrastructure:**
1. Add `fts_vector tsvector` column to `species`
2. Create function to build tsvector from species name + aliases
3. Create triggers on `species` INSERT/UPDATE and `alias_species` INSERT/DELETE
4. Populate initial values
5. Create GIN index
6. Drop `species_fts` virtual table

**Test seeds** — convert `priv/repo/test_seeds.sql` from SQLite to Postgres-compatible SQL (or Elixir seeds file).

**Existing migrations** — 6 migrations with raw SQL need review. Most should work, but table recreation patterns and any SQLite functions need porting.

#### Zero Effort (Ecto abstracts it)

All schema definitions, changesets, associations, preloads, and context functions using Ecto's query DSL work unchanged. This is the majority of the codebase.

### 2.2 Infrastructure Changes

**Dockerfile** — simplifies significantly:
- Remove: `sqlite` package, Litestream binary, `litestream.yml`, `aws-cli` (if only for SQLite)
- Add: `postgresql-client` (optional, for debugging)

**docker-entrypoint.sh** — drops from ~60 lines to ~10:
- Remove: Litestream restore, pre-migration backup logic, `litestream replicate -exec` wrapper
- Keep: Ecto migrations, app start

**fly.toml**:
- Remove: `DATABASE_PATH` env var
- Remove or repurpose: volume mount (may keep for request logs)
- Update: kill timeout (no longer waiting for Litestream flush)
- Add: `DATABASE_URL` reference (stored as Fly secret)

**Fly secrets**:
- Add: `DATABASE_URL`
- Remove: `LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY`

**CI workflow** (`.github/workflows/ci.yml`):
- Add Postgres service container
- Replace `sqlite3 < test_seeds.sql` with `psql < test_seeds.sql`
- Remove WAL file cleanup

**Snapshot workflow** (`.github/workflows/db-snapshot.yml`):
- Replace Litestream restore with `pg_dump`
- Replace `sqlite3 "PRAGMA integrity_check"` with Postgres validation
- Replace SQLite-based sanitization with SQL UPDATE via `psql`

**Makefile** — update 6-8 targets:
- `download-db`: `curl .sqlite` → download SQL dump + `psql` import
- `upload-reset-db`: `sqlite3` validation → `pg_dump` + S3 upload
- `check-db`: file existence check → `psql` connection check
- `dump-schema`: remove SQLite FTS/sequence cleanup
- `test-db`: `sqlite3 <` → `psql <`
- `test-prod-data`: file copy → `pg_dump`/`pg_restore`

**OpenTofu/IAM**:
- Rename or repurpose `litestream-gallformers` IAM user
- Repurpose S3 paths (`litestream/` → `postgres/`)
- If using external Postgres (not Fly): add RDS, security groups, VPC config

**Runbooks** — rewrite 4-5 operational runbooks:
- `restore-database.md`: Litestream → `pg_restore`
- `reset-production-database.md`: 10-step volume swap → `DROP/CREATE/pg_restore`
- `fly-operations.md`: remove volume/file-specific warnings
- `diagnose-deployment-issue.md`: update DB debugging steps

### 2.3 Test Changes

**Biggest win: parallel tests.** PostgreSQL's MVCC supports concurrent write transactions:
- Remove `max_cases: 1` from `test_helper.exs`
- Remove `async: false` enforcement from `DataCase` and `ConnCase`
- ~58 test files can use `async: true` → estimated **4-8x faster test suite**

Other changes:
- Config: remove `journal_mode`, `busy_timeout`, update to Postgres connection params
- Pool size: can increase from 5 to 10-20
- E2E tests: no change (shared sandbox works identically)
- Prod data tests: `cp file.sqlite` → `pg_dump`/`pg_restore` (slower but functional)

### 2.4 Backup Strategy

**Current (Litestream)**:
- Continuous S3 replication, 5-second sync interval
- Point-in-time recovery: `litestream restore -timestamp "2026-01-08T15:30:00Z"`
- Daily sanitized public snapshots via GitHub Actions
- Pre-migration file backups on-machine (keeps 10)

**Replacement options**:

| Option | RPO | Effort | Cost |
|--------|-----|--------|------|
| Fly Postgres snapshots | ~24h | Low (built-in) | Included with Fly Postgres |
| `pg_dump` cron to S3 | Configurable | Medium | S3 storage only |
| WAL-G continuous archiving | Seconds | High | S3 storage only |
| Managed backup (Neon/Supabase/RDS) | Varies | None | Included in service |

Litestream's ease of point-in-time recovery is the hardest thing to replicate cheaply. For a 27MB database, hourly `pg_dump` to S3 provides adequate protection with minimal effort.

---

## 3. Costs

### Current SQLite Cost
- Fly volume (1GB): ~$0.15/month
- Litestream S3 storage: negligible
- **Total incremental DB cost: ~$0.15/month**

### PostgreSQL Options (ranked by cost for ≤500MB hobby project)

| Option | Monthly | Annual Delta | Notes |
|--------|---------|-------------|-------|
| **Neon Free** | $0 | -$2 | 0.5GB, scales to zero, never expires, commercial OK |
| **Self-managed Fly Postgres** | ~$2 | +$22 | Cheapest on-Fly, no support, DIY ops |
| **Neon Launch** | $1-5 | +$12-58 | Usage-based, serverless |
| **Railway Hobby** | $5 | +$58 | $5 base includes usage credits |
| **Render Basic** | $6 | +$70 | Fixed pricing, simple |
| **Supabase Pro** | $25 | +$298 | Full platform, overkill for just DB |
| **Fly Managed Postgres** | $38+ | +$454 | Production-grade, overkill for hobby |

**Recommendation**: Neon Free for dev/staging validation ($0). For production, either Neon Free (if scale-to-zero latency is acceptable) or self-managed Fly Postgres (~$2/mo) for co-location with the app.

---

## 4. Features Lost

| Feature | Current (SQLite) | Impact |
|---------|-----------------|--------|
| Zero-dep local dev | Just a file, no server | Developers need Postgres installed locally |
| Instant DB copy | `cp file.sqlite` | Need `pg_dump`/`pg_restore` (seconds, not instant) |
| Litestream | 5-sec RPO, easy point-in-time recovery | Must build replacement backup strategy |
| File-based debugging | `sqlite3 /data/db.sqlite` via SSH | `psql` with connection string |
| Portable snapshots | `curl` a .sqlite file | Download SQL dump instead |
| Embedded simplicity | No separate process, no network | Separate database server/service |
| Single-file portability | Email/share a database file | Not practical with client-server DB |

---

## 5. Features Gained

| Feature | Impact |
|---------|--------|
| **Concurrent writes (MVCC)** | No single-writer bottleneck, no `busy_timeout` |
| **Parallel tests (`async: true`)** | 4-8x faster test suite (~58 files can parallelize) |
| **Native `ilike`** | Simpler queries, delete 46 fragment workarounds |
| **`DISTINCT ON`** | Cleaner queries where `group_by` is a workaround |
| **Standard migrations** | No `safe_recreate_table`, no PRAGMA dance, no connection pinning |
| **`release_command` works** | Migrations run properly on deploy (not hacked into entrypoint) |
| **Better query planner** | More sophisticated optimizer for complex joins |
| **Richer types** | Arrays, JSONB, enums, ranges, intervals |
| **Extensions** | PostGIS (range maps), pg_trgm (fuzzy search), pgvector (embeddings) |
| **Better FTS** | Configurable dictionaries, weights, phrase search, more tunable |
| **Parallel query execution** | Postgres can parallelize large analytical queries |
| **Connection pooling** | PgBouncer for high-concurrency scenarios |
| **Standard tooling** | Ecosystem of monitoring, backup, admin tools |

---

## 6. Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|-----------|-----------|
| FTS search quality regression | Medium | Medium | Test ranking quality thoroughly with production data before/after. Keep custom `Search.Ranking` layer. |
| Backup gap during transition | High | Low | Build and test Postgres backup before cutover. Keep Litestream running in parallel during transition. |
| Network latency | Low | Certain | DB in same Fly.io region (iad). 27MB DB = fast queries. Measure before/after. |
| Data migration failure | Low | Low | 27MB is trivial. Can test migration many times. Maintain SQLite backup for rollback. |
| Local dev friction | Low | Certain | Docker Compose with Postgres. Or use Neon free tier for shared dev DB. |
| Operational knowledge gap | Medium | Medium | Write runbooks before cutover. Practice restore procedures. |

---

## 7. Effort Estimate

| Phase | Days | Details |
|-------|------|---------|
| **Adapter + config swap** | 0.5 | `mix.exs`, `repo.ex`, `config/*.exs` |
| **ilike + query cleanup** | 1 | 46 fragment replacements, `DISTINCT ON` where applicable |
| **FTS migration** | 2-3 | Schema, triggers, query rewrites, ranking validation |
| **Infrastructure** | 1-2 | Dockerfile, entrypoint, fly.toml, Fly secrets, Postgres provisioning |
| **Backup strategy** | 1-2 | Replace Litestream, update snapshot workflow, test restore |
| **CI/CD** | 0.5 | Postgres service container, test DB setup |
| **Makefile + tooling** | 0.5 | Update all DB-related targets |
| **Test suite** | 1 | Enable async, update config, validate all tests pass |
| **Runbooks** | 0.5-1 | Rewrite 4-5 operational documents |
| **Migration execution** | 1 | Data migration, cutover, monitoring, rollback plan |
| **Total** | **10-14 days** | |

---

## 8. Migration Approach (if we proceed)

### Phase 1: Validate (zero risk, zero cost)
1. Provision Neon free tier for dev/staging
2. Port adapter config for dev environment
3. Run existing test suite against Postgres (find all breakage)
4. Benchmark FTS quality: same searches, compare results

### Phase 2: Code Migration
1. Replace all `fragment("lower(?) LIKE ?")` with `ilike`
2. Build FTS migration (tsvector + triggers)
3. Port FTS queries and validate search ranking with production data
4. Remove `Gallformers.Migration` module and linter
5. Enable `async: true` in tests

### Phase 3: Infrastructure
1. Update Dockerfile (remove SQLite/Litestream)
2. Update entrypoint, fly.toml, Fly secrets
3. Build backup strategy (`pg_dump` to S3)
4. Update CI workflow with Postgres service
5. Update Makefile targets

### Phase 4: Cutover
1. Final production backup via Litestream
2. Export SQLite → Postgres (data migration script)
3. Deploy Postgres-backed app
4. Verify search quality, backup procedures, monitoring
5. Keep SQLite backup for 30 days as rollback safety net

---

## 9. Open Questions

- **Neon free tier latency**: Does scale-to-zero cold start cause unacceptable delays for first request? Need to test.
- **FTS quality**: Will PostgreSQL's `ts_rank` produce comparable results to SQLite's `bm25` for our use case? Need side-by-side comparison with production queries.
- **Backup RPO**: Is hourly `pg_dump` acceptable, or do we need continuous WAL archiving? Current Litestream RPO is 5 seconds.
- **Local dev**: Docker Compose with Postgres, or shared Neon dev instance, or require local Postgres install?
- **Prod data test workflow**: `pg_dump`/`pg_restore` is slower than `cp`. Is the test-prod-data workflow still practical?
- **Timeline priority**: Is this worth doing now vs. other planned work (image processing, refactoring, etc.)?
