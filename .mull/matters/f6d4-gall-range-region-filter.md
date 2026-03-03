---
status: raw
created: 2026-03-03
updated: 2026-03-03
epic: geo-expansion
relates: [8900, b9e5]
needs: [b9e5]
---

# Gall range region filter

GitHub: jeffdc/gallformers#522 (Megachile)

## Problem

Now that we're global, many galls occur only in their native range but their host plants are widely cultivated elsewhere. The current range map on the admin gall-host mapping page shows the union of all host ranges with no distinction between native and introduced. The admin's only recourse is manually excluding places one by one via the drill-down — tedious when a host is planted across dozens of countries.

## Root cause

WCVP provides native vs introduced status for every distribution record. Our pipeline imports and displays this distinction (the admin host form even has an "Include introduced range" checkbox), but `host_range` has no column to store it. Once saved, the distinction is permanently lost.

## Design

### Schema change

Add `distribution_type` column to `host_range`:

```sql
ALTER TABLE host_range ADD COLUMN distribution_type TEXT NOT NULL DEFAULT 'native'
  CHECK (distribution_type IN ('native', 'introduced'))
```

Two values only. Manually-added entries default to `native`.

### Preserve native/introduced at save time

Update all insert paths to pass `distribution_type`:
- `Ranges.add_place_to_host/3` — add parameter
- Host form WCVP apply flow — tag introduced places when saving
- Bulk WCVP backfill (matter b9e5) — must incorporate this

### Backfill existing hosts

For hosts with a `wcvp_id` in `host_traits`, re-query WCVP secondary DB and update existing `host_range` rows with the correct `distribution_type`. Rows not matchable to WCVP stay as `native` (the default).

### Gall-host admin page changes

With `distribution_type` stored, `Ranges.get_display_range_for_gall` can return range grouped by continent with native/introduced breakdown. The gall-host mapping page can then:

1. Show which host range codes are native vs introduced (visual distinction on map — new color?)
2. Default-exclude introduced range from the gall's map (bulk exclusion)
3. Let admin override — some galls do follow hosts to introduced range

The UI for this needs further design once the data foundation is in place.

## Relationship to b9e5 (bulk WCVP backfill)

The backfill matter (b9e5) is currently designed as additive-only `INSERT OR IGNORE` without native/introduced. That design must be updated to incorporate `distribution_type` before execution. These two matters should be coordinated — the schema migration should land first, then the backfill uses it.

## Sequencing

1. Schema migration (add column, default existing rows to native)
2. Update insert paths to preserve distribution_type
3. Backfill from WCVP for existing hosts
4. Gall-host admin UI changes (display + bulk exclusion)
