---
status: planned
created: 2026-02-18
updated: 2026-02-18
epic: images
relates: [1edb]
---

# AuditCache performance rework (lazy scan + hibernate)

Two fixes for the AuditCache GenServer identified during Feb 18 OOM investigation:

1. **Make S3 scan on-demand only** — Currently auto-triggers when TTL (1h) expires on any get_count/get_orphans call. The scan loads all S3 objects + all DB image paths + all species IDs into memory simultaneously, with quadratic list accumulation (acc ++ new_paths). Remove auto-trigger; only scan on explicit admin button click.

2. **Add hibernate_after to GenServer** — The orphan path list sits in the GenServer heap permanently between scans. Adding hibernate_after: 15_000 would compact the heap when idle.

Also review: the acc ++ new_paths pattern in Storage.list_gall_paths_recursive should be reversed to [new | acc] with a final Enum.reverse, or use a different accumulation strategy.

Context: docs/investigations/20260218-oom-crash-bot-traffic-memory-accumulation.md
Files: lib/gallformers/images/audit_cache.ex, lib/gallformers/images/audit.ex, lib/gallformers/storage.ex

## Implementation Plan (2026-02-18)

### Phase 1 — Stop the Bleeding (OOM fixes)

**1a. Remove auto-trigger scans from get_count and get_orphans**
- Delete the `if (stale? or ...) and not state.scanning?` blocks from both `handle_call` clauses in AuditCache
- These become pure reads: return cached data (or empty + stale)
- Only `handle_cast(:refresh)` triggers scans (explicit admin button)

**1b. Add hibernate_after: 15_000 to GenServer**
- In `start_link`: pass `hibernate_after: 15_000` to `GenServer.start_link`
- Between scans, BEAM compacts the process heap

**1c. Fix quadratic acc ++ new_paths in Storage.list_gall_paths_recursive**
- Change to `new_paths ++ acc` (prepend), skip Enum.reverse since orphan detection doesn't care about order

**1d. Fix scanning? race in handle_call paths**
- Goes away for free with 1a (auto-trigger removal)

### Phase 2 — Reduce Scan Cost

**2a. Remove unnecessary cache refreshes from delete/assign handlers**
- Remove `AuditCache.refresh()` calls from LiveView's delete_orphan and do_assign_orphan handlers
- Add `remove_path/1` API to AuditCache that removes a single path from cached list

**2b. Add PubSub notification for scan completion**
- AuditCache broadcasts on "image_audit" topic when scan completes
- LiveView subscribes in mount, handles message to reload data
- Remove the `Process.send_after(self(), :reload_orphans, 500)` hack

### Phase 3 — Reduce Peak Memory During Scan

**3a. Chunk the WHERE path IN (...) query in find_orphan_paths**
- SQLite SQLITE_MAX_VARIABLE_NUMBER defaults to 999
- Chunk paths into groups of 500, query each, merge MapSets

**3b. Eliminate intermediate paths variable**
- Restructure to stream through S3 objects and check DB in batches rather than loading everything into memory at once

### Phase 4 — Code Quality & Tests

**4a. Move TTL from process dictionary to struct field**
**4b. Extract state reset helpers in LiveView**
**4c. Simplify orphan grid IDs** — replace :crypto.hash(:md5, ...) with :erlang.phash2
**4d. Add missing tests:**
- "Path in S3, not in DB" orphan detection
- create_image_from_orphan happy path
- Scan completion sets data correctly
- Scan error handling
- Verify get_count/get_orphans do NOT trigger scans when stale
