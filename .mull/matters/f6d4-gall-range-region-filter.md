---
status: planned
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

## Implementation Plan

**Goal:** Store native/introduced distinction for host range entries so the gall-host admin page can default-exclude introduced range from gall maps.

**Architecture:** Schema migration adds `distribution_type` to `host_range`. All insert paths (individual add, bulk update, WCVP flows) pass `distribution_type`. Range queries propagate the field so admin UI can distinguish native from introduced host range on the map. A backfill step tags existing rows using WCVP data.

### Task 1: Schema migration — add `distribution_type` to `host_range`

**Files:**
- Create: `priv/repo/migrations/<timestamp>_add_distribution_type_to_host_range.exs`
- Modify: `lib/gallformers/ranges/host_range.ex` (add field + changeset validation)

**Behavior:**
Migration adds `distribution_type TEXT NOT NULL DEFAULT 'native'` with a CHECK constraint to `host_range`. All existing rows default to `native`. The HostRange schema gets a new `:distribution_type` field with `default: "native"` and `validate_inclusion` for `~w(native introduced)`.

Update `@optional_fields` to include `:distribution_type`. The changeset already handles optional fields via `cast/3`.

**Testing:**
- Migration runs cleanly (up and down)
- HostRange changeset accepts `distribution_type: "native"` and `distribution_type: "introduced"`
- HostRange changeset rejects invalid distribution_type values
- Default is "native" when not specified

**Notes:**
Simple ALTER TABLE — no table rebuild needed since we're adding a column with a default. SQLite supports this directly.

### Task 2: Update insert paths to pass `distribution_type`

**Files:**
- Modify: `lib/gallformers/ranges.ex` — `add_place_to_host/3`, `normalize_entries/2`, `update_host_places/2`, `toggle_place_for_host/2`
- Test: `test/gallformers/ranges_test.exs`

**Behavior:**

`add_place_to_host/3` → `add_place_to_host/4` with optional `distribution_type \\ "native"`. Pass it through to the HostRange changeset.

`normalize_entries/2` currently accepts `{place_id, precision}` tuples or bare `place_id` integers. Extend to also accept `{place_id, precision, distribution_type}` triples. The two existing formats default `distribution_type` to `"native"`.

`update_host_places/2` (used by host form save) — currently does delete-all + insert-all. The caller must now pass distribution_type in the entries. The `normalize_entries` change handles this.

`toggle_place_for_host/2` — used by map click on host admin. Manual toggles default to `"native"`.

**Testing:**
- `add_place_to_host` with explicit "introduced" stores it correctly
- `add_place_to_host` without distribution_type defaults to "native"
- `update_host_places` preserves distribution_type from entries
- Round-trip: insert with "introduced", query back, verify field value

### Task 3: Host form — preserve native/introduced through WCVP flows

**Files:**
- Modify: `lib/gallformers_web/live/admin/host_live/form.ex` — WCVP prefill and apply flows
- Modify: `lib/gallformers/ranges.ex` — `update_host_places/2` caller contract

**Behavior:**

The host form already tracks native vs introduced place_ids separately in `wcvp_prefilled` and `wcvp_diff` assigns. The problem is that at save time (`save_wcvp_data/2` at line 981), it calls `Ranges.update_host_places(host.id, place_ids)` with a flat list of place_ids — no distinction.

**New host creation flow** (line 731+):
- `wcvp_prefilled` already has `place_ids` (native) and `introduced_place_ids` (introduced) as separate lists
- When `include_introduced` is toggled, the combined list is used
- Change: instead of merging into one flat list, pass entries as `{place_id, "exact", "native"}` or `{place_id, "exact", "introduced"}` so `normalize_entries` can distinguish them

**Existing host WCVP refresh flow** (line 288+):
- `apply_wcvp_updates` merges `selected_adds`, `selected_removes`, and `selected_introduced` into a single `exact_places` list
- Change: track introduced places separately through to save. One approach: keep two lists in assigns (`exact_places_native` and `exact_places_introduced`) or tag entries as tuples `{code, distribution_type}`. The simpler approach: add an `introduced_places` assign alongside `exact_places` and `country_places`, and merge them at save time with proper tags.

