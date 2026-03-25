# P4: Apparent Early Morning Outage - March 19, 2026

## Status: Closed — no outage occurred

## Summary

Fly.io dashboards showed a data gap around 2:00-3:00 AM ET (06:00-07:00 UTC), which appeared
to be a full site outage. Postgres metrics also went dark in the same window, reinforcing the
impression.

**No outage occurred.** Request logs confirm the app served traffic continuously with zero
errors and normal latency throughout the window. The gap was caused by a Fly.io metrics
cluster incident that lost ~1 hour of metrics data starting at 06:07 UTC.

## Impact

- **Duration**: None — site was operational throughout
- **Scope**: Metrics visibility only — no user-facing impact

## Machine Info

- Machine: `7847515a205e68` (blue-dawn-7651)
- Size: `shared-cpu-1x:1024MB`
- Region: iad
- Release: v155 (deployed 2026-03-18 23:58 UTC)

## Timeline (all ET = UTC-4 EDT)

| Time | Event |
|------|-------|
| ~2:07 AM ET (06:07 UTC) | Fly metrics cluster begins losing data |
| 2:28 AM ET (06:28 UTC) | Fly posts "Investigating" on status page |
| 3:12 AM ET (07:12 UTC) | Fly posts "Monitoring — fix implemented, ~1h of metrics lost from 06:07 UTC" |
| 6:37 AM ET (10:37 UTC) | Fly marks incident resolved; lost metrics are unrecoverable |

## What We Ruled Out

- **App crash/restart**: Machine event log shows no events after the v155 deploy at 23:59 UTC on March 18
- **Actual outage**: Request logs show continuous traffic every minute from 05:30-07:30 UTC, zero 500 errors, zero slow requests (>1s)
- **Host maintenance**: `fly incidents hosts list` shows no host-level incidents
- **Postgres outage**: Postgres metrics gap was also caused by the metrics cluster issue, not a database problem

## Root Cause Analysis

Fly.io metrics cluster incident. Metrics were not collected for approximately 1 hour starting
at 06:07 UTC. The data gap on dashboards mimicked an outage but the app was healthy throughout.

## Lesson Learned

When Fly dashboards show a gap, check the request logs first. If requests were served
continuously with normal latency and status codes, the "outage" is a metrics gap, not an app
problem. Also check status.flyio.net for metrics-specific incidents.
