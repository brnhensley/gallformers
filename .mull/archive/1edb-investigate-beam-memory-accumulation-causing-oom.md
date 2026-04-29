---
status: done
created: 2026-02-18
updated: 2026-02-18
epic: platform
relates: [8ae6, ee67, 9ad7, cd9d]
docket: 1
---

# Investigate BEAM memory accumulation causing OOM

## Context

OOM crash at 5:58 AM ET on 2026-02-18. Request logs show all HTTP responses completing in <407ms — the app is fast and healthy right up to the crash. This means the OOM is from gradual memory accumulation over the application's lifetime on a 512MB machine, not from individual request pressure.

## Investigation Areas

1. **BEAM allocator fragmentation** — many short-lived processes (bot + human HTTP requests) cause memory fragmentation where RSS grows but usable memory doesn't. Well-known BEAM issue with tuning flags (`+MBas`, `+MBcs`, etc.)
2. **LiveView processes holding stale assigns** — real users with tabs open for hours, each holding species data, image lists, etc. in process memory. Check if LiveView processes are being hibernated.
3. **ETS table growth** — PubSub tracking, telemetry, any caching tables that grow without bounds.
4. **Atoms table** — if anything is dynamically creating atoms (e.g., `String.to_atom`).
5. **Litestream memory footprint** — WAL reader for S3 replication.

## Approach

- Add BEAM memory telemetry to the health endpoint (`:erlang.memory/0`, process count, ETS table sizes) so we can observe accumulation patterns over time in production.
- Profile locally under sustained bot-like load to reproduce the growth pattern.
- Apply targeted fixes based on what the profiling reveals.

## Investigation Results (2026-02-18)

### Atoms table — CLEAN
Grepped for `String.to_atom` across `lib/`. Found 17 call sites, all converting fixed known strings (column names, tab names, filter types) from the app's own UI events. No arbitrary user input flows into atom creation. Atom table will plateau once every sort column and filter type has been seen. Not a leak risk.

### Litestream memory — LOW IMPACT
Checked via `/proc/<pid>/status` on prod. Litestream RSS is ~57 MB (~11% of 512MB). This is a fixed cost that doesn't grow over time — not a contributor to the accumulation pattern.

### LiveView hibernation — ADDRESSED
Hibernation was enabled in recent commits. Remaining risk is assigns holding references to large shared-heap binaries that survive hibernation, but this is low probability.

### Remaining areas
- **BEAM allocator fragmentation** — most likely root cause, requires empirical tuning of VM flags. Low urgency while recent changes (hibernation, pagination) hold.
- **ETS table growth** — spot-check via LiveDashboard next time on prod. AuditCache is the most likely offender (tracked in ee67).
