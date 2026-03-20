---
status: done
created: 2026-03-16
updated: 2026-03-17
epic: platform
relates: [973c]
---

# Async WCVP queries + loading feedback in admin UI

## Scope

HostLive.Form WCVP queries are synchronous with no loading state. On cold SQLite = 15+ seconds of dead UI for admins.

## Changes

- Typeahead search (`search_wcvp` event): Task.async the Wcvp.Lookup.search call, show loading_spinner in dropdown
- Select action (`select_wcvp` event): Task.async the Wcvp.Lookup.get call, show loading_overlay on form section
- Refresh action (`refresh_from_wcvp` event): Task.async the lookup chain, show loading_overlay
- No-match modal search (`wcvp_nomatch_search` event): Same async pattern
- If any query takes >2s, show "WCVP database warming up..." message

## Not in scope

- HostRangeLive bulk sync — already has progress bar
- Wcvp.Lookup module itself — no changes needed
- SQLite performance tuning — Prong 2 (matter 973c) handles this via Postgres migration

## Key files

- lib/gallformers_web/live/admin/host_live/form.ex — all changes here
- lib/gallformers_web/components/ui_components.ex — loading_spinner, loading_overlay already exist
