---
status: raw
effort: 1 day
created: 2026-02-18
updated: 2026-02-18
epic: platform
relates: [1edb, 8ae6, 8c5c]
---

# Audit LiveView usage — convert read-only pages to controllers

Every page in gallformers is a LiveView, including read-only display pages that don't need server-driven interactivity. Each LiveView page means: double mount (dead render + WebSocket), a long-lived process per open tab, all assigns held in process heap indefinitely.

## Candidates for conversion to controller + dead template

| Page | Current | Traffic | Interactivity |
|------|---------|---------|---------------|
| Species detail (/gall/:id, /host/:id) | LiveView | Highest (bot + human) | Read-only display |
| Explore (/explore) | LiveView | Moderate | Tree expand/collapse, search — all doable client-side |
| Home (/) | LiveView | High | Mostly static, counts gated behind connected? already |

## Options per page

1. **Controller + dead template** — one HTTP request, process dies, zero ongoing memory. Need small JS for client-side interactivity (Alpine.js or vanilla).
2. **Skinny LiveView with temporary_assigns** — keep LiveView convenience but shed data after render. Server-side search needs re-query.
3. **Keep LiveView, fix the waste** — gate behind connected?(), stop duplicating assigns, rely on hibernate_after.

## Why this matters

On a 512MB machine with 65% bot traffic, every species detail page hit spawns a LiveView process, runs mount twice, and holds a WebSocket connection. Bots don't run JS so the WebSocket never connects, but the dead render still allocates. Converting the highest-traffic read-only pages to controllers would eliminate this entire class of memory usage.

Species detail pages are likely the single highest-impact conversion — they're what bots crawl most.

Context: docs/investigations/20260218-oom-crash-bot-traffic-memory-accumulation.md
