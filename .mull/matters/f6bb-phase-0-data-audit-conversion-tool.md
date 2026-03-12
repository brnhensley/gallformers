---
status: refined
created: 2026-03-11
updated: 2026-03-11
epic: postgres
blocks: [f654]
needs: [4474]
parent: 4474
---

# Phase 0: Data audit + conversion tool

## Goal

Local Postgres with real gallformers data, bootstrappable from Ecto migrations. Plus: any changes to the current production site needed to support the migration.

## Steps

### 0. Site operations features (on main, against current SQLite site)

**Maintenance banner:**
- Admin-controlled maintenance banner: text field + on/off toggle
- Super admin only
- Deploy to production so it's available well before cutover
- Details TBD on implementation (DB-backed vs config)

**Read-only mode:**
- Flag checked in the existing auth plug — if on, admin routes return maintenance message
- Public routes unaffected
- Enables safe cutover: deploy Postgres site in read-only mode, soak under real traffic, roll back to SQLite with zero data loss if needed
- Reusable for future maintenance: PG upgrades, schema migrations, anything requiring careful handling
- Could share admin UI with the maintenance banner toggle
- **Must include an escape hatch** — if the flag is DB-stored and you roll back to SQLite, admin UI can't turn it off (chicken-and-egg). Need an out-of-band mechanism: env var override, mix task via `fly ssh console`, or direct DB update. Decide during implementation.

### 1. Baseline migration
- Branch, swap main Repo adapter to Postgres
- Write a single migration that creates all tables from Ecto schemas
- Replaces `structure.sql` as the schema bootstrap
- Verify: `mix ecto.create && mix ecto.migrate` produces a complete, empty Postgres schema

### 2. Schema diff
- Dump actual prod SQLite schema (`sqlite3 gallformers.sqlite .schema`)
- Dump the Ecto-generated Postgres schema (`mix ecto.dump` or `pg_dump --schema-only`)
- Compare — identify everything in SQLite not captured by Ecto schemas
- Expected differences: FTS5 virtual table, check constraints added in raw SQL, indexes outside Ecto, triggers
- Decide per difference: port to Postgres, replace with Postgres equivalent, or drop

### 3. Data audit
- Script that checks every column in prod SQLite against Ecto-declared types
- Known risks: booleans stored as strings ("true"/"false" vs 1/0), empty strings where NULL expected, non-integer data in integer columns
- Output: mismatch report listing every column with problematic values and counts
- This report drives the type coercion logic in the conversion tool

### 4. Conversion tool
- Data-only — schema comes from Ecto migrations
- Reads from local SQLite copy, writes to local Postgres
- Handles type coercions identified in step 3
- Repeatable: run anytime to get a fresh Postgres from current prod snapshot
- Fast enough to run casually (not a ceremony)
- Used throughout the entire migration effort and one final time at cutover

## Conversion tool options (evaluate during this phase)
- **pgloader** — reads SQLite directly, handles type mapping, widely used
- **Custom script** — sqlite3 dump + transform + psql load, more control
- **Ecto-based** — read from SQLite repo, write to Postgres repo, type-safe but potentially slow at 140MB

## Output
- Maintenance banner + read-only mode deployed to production
- Baseline Postgres migration
- Schema diff report with decisions
- Data audit report
- Working conversion tool
- Local Postgres with real data, app can point at it

