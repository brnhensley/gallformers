---
status: raw
created: 2026-03-15
updated: 2026-03-16
epic: postgres
relates: [4474, 2574]
---

# WCVP migration from SQLite to Postgres

## Design

Two-pronged approach: fix the admin UX now, migrate to Postgres later.

### Prong 1: Async WCVP queries + loading feedback (do now)

All WCVP lookups in HostLive.Form are synchronous and blocking with no loading state. On cold SQLite this means 15+ seconds of dead UI.

**Changes:**
- Make WCVP typeahead search async (Task.async + handle_info) with loading_spinner in dropdown
- Make select/refresh actions async with loading_overlay on the form section
- If first query takes >2s, show "WCVP database warming up..." message
- HostRangeLive bulk sync already has progress bar — no changes needed there

**Why:** Doesn't make SQLite faster but makes slowness visible and tolerable. Small scope, immediate payoff for admins.

### Prong 2: Migrate WCVP to Postgres (do after main cutover is stable)

- Import WCVP tables into main Postgres instance using a separate `wcvp` schema
- Replace Repo.WCVP calls with main Repo queries scoped to wcvp schema
- Bump Fly volume to 3-4GB, possibly RAM to 2GB
- Adapt build pipeline: mix gallformers.wcvp.build_db writes to Postgres instead of SQLite
- Drop ecto_sqlite3 dependency
- Full dataset stays — no trimming

**Why:** Eliminates cold starts (connection pool always warm), better query planning on 700MB, consolidates to one DB engine, removes operational oddity of managing SQLite in a Postgres project.

### Sequencing

Prong 1 first (small, immediate). Prong 2 after main Postgres cutover (matter 4474) is stable.
