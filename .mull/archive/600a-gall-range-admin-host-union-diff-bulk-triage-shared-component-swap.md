---
status: done
created: 2026-03-10
updated: 2026-04-17
epic: geo-expansion
relates: [383e, be9d, f6d4]
blocks: [53cb]
needs: [0df8, 6b43]
---

# Gall range admin — host-union diff, bulk triage, shared component swap

## Context

Layer 3 of the host range native/introduced architecture (matter 383e). Depends on Layer 2 (matter 0df8) which delivers the shared PlaceDrillDown component and PowoDiffReview LiveComponent.

The gall range system infrastructure is already complete (shipped in f6d4):
- `gall_range` table with stored curated ranges
- `gall_traits` with `range_confirmed` and `range_computed_at`
- Invalidation cascade (host range change -> gall `range_confirmed = false`)
- `GallHostLive` curation page with map, binary toggle, RangeDrillDown
- `GallRangeLive` bulk triage page with selection, bulk confirm
- All public consumers reading from `gall_range`
- All Ranges context query functions

What's missing: the diff/import workflow, component swap, and bulk page polish.

## Design decisions

- **Gall range is binary** -> in or out. No native/introduced on `gall_range` rows.
- **Host native/introduced is informational** -> shown on the map (solid vs hatched) but doesn't affect gall range storage.
- **Host union is the default starting point, not the authority.** The union of host native ranges is the suggested baseline for gall range, but admins can freely add or remove regions based on gall-specific evidence.
- **Introduced host range is visible but excluded from default selection.** It should appear in the diff as an opt-in suggestion, not be auto-applied.
- **"Refresh from hosts" is a manual advisory workflow**, not automatic. The `range_confirmed = false` flag tells the admin something changed in host data; they click to review what the host union suggests.
- **No reclassification tracking.** If a host place changes from native to introduced, that affects map styling and the suggested diff, not gall range membership by itself.
- **The diff review LiveComponent from Layer 2 is reused.** Same UI pattern -> buckets with select/deselect/apply. Different labels, different default selections.

## Gall range diff model

State matrix -> gall range `{not in range, in range}` vs host union `{not in hosts, host native, host introduced}`:

| Gall ↓ \ Hosts → | Not in hosts | Host native | Host introduced |
|---|---|---|---|
| Not in range | no-op | add candidate | add candidate (default off) |
| In range | outside suggestion | agreement | agreement |

Four diff buckets:

| Bucket | Meaning | Default selection |
|--------|---------|-------------------|
| `add_native` | In host native range, not in gall range | selected (accept) |
| `add_introduced` | In host introduced range only, not in gall range | NOT selected (opt-in) |
| `orphaned` | In gall range, not in any host range | selected (= keep; uncheck to remove) |
| `agree` | In both -> no action | not shown, collapsed count |

Compared to host POWO diff (6 buckets): simpler because gall range has no `distribution_type` to reclassify. The diff LiveComponent renders whatever buckets are non-empty -> it doesn't need to know whether it's showing a POWO diff or a host-union diff.

Important interpretation change: `orphaned` is a technical diff bucket, not an error bucket. These places are simply outside the current host-based suggestion. They may still be correct gall range based on direct evidence.

## Implementation Plan

**Goal:** Add a host-union review workflow to gall range editing, polish the bulk triage page, and swap to shared components from Layer 2.

**Architecture:** Diff computation lives in the Galls context. Diff review uses the shared PowoDiffReview LiveComponent from Layer 2. PlaceDrillDown replaces RangeDrillDown. GallRangeLive gets filters, pagination, and bulk recompute.

**Branch:** New branch off main after 0df8 merges.

---

### Task 1: Gall range diff computation in Galls context

**Files:**
- Modify: `lib/gallformers/galls.ex` (new public function)
- Create: `test/gallformers/galls/host_range_diff_test.exs`

**Behavior:**

New function:
```elixir
@spec compute_host_range_diff(
  gall_range_codes :: MapSet.t(),
  host_native_codes :: MapSet.t(),
  host_introduced_codes :: MapSet.t()
) :: map()
def compute_host_range_diff(gall_range_codes, host_native_codes, host_introduced_codes)
```

Takes:
- `gall_range_codes` -> MapSet of place codes currently in the gall's range
- `host_native_codes` -> MapSet of place codes from union of all hosts' native ranges
- `host_introduced_codes` -> MapSet of place codes from union of all hosts' introduced ranges (excluding any that are also in native)

