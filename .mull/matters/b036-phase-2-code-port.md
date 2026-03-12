---
status: refined
created: 2026-03-11
updated: 2026-03-11
epic: postgres
blocks: [1c9b]
needs: [f654]
parent: 4474
---

# Phase 2: Code port

## Goal

All application code running against Postgres. No SQLite-specific code remaining in the main app (WCVP repo excluded). Tests green. Docs updated.

## Steps

### 1. Mechanical query port
- `fragment("lower(?) LIKE ?")` → `ilike` (39 occurrences in 8 app files)
- `GROUP_CONCAT` → `string_agg` (2 files: ranges.ex, species.ex)
- `fragment("date(?)")` in analytics.ex (3 calls) — verify if Postgres handles `date()` as a type cast or if it needs `::date`. Fix if needed.
- Any other SQLite-specific fragments identified during the work

### 2. FTS migration
- Postgres tsvector column on species table with GIN index
- Database triggers to auto-sync on species INSERT/UPDATE and alias changes
- Rewrite search queries in search.ex, species.ex, plants.ex
- Remove manual FTS sync infrastructure: `update_species_fts/1`, `delete_species_fts/1`, `rebuild_species_fts/0`, all call sites
- Remove `sanitize_fts_query/1` (replace with Postgres tsquery construction)
- Update test seeds — remove `species_fts` INSERT statements, add tsvector population
- Search quality verified manually

### 3. Remove SQLite workarounds
- Delete `lib/gallformers/migration.ex` (safe_recreate_table module)
- Delete all old migration files (19 files) — baseline migration from Phase 0 replaces them. Old files `use Gallformers.Migration` and won't compile once the module is deleted.
- Delete `lib/mix/tasks/migrations/lint.ex` (migration linter)
- Remove `busy_timeout` config from all environments
- Remove `journal_mode: :wal` config from all environments
- Remove Litestream from Dockerfile and entrypoint
- Remove `litestream.yml`
- Remove kill_timeout Litestream flush logic
- Clean up any other SQLite-specific code paths

### 4. Documentation updates
- Update CLAUDE.md — remove all SQLite-specific caveats, add Postgres patterns
- Update CODING_STANDARDS.md — remove SQLite section, update query patterns, update test infrastructure docs
- Update README.md — dev setup instructions now require local Postgres
- Update any other docs referencing SQLite, Litestream, single-writer, busy_timeout, WAL mode, etc.
- Update runbooks as needed

## Output
- All tests pass against Postgres
- CI green
- No SQLite-specific code in main app
- FTS working with trigger-based sync
- All documentation current