**Save path** (`save_wcvp_data/2` line 981):
- Currently: `Ranges.update_host_places(host.id, place_ids)` with bare IDs
- After: build entries list with `{place_id, precision, distribution_type}` tuples

**Testing:**
- New host created from WCVP with introduced places → `host_range` rows have correct `distribution_type`
- WCVP refresh on existing host → introduced places tagged correctly
- Toggle "include introduced" on/off → only affects introduced entries, native entries unchanged
- Manual range edits (map clicks) default to "native"

**Notes:**
This is the most complex task. The host form has multiple code paths that produce range data (new from WCVP, refresh from WCVP, manual map edits). All must converge on the same tagged entry format at save time. Be careful not to break the existing deferred-changes pattern — the form tracks unsaved changes and only writes on explicit Save.

### Task 4: Range queries — propagate `distribution_type` for gall display

**Files:**
- Modify: `lib/gallformers/ranges.ex` — `get_host_ranges_with_precision_for_gall/1`, `get_host_ranges_with_precision_for_species_ids/1`, `compute_display_range/2`, `split_by_precision/1`
- Modify: `lib/gallformers/ranges/display_range.ex` — add `introduced_range` field
- Test: `test/gallformers/ranges_test.exs`

**Behavior:**

The range queries that feed the gall-host admin page need to include `distribution_type` so the UI can distinguish native from introduced host range.

`get_host_ranges_with_precision_for_gall/1` (line 373) — add `hr.distribution_type` to the select map. Same for `get_host_ranges_with_precision_for_species_ids/1` (line 299).

`split_by_precision/1` (line 389) — currently splits on `precision` only. After: also split by `distribution_type`. The function should return `{exact_native, exact_introduced, inherited_native, inherited_introduced}` or a more structured format.

`compute_display_range/2` (line 324) — currently returns `%DisplayRange{in_range, inherited_range, excluded_range}`. After: also return `introduced_range` (exact + inherited codes that come from introduced host range, minus exclusions).

`DisplayRange` struct — add `:introduced_range` field (list of codes from introduced host range entries).

**Testing:**
- Gall with one host having native-only range → `introduced_range` is empty
- Gall with one host having both native and introduced range → codes correctly split
- Gall with multiple hosts, one native-only, one with introduced → union works correctly
- Exclusions subtract from introduced range too
- Country-level introduced range expands to leaf descendants correctly

**Notes:**
The key question for `split_by_precision` is whether introduced country-level entries should expand to inherited descendants. They should — the expansion is about display precision, orthogonal to native/introduced. But the resulting leaf codes need the introduced tag.

### Task 5: Gall-host admin page — display introduced range on map

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_host_live.ex` — pass introduced range to map, update `recompute_range`
- Modify: `lib/gallformers_web/components/data_display_components.ex` — `range_map` component: add `introduced_range` attribute
- Modify: `assets/js/hooks/range_map.js` — new color for introduced range, update `computeEffectiveSets` and `buildFillExpression`
- Modify: `lib/gallformers_web/components/data_display_components.ex` — update `.range_map_legend` for gall_admin mode

**Behavior:**

The gall-host admin page (`GallHostLive`) loads range via `Ranges.get_display_range_for_gall/1` and recomputes via `compute_display_range/2`. With `introduced_range` now available:

1. Pass `introduced_range` codes to the `.range_map` component as a new attribute
2. The JS hook renders introduced range in a distinct color (amber/yellow? — needs to be visually distinct from green/native, light green/inherited, and red/excluded)
3. Update the legend to explain the new color
4. The `push_range_update` event includes `introduced_range`

Color hierarchy in `buildFillExpression`: excluded (red) > in_range/native (green) > inherited/native (light green) > introduced (amber) > default (white). Excluded always wins.

**Testing:**
- Gall-host page renders introduced range codes in the new color
- Adding a host with introduced range shows the new color on map
- Removing that host removes the introduced codes
- Exclusions override introduced (clicking an introduced place to exclude it turns red)

**Notes:**
The `range-update` event payload in the JS hook needs to include `introduced_range`. The hook's `computeEffectiveSets` must subtract exclusions from introduced range too.

### Task 6: Gall-host admin page — bulk exclude introduced range

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_host_live.ex` — add continent-based bulk exclusion
- Modify: `lib/gallformers_web/live/admin/gall_host_live.ex` (template) — add UI controls

