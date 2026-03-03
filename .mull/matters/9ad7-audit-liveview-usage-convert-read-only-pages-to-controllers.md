---
status: raw
effort: 1 day
created: 2026-02-18
updated: 2026-03-03
epic: platform
relates: [1edb, 8ae6, 8c5c]
---

# Audit LiveView usage — convert read-only pages to controllers

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

## JS strategy: no framework, better organization

Evaluated Alpine.js, Stimulus, and htmx. All rejected — they add a second reactivity system that conflicts with LiveView's DOM patching or duplicate what Phoenix already provides. The existing LiveView hooks pattern (mounted/updated/destroyed + pushEvent) is already a sufficient framework.

Current JS is ~2,500 lines across 7 files, with only 3 npm deps (MapLibre, PMTiles, D3). The complexity feeling comes from app.js being a 714-line grab bag of 10 inline hooks.

### Extract inline hooks from app.js

Move each inline hook in app.js to its own file under hooks/:

- `hooks/tabs.js` — tab switching with keyboard nav
- `hooks/image_gallery.js` — gallery navigation, lightbox, attribution
- `hooks/typeahead.js` — keyboard nav for search dropdowns
- `hooks/copy_to_clipboard.js` — clipboard API wrapper
- `hooks/auto_dismiss.js` — flash message auto-dismiss
- `hooks/input_event.js` — generic input event forwarder
- `hooks/scroll_to_couplet.js` — dichotomous key navigation
- `hooks/admin_nav.js` — active nav link highlighting
- `hooks/region_scope.js` — continent scope widget
- `hooks/region_prompt.js` — first-visit region prompt
- `hooks/indeterminate_checkbox.js` — tri-state checkbox

After extraction, app.js becomes ~30 lines: imports + LiveSocket setup.

### Client interactivity on converted controller pages

Pages converted to controllers lose LiveView hooks. For pages that need client interactivity (browse tree search/filter, family sort/search):

- Use standalone JS modules that attach via `data-` attributes on `DOMContentLoaded`
- No framework — it's filtering/sorting a list that was already server-rendered
- Tree data can be embedded as JSON in a `<script>` tag or `data-` attribute, filtered client-side
- These modules live alongside hooks/ but don't depend on LiveSocket

### Sequencing

1. Extract inline hooks (cleanup, no behavior change, can land independently)
2. Convert read-only pages to controllers (species detail, genus — no client JS needed)
3. Convert interactive-read pages (browse, family — needs standalone JS modules for search/filter)

## Investigation artifacts

- Request log analysis: 75% bot traffic, GPTBot (9.4K), Meta (9K), ClaudeBot (7.2K), Amazonbot (4K)
- Tree memory measurements: galls ~1 MB, hosts ~670 KB, places ~760 KB per process
- Machine: shared-cpu-1x with 1024 MB RAM

