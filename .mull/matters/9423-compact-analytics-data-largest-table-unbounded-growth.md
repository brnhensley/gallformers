---
status: raw
created: 2026-02-18
updated: 2026-02-18
epic: platform
---

# Compact analytics data (largest table, unbounded growth)

The analytics table is the largest table in the database and grows without bound. Investigate compaction strategies — rolling up old rows into summary aggregates, pruning raw data after N days, archiving to S3, or switching to a time-bucketed schema. Not urgent but will become a problem at scale.