**Behavior:**

This is the payoff — the feature Megachile requested. With introduced range visible on the map, the admin needs a way to bulk-exclude it.

Add continent-level toggle controls to the gall-host admin page. When the admin loads a gall, the page groups introduced range codes by continent (using `Places.list_continents/0` + ancestor lookups). Each continent with introduced range gets a toggle.

**UI approach**: Above the map, show a row of continent chips/checkboxes. Only continents that have introduced range for this gall appear. All start unchecked (introduced range is shown but not auto-excluded). Clicking a continent checkbox bulk-adds all introduced range codes in that continent to the exclusion list. Unchecking removes them.

This operates on the existing exclusion system — no new data model. The bulk action just calls the same `toggle_exclusion` logic for multiple places at once. The existing Save button persists the exclusions.

**Events:**
- `exclude_continent_introduced` — receives continent code, finds all introduced range codes that are descendants, adds them to `excluded_place_ids`
- `include_continent_introduced` — reverse: removes those codes from `excluded_place_ids`

**Testing:**
- Continent chips only appear for continents with introduced range
- Checking a continent adds all its introduced codes to exclusions
- Unchecking removes them
- Manual exclusions (via drill-down) are preserved — bulk action is additive
- Save persists the bulk exclusions correctly

**Notes:**
Need `Places.ancestor_ids/1` or a precomputed code→continent mapping to group codes. Since this runs on the admin page (not public), a few extra queries are acceptable. Could cache the mapping in assigns on load.

### Task 7: Backfill existing `host_range` rows from WCVP

**Files:**
- Create: `priv/repo/migrations/<timestamp>_backfill_host_range_distribution_type.exs` (data migration)
  OR integrate into the bulk backfill task (b9e5)

**Behavior:**

For each host with a `wcvp_id` in `host_traits`:
1. Look up WCVP distributions via `Wcvp.Lookup.get/1`
2. Get `introduced_distribution` TDWG codes
3. Convert to gallformers place codes via `Wcvp.Tdwg`
4. Update matching `host_range` rows: `SET distribution_type = 'introduced'` where `species_id = X AND place_id IN (introduced_place_ids)`

Rows that don't match any WCVP introduced distribution stay as `native` (the default).

**Decision:** This could be a standalone data migration or folded into the b9e5 bulk backfill task. If b9e5 runs first and populates wcvp_ids for all hosts, this backfill can tag the introduced rows in a second pass. If this matter runs first, it only tags the ~62 hosts that currently have wcvp_ids.

Recommend: coordinate with b9e5. The schema migration (Task 1) lands first. The b9e5 backfill generates SQL that includes `distribution_type` in its `INSERT OR IGNORE` statements. Then no separate backfill migration is needed.

**Testing:**
- Host with known WCVP introduced range → rows correctly tagged
- Host without wcvp_id → rows unchanged (stay native)
- Idempotent: running twice doesn't break anything

## Dependency order

Task 1 (schema) → Task 2 (insert paths) → Task 3 (host form) and Task 4 (range queries) can proceed in parallel → Task 5 (map display) needs Task 4 → Task 6 (bulk exclude) needs Task 5 → Task 7 (backfill) needs Task 1, coordinates with b9e5.

## Sequencing

1. Schema migration (Task 1)
2. Insert paths (Task 2)
3. Host form flows + Range queries (Tasks 3 & 4, parallel)
4. Map display (Task 5)
5. Bulk exclusion UI (Task 6)
6. Backfill (Task 7, coordinated with b9e5)
