---
status: refined
created: 2026-03-25
updated: 2026-03-25
epic: platform
docs: [docs/architecture/oban-background-jobs-research.md]
relates: [7fda, 16bb, c52c]
blocks: [7fda, 16bb]
---

# Oban infrastructure — add job queue to the platform

## Context

Research completed in `docs/architecture/oban-background-jobs-research.md` (2026-03-21).
Oban OSS (Apache 2.0) is the clear choice — Postgres-backed, 66% Elixir adoption, no Redis needed.

Split from matter 7fda to decouple platform infrastructure from domain-specific ingestion work.
Oban infrastructure is a prerequisite for source ingestion (7fda) and image processing (16bb).

## Motivation

The Analytics.Rollup GenServer demonstrated real fragility in production after the Postgres
migration: handle_info crashes prevented rescheduling, 10k+ per-row INSERTs in a single
transaction timed out on Fly Postgres, and failures were completely silent. A fix shipped
(batch INSERTs, error recovery) but the underlying issues — no persistence, no retry
visibility, no monitoring — remain architectural gaps that Oban addresses structurally.

## Scope

### 1. Add Oban dependency and migrations
- `oban` hex package (OSS, Apache 2.0)
- Run `Oban.Migrations.up()` to create `oban_jobs` table
- Configure in application.ex supervisor tree (after Repo, before Endpoint)

### 2. Configuration
- Queues: `default` (general), `extraction` (LLM, concurrency 1-2), `maintenance` (rollups/cleanup)
- Plugins: Pruner (7-day retention), Reindexer, Lifeline (rescue orphans)
- Testing: inline mode for test env
- Autovacuum tuning for `oban_jobs` table

### 3. First consumer: migrate Analytics.Rollup to Oban cron worker
- Replace GenServer + Process.send_after with Oban cron plugin
- Cron schedule: `0 7 * * *` (07:00 UTC daily, same as current)
- Worker processes pending days with per-day error isolation (same logic, Oban wrapper)
- Prune as separate cron job or post-rollup step
- Gains: persistent job record, retry with backoff, error history, monitoring via Oban Web

### 4. Oban Web dashboard
- Mount at `/admin/jobs` (admin-only route)
- Provides queue monitoring, job inspection, retry/cancel controls

### 5. Documentation
- CLAUDE.md: Oban patterns, when to use Oban vs GenServer
- CODING_STANDARDS.md: worker conventions, testing patterns, transaction boundaries
- Runbook: queue management, troubleshooting failed jobs

## Design decisions (from research)

- **OSS only** — Pro is $135/mo for multi-node features we don't need (single Fly machine)
- **Share Ecto pool** — at our volume (~dozens of jobs/day), no dedicated pool needed
- **Transactional enqueue** — insert domain record + enqueue job atomically
- **PubSub for progress** — workers broadcast to LiveView for real-time status

## What stays as GenServer

- **HealthWatchdog** — periodic health checks, no persistence needed, no retries
- **SiteSettings** — persistent_term cache, event-driven, not a job
