# P1: 90-Minute Unresponsive Outage - March 9, 2026

## Status: Closed — Root cause undetermined, mitigations deployed

## Summary

Production became completely unresponsive at ~2:52 PM ET on March 9 and remained a zombie
for 90 minutes until the BEAM process was killed at 4:23 PM ET. Fly auto-restarted the
machine at 4:25 PM ET and service resumed immediately. This was the longest outage in the
site's history.

All observable metrics (memory, CPU, traffic, request latency) were normal right up until
the instant the app died. The root cause could not be determined from available data. The
most likely explanation is a Fly.io host-level or hypervisor-level issue, but this could
not be confirmed.

The investigation yielded two mitigations: a health watchdog that prevents future 90-minute
zombie states, and a batched query fix for an N+1 pattern.

## Impact

- **Total outage**: ~93 minutes (2:52 PM - 4:25 PM ET)
- **Zero requests served** during the window (confirmed by request log gap)
- All traffic was bot/crawler — no known human users affected

## Machine Info

- Machine: `7847515a205e68` (blue-dawn-7651)
- Size: `shared-cpu-1x:1024MB`
- Region: iad
- Release: v142 (commit b9516e1d)

## Timeline (all ET = UTC-4, daylight saving started March 8)

| Time (ET) | Time (UTC) | Event |
|-----------|------------|-------|
| 10:16 AM | 14:16 | Deploy v142 — trivial fix (range map bbox tolerance) |
| 10:16 AM - 2:52 PM | 14:16 - 18:52 | ~4.5 hours normal operation, all metrics healthy |
| 2:52 PM | 18:52 | **Last request logged** — 200, 4ms response, normal |
| 2:52 PM | 18:52 | App becomes instantly unresponsive — no degradation |
| ~2:53 PM | ~18:53 | Fly health checks start failing, machine marked unhealthy |
| 2:53 - 4:23 PM | 18:53 - 20:23 | **90-minute zombie** — process alive but unresponsive |
| 4:23 PM | 20:23 | Process killed: `exit_code=-1, oom_killed=false, requested_stop=false` |
| 4:25 PM | 20:25 | Fly auto-restarts machine, first request served |
| 4:25 PM onward | 20:25+ | Normal operation, no further issues |

## What We Ruled Out

### Memory

Grafana memory chart showed flat, stable usage at ~460 MiB of 962 MiB total (~48%
utilization). No growth, no spike, no pressure. Fly reported `oom_killed=false`.

### CPU Credits

Initial analysis incorrectly identified CPU credit exhaustion as the cause. Closer
inspection of the Grafana CPU Quota chart with tooltip data showed:

- Utilization: **1.02%** (well below baseline)
- Baseline: **6.25%**
- Balance: **7.94 mins** (fully stocked, at cap)

The app was using ~1/6 of its CPU baseline. Credits were accumulating, not draining.
The balance line going UP and flatlining at max means credits were healthy.

### Traffic

- 40,759 total requests on March 9 (lower than March 8's 45,628)
- Normal hourly distribution, no unusual spikes
- No slow requests (>500ms) in the 2 hours before the outage
- Request rate was ~25-35/minute, consistent with previous days
- All 200 responses, normal 5-15ms latency, right up to the last request

### Admin / Write Activity

- Zero admin requests in the 2 hours before the outage
- No POST/PUT/PATCH/DELETE requests (only bot spam POSTs returning 404)
- `invalidate_gall_ranges_for_host` (new in PR #528) was never called

### Code Changes

v142 deployed that morning changed 2 files:

1. `range_map.js` — removed `isStyleLoaded()` guard (client-side only)
2. `places.ex` — added 0.01 tolerance to bbox span comparison

Neither could cause server-side CPU or lock issues.

PR #528 (v141, deployed March 8) was a major change (88 files, 15k insertions, 22k
deletions) including gall range curation, LiveView-to-controller conversions, and TDWG
mapping precision. Investigation of its SQLite interaction patterns found:

- New `gall_range` table (139K rows) queried on gall pages — but all queries were fast
- `invalidate_gall_ranges_for_host` does cascading writes — but wasn't called during outage
- Max galls per host is 124 (Quercus alba) — not enough for lock contention
- All traffic was read-only; SQLite WAL mode handles concurrent reads without locks

### Fly.io Platform

No incidents reported on status.flyio.net for March 9, 2026.

## What We Could Not Determine

The crash characteristics — instant death from a healthy state, 90-minute zombie where the
process is alive but completely unresponsive, terminated by SIGKILL (`exit_code=-1`) with no
application-level metric anomaly — are consistent with a host-level or hypervisor-level
issue that is invisible to application monitoring:

- Firecracker microVM freeze
- Host hardware issue
- Host-level resource contention
- Network partition between the VM and Fly's proxy

These would require Fly support to investigate using host-level telemetry.

## Mitigations Deployed

### 1. Health Watchdog (commit 5b1ab70c)

Added `Gallformers.HealthWatchdog` — a GenServer that checks DB connectivity every 30
seconds. After 5 consecutive failures (2.5 minutes), it calls `System.stop(1)` to trigger
Fly's `on-failure` restart policy.

**Why this matters:** Fly health checks only affect routing — they don't restart machines.
Without the watchdog, a zombie process sits indefinitely until it happens to crash on its
own. The watchdog turns a 90-minute outage into a ~3-minute recovery.

### 2. Batched Leaf Descendant Query (commit efae9cd7)

Replaced N+1 `Places.leaf_descendant_ids/1` calls in `split_by_precision` with a single
batched recursive CTE via `Places.batch_leaf_descendant_ids/1`. Previously each
country-level range entry triggered its own recursive query.

This was not related to the outage (only 2 country-level entries exist, and the function
ran fine) but is good hygiene for when more country-level data is added.

### 3. CPU Bump to shared-cpu-2x (commit 5b1ab70c)

Bumped from `shared-cpu-1x` to `shared-cpu-2x` in fly.toml. This was based on an
incorrect CPU credit analysis and is unnecessary — the app uses ~1% CPU against a 6.25%
baseline. Can be reverted to save cost.

## Recommendations

1. **File Fly.io support ticket** referencing machine `7847515a205e68` at
   `2026-03-09T20:23:35Z` to get host-level event data
2. **Revert CPU to 1x** when convenient — the bump provides no benefit
3. **Monitor** the health watchdog in logs — if it triggers, we'll know the app became
   unresponsive and recovered automatically
