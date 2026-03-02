---
status: raw
created: 2026-03-02
updated: 2026-03-02
epic: geo-expansion
relates: [d7d1, 8900]
---

# Bulk WCVP range backfill for all hosts

## Problem

Host species in the prod DB lack WCVP-sourced range data. The existing admin flow handles one host at a time. We need a bulk approach for all ~thousands of hosts.

## Approach: Local generation, prod SQL execution

Generate a self-contained SQL file locally, SFTP to prod, execute via sqlite3 CLI. Single transaction, minimal write lock time, no Mix/Ecto on prod.

## Pipeline

### Phase 0: Prepare mappings (done once, human-reviewed)

0.1. `make download-db` — fresh prod snapshot
0.2. `mix gallformers.wcvp.reconcile` — generates reconciliation reports
0.3. New Mix task generates a **mappings CSV** from reconciliation data:

```
species_id,species_name,wcvp_plant_name_id,wcvp_name,match_type,decision
4521,Quercus alba,12345,Quercus alba,exact,
4530,Rubus pensylvanicus,67890,Rubus pensilvanicus,fuzzy,
4535,Salix sp.,,,none,X
```

Decision column:
- exact → leave blank (auto-accepted)
- fuzzy → `A` accept, `R` reject, blank = unreviewed (errors at SQL gen time)
- none → `X` ignore

0.4. Same task generates an **unmatched hosts report** — shareable doc with host names, admin links, grouped by pattern (sp., undescribed, etc.). For admin team review, not blocking.

0.5. Human reviews CSV: mark fuzzy rows A or R. Save.

### Phase 1: Generate SQL (at go time)

1.1. `make download-db` — fresh prod snapshot (again)
1.2. **Drift check** — compare fresh DB against Phase 0 mappings. Report new hosts, deleted hosts, renames. Decide go/no-go.
1.3. Mix task reads reviewed CSV + wcvp.sqlite, resolves TDWG codes → place_ids, generates `.sql` file:

```sql
BEGIN;
INSERT OR IGNORE INTO host_range (species_id, place_id, precision) VALUES ...;
INSERT OR REPLACE INTO host_traits (species_id, wcvp_id, powo_id) VALUES ...;
COMMIT;
```

### Phase 2: Apply to prod

2.1. SFTP `.sql` to Fly machine
2.2. `sqlite3 /data/gallformers.sqlite < backfill.sql` via SSH

## Design decisions

- **Additive only**: `INSERT OR IGNORE` — never removes existing range data
- **Single transaction**: One write lock acquisition, fast execution
- **CSV for review**: Spreadsheet-friendly, simple A/R/X decisions
- **Drift check before apply**: Catches changes between mapping creation and execution
- **host_traits backfill included**: Writes wcvp_id/powo_id alongside ranges so future per-host WCVP refresh works

## New code needed

- Mix task: generate mappings CSV + unmatched report from reconciliation output
- Mix task: drift check (compare mappings CSV against current DB)
- Mix task: generate SQL from reviewed CSV + wcvp.sqlite
- Could be one task with subcommands or separate tasks

