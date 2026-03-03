---
status: raw
effort: 1 day
created: 2026-02-18
updated: 2026-03-03
epic: platform
relates: [1edb, 8ae6, 8c5c]
---

# Audit LiveView usage — convert read-only pages to controllers

Every page in gallformers is a LiveView, including read-only display pages that don't need server-driven interactivity. Each LiveView page means: double mount (dead render + WebSocket), a long-lived process per open tab, all assigns held in process heap indefinitely.

## March 2-3 OOM incidents

Two OOM kills confirmed:
- ~11:30 PM ET March 2 (user-reported, GitHub issue #525)
- ~10:00 AM ET March 3 (confirmed oom_killed=true in fly machine events)

Root cause: issue #525 — host edit page bug where genus/name handling went wrong, causing runaway state. Being addressed separately.

Contributing factor: 75% bot traffic (GPTBot, ClaudeBot, Amazonbot, Meta) with ~42K requests/day, all hitting LiveView pages that hold process memory. The browse pages added in 9a14daf4 load full tree datasets (~1 MB for galls, ~670 KB for hosts, ~760 KB for places) into each process on mount.

## Candidate conversion list

| Page | Current | Traffic | Interactivity | Priority |
|------|---------|---------|---------------|----------|
| Browse galls (/galls) | LiveView | Moderate | Tree + search | High — 1 MB per mount |
| Browse hosts (/hosts) | LiveView | Moderate | Tree + search | High — 670 KB per mount |
| Browse places (/places) | LiveView | Moderate | Tree + search | High — 760 KB per mount |
| Species detail (/gall/:id, /host/:id) | LiveView | Highest (bot + human) | Read-only display | High — volume |
| Family (/family/:name) | LiveView | Moderate | Sort + search | Medium |
| Genus (/genus/:name) | LiveView | Moderate | Read-only display | Medium |
| Home (/) | LiveView | High | Mostly static | Low |

## Approach

Convert to controller + dead template (EEx). Existing pattern: PageController + PageHTML with embed_templates. SEO assigns pass through conn assigns to root layout. Tree interactivity approach TBD — needs design discussion.

## Investigation artifacts

- Request log analysis: 75% bot traffic, GPTBot (9.4K), Meta (9K), ClaudeBot (7.2K), Amazonbot (4K)
- Tree memory measurements: galls ~1 MB, hosts ~670 KB, places ~760 KB per process
- Machine: shared-cpu-1x with 1024 MB RAM