Returns:
```elixir
%{
  add_native: [code],
  add_introduced: [code],
  orphaned: [code],
  agree_count: integer(),
  has_changes: boolean()
}
```

The caller (GallHostLive or bulk page) handles grouping for display and passes the result to the diff review component.

A helper function to gather the host union data:
```elixir
@spec compute_host_union_for_gall(gall_species_id :: integer()) :: {MapSet.t(), MapSet.t()}
def compute_host_union_for_gall(gall_species_id)
```

Returns `{native_codes, introduced_codes}` -> the union of all host ranges for the gall's hosts, split by `distribution_type`. Uses `Ranges.get_host_ranges_with_precision_for_species_ids/1` which already returns entries with `distribution_type`.

**Testing:**
- Empty gall range + host data -> everything in `add_native` / `add_introduced`
- Gall range matches host native -> `agree_count` correct, empty change buckets
- Gall range has places not in any host range -> those in `orphaned`
- Host native + introduced overlap -> native wins (place only appears in `add_native`)
- Mixed scenario -> correct distribution across all buckets

---

### Task 2: "Refresh from hosts" button and diff review in GallHostLive

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_host_live.ex` (button, event handler, diff component mount)
- Test: `test/gallformers_web/live/admin/gall_host_live_test.exs`

**Behavior:**

Add a "Refresh from hosts" button to the GallHostLive page (near the range section, below the host list). Only visible when a gall is selected.

On click:
1. Compute host union via `Galls.compute_host_union_for_gall/1`
2. Compute diff via `Galls.compute_host_range_diff/3`
3. Group for display (same `group_places_by_country` pattern)
4. Assign `host_range_diff` and render the PowoDiffReview component

The diff review component shows:
- `add_native` bucket (green) -> "Native host range places not in gall range" -> default selected
- `add_introduced` bucket (amber) -> "Introduced host range places not in gall range" -> default NOT selected
- `orphaned` bucket (neutral/warning styling, not error language) -> "Gall range places outside current host-range suggestion" -> default selected (= keep)
- `agree_count` as collapsed summary

On apply:
- Selected `add_native` and `add_introduced` -> add to `gall_range_place_ids`
- Unselected `orphaned` -> remove from `gall_range_place_ids`
- Recompute map display
- Mark dirty
- Admin still needs to click Save to persist

On cancel:
- Dismiss diff, no changes

**Testing:**
- Click refresh -> diff component appears with correct buckets
- Apply with defaults -> native adds included, introduced not, outside-suggestion places kept
- Toggle introduced places on -> they're added when applied
- Toggle outside-suggestion places off -> they're removed when applied
- Cancel -> no changes
- Save after apply -> correct `gall_range` persisted

**Notes:**
- The PowoDiffReview component from Layer 2 needs to support configurable default selections per bucket. In Layer 2 (POWO diff), all buckets default to selected. Here, `add_introduced` defaults to not selected.
- The refresh button could show a hint: "Host ranges have changed" when `range_confirmed` is false.
- This workflow is advisory. It should not imply that the host union is the only valid gall range.

---

### Task 3: Swap RangeDrillDown -> PlaceDrillDown in GallHostLive

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_host_live.ex` (component reference, callback handlers)
- Delete: `lib/gallformers_web/live/admin/range_drill_down.ex`
- Delete: `test/gallformers_web/live/admin/range_drill_down_test.exs` (if exists)
- Test: `test/gallformers_web/live/admin/gall_host_live_test.exs`

**Behavior:**

Replace:
```heex
<.live_component module={RangeDrillDown} ... />
```

With:
```heex
<.live_component module={PlaceDrillDown} mode={:gall} ... />
```

Update `handle_info` callbacks to match PlaceDrillDown message format. In gall mode, PlaceDrillDown sends `{PlaceDrillDown, {:toggle_place, code}}` etc. -> same semantics as current RangeDrillDown, just different module name. If the message format matches (designed in Layer 2 Task 3), this is a near-mechanical swap.

Delete `RangeDrillDown` and `CountryDrillDown` -> both replaced by `PlaceDrillDown`.

**Testing:**
- Open drill-down on country -> subdivisions shown with correct in-range/excluded colors
- Introduced places show amber indicator (read-only)
- Toggle subdivision -> place toggled in/out of gall range
- Include all / exclude all -> bulk toggle works
- Close -> panel closes, map zooms out

---

