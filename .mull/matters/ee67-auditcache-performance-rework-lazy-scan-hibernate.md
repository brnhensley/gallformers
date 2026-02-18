---
status: raw
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
