---
status: refined
created: 2026-03-11
updated: 2026-03-11
epic: postgres
blocks: [b036]
needs: [f6bb]
parent: 4474
---

# Phase 1: Dev + CI workflow

## Goal

Development loop functional against Postgres: local Makefile targets work, CI pipeline exists. Tests will NOT fully pass yet — SQLite-specific code (FTS, GROUP_CONCAT) still in the codebase. Phase 2 gets tests green.

## Steps

### 1. Local CI (Makefile)
- Get all Makefile targets operational against Postgres
- `make test` — rebuilds test DB (now via `mix ecto.create && mix ecto.migrate && psql < test_seeds.sql`), runs tests
- `make precommit` — format, credo, compile --warnings-as-errors, tests
- Other targets: `make test-db`, `make ci`, etc.
- Test seeds ported from SQLite-flavored SQL to Postgres-compatible SQL
- Note: test seeds currently INSERT INTO `species_fts` — must be removed/rewritten since FTS5 virtual table won't exist in Postgres
- `make download-db` deferred — not needed during migration work (conversion tool from Phase 0 covers it)
- CI must support BOTH Postgres (main Repo) and SQLite (WCVP Repo) — WCVP tests need SQLite available

### 2. Enable async tests
- Remove `max_cases: 1` from `test_helper.exs`
- Remove `async: false` enforcement from DataCase and ConnCase
- Set `async: true` on test files (55 files)
- Fix any tests that break under concurrency — shared state assumptions, insertion order dependencies, etc.
- Risk: some tests may have implicit ordering dependencies that only surface under concurrency

### 3. GitHub Actions CI
- Separate workflow file for the integration branch (not modifying existing workflow)
- Postgres service container
- SQLite also available (needed for WCVP tests)
- Test seeds loaded via psql
- Scoped to integration branch via `on.push.branches` / `on.pull_request.branches`
- When migration merges to main: swap in as the primary workflow, delete old SQLite workflow

## Exit criteria
- Makefile targets run (some tests will fail due to SQLite-specific code — that's expected)
- Async test infrastructure in place
- CI pipeline exists and runs on the integration branch
- Phase 2 will get tests fully green