### Task 4: Polish GallRangeLive bulk triage page

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_range_live.ex` (filters, pagination, bulk recompute)
- Modify: `lib/gallformers/galls.ex` (query functions for filters, bulk recompute)
- Modify: `lib/gallformers_web/router.ex` (uncomment route)
- Test: `test/gallformers_web/live/admin/gall_range_live_test.exs`

**Behavior:**

**Filters** -> match HostRangeLive pattern:
- Status: Unconfirmed (default) / Confirmed / All
- Has range: All / Yes / No
- Search: by gall name (debounced text input)

**Pagination** -> same as HostRangeLive: `@page_size 50`, offset-based, `.pagination` component.

**Bulk recompute from hosts:**
- Admin selects galls, clicks "Recompute from hosts"
- Confirmation dialog: "Recompute range for N galls from host data? This will REPLACE the current gall range with the host-native union. Use only when you want to discard manual edits and reset to the host-based baseline."
- On confirm: iterate selected galls, for each compute host native union -> `Ranges.set_gall_range/2`, set `range_confirmed = true`, set `range_computed_at = now()`
- Progress bar (same async pattern as HostRangeLive bulk sync)
- Summary on completion: "Recomputed N galls, M had changes"

**Optional per-gall diff review:**
- Stretch goal, same as host bulk page. If implemented: expand a row to see the diff component inline. If not: admin clicks through to GallHostLive for per-gall review.
- Defer to follow-up if scope is too large.

**Route:** Uncomment `live "/gall-range", Admin.GallRangeLive` in router.ex. Add link from admin dashboard.

**Testing:**
- Filter by status -> correct galls shown
- Search by name -> debounced, correct results
- Pagination -> page navigation works
- Bulk confirm -> marks selected as confirmed
- Bulk recompute -> replaces gall ranges with host native union, shows progress
- Empty states -> correct messages per filter combination

---

### Task 5: Integration tests and cleanup

**Files:**
- Modify: `test/gallformers_web/live/admin/gall_host_live_test.exs`
- Modify: `test/gallformers_web/live/admin/gall_range_live_test.exs`
- Delete: `lib/gallformers_web/live/admin/range_drill_down.ex` (if not done in Task 3)
- Delete: `lib/gallformers_web/live/admin/country_drill_down.ex` (if not done in Layer 2)

**Behavior:**

Integration scenarios:

1. **Full invalidation round-trip:** Host range changes via POWO sync -> gall `range_confirmed` set to false -> admin opens gall-host page -> sees "needs review" banner -> clicks "Refresh from hosts" -> sees diff with new places -> applies -> saves -> range confirmed
2. **Outside-suggestion place handling:** Remove a host from a gall -> "Refresh from hosts" -> outside-suggestion places appear in diff -> admin keeps or removes them explicitly -> saves
3. **Introduced opt-in:** Host has introduced range -> refresh from hosts -> introduced places default to unselected -> admin selects some -> apply -> those places added to gall range
4. **Bulk recompute:** Select 3 galls -> recompute from hosts -> verify each gall's range matches host native union -> all confirmed

Cleanup:
- Verify no references to deleted RangeDrillDown or CountryDrillDown
- Run `mix precommit` clean

## Sequencing

```text
(Layer 2 complete -> PlaceDrillDown and PowoDiffReview exist)
  -> Task 1 (diff computation)
       -> Task 2 (refresh from hosts in GallHostLive)
  -> Task 3 (component swap - can parallel with 1)
  -> Task 4 (bulk page polish - can parallel with 1-3)
  -> Task 5 (integration tests - last)
```

Tasks 1, 3, and 4 can proceed in parallel. Task 2 depends on Task 1. Task 5 is last.

## Layer 2 dependency note

The PowoDiffReview component (Layer 2, Task 4) needs to support:
- Configurable default selections per bucket (`add_introduced` defaults to unselected here)
- Bucket labels passed as props (host diff says "POWO native", gall diff says "Host native range")
- Styling/wording that can treat the `orphaned` bucket as "outside current suggestion" rather than inherently erroneous

## Relationship to 53cb

Matter 53cb (genus-level host associations) depends on this matter resolving the range-authority question in the right direction.

This matter now assumes:
- Gall range is independent from host range
- Host union remains useful as a review tool and reset baseline
- "Refresh from hosts" is advisory
- Bulk recompute is a deliberate reset action, not routine synchronization

That alignment should remove the conceptual conflict between 600a and 53cb.
