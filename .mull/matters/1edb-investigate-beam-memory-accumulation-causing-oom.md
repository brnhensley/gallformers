---
status: raw
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
