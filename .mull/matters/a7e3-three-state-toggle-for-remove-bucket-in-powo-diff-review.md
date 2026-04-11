---
status: planned
created: 2026-04-11
updated: 2026-04-11
epic: admin
---

# Three-state toggle for remove bucket in POWO diff review

## Context

When applying WCVP range data to a host, the PowoDiffReview component shows a "remove" bucket for "Places in current range but not in WCVP." Currently this bucket uses simple checkboxes (checked = keep, unchecked = remove). But pre-existing regions not in WCVP may be valid — they're just not validated by WCVP data. The curator needs a way to keep them AND reclassify as introduced in the same review step.

Example: Quercus robur has NA states added before WCVP sync. WCVP doesn't list those states. They're valid (we have evidence) but should be marked introduced, not native. Currently the user must keep them, then manually edit each one afterward.

## Design Decision

Replace the checkbox in the remove bucket with a three-state cycle toggle per item:
- **Include Native** (green) — keep as-is
- **Include Introduced** (hatched green) — keep but reclassify
- **Do Not Include** (red) — remove from range

Add a review note at the top of the remove bucket explaining that these regions need careful review.

The other 4 buckets keep their existing checkbox UI. Only the remove bucket changes.

## Implementation Plan

**Goal:** Replace the remove bucket's checkboxes with three-state cycle toggles so curators can keep/reclassify/remove non-WCVP regions in one step.

**Architecture:** The remove bucket gets a custom render path in PowoDiffReview instead of sharing the selectable_tree component. The selection data model changes from a MapSet to a map of per-code decisions. The apply handler in form.ex is updated to process the new structure.

### Task 1: Change remove bucket data model in PowoDiffReview

**Files:**
- Modify: `lib/gallformers_web/live/admin/powo_diff_review.ex`

**Behavior:**
- `selected_remove` changes from `MapSet` to `%{code => :native | :introduced | :remove}`
- `init_selections/2` initializes remove bucket: all codes default to `:native` (keep as native, matching current "all selected" default)
- New event `cycle_remove` cycles a code: `:native → :introduced → :remove → :native`
- Group-level ops: `select_all_remove` sets all to `:native`, `deselect_all_remove` sets all to `:remove`
- Remove the macro-generated handlers for the remove bucket (toggle_item, toggle_group, select_all, deselect_all) and replace with explicit handlers
- `apply` event builds `selections.remove` as the map instead of a MapSet

**Testing:**
- `cycle_remove cycles through three states`
- `select_all_remove sets all to native`
- `deselect_all_remove sets all to remove`
- `apply sends remove map with per-code decisions`

### Task 2: Custom render for remove bucket

**Files:**
- Modify: `lib/gallformers_web/live/admin/powo_diff_review.ex`

**Behavior:**
- Remove bucket no longer uses `bucket_tree` / `selectable_tree`
- Render directly in `render/1` with:
  - Review note at top: "These places are in your current range but not found in WCVP data. Review each carefully — click to cycle through: Include as Native → Include as Introduced → Exclude from range."
  - Same expandable group structure (countries → subdivisions)
  - Per-item: a cycle button instead of checkbox, showing state with color + label
  - Summary line: "N kept (M as introduced), K excluded" instead of "(X/Y)"
- Visual states for the cycle button:
  - `:native` — green bg, check icon, "Native" label
  - `:introduced` — green bg with hatching (CSS), check icon, "Introduced" label
  - `:remove` — red bg, X icon, "Exclude" label

### Task 3: Update apply_powo_selections in form.ex

**Files:**
- Modify: `lib/gallformers_web/live/admin/host_live/form.ex`

**Behavior:**
- `apply_powo_selections/3` handles `selections.remove` as a map `%{code => :native | :introduced | :remove}`
- Codes with `:remove` → delete from range_entries
- Codes with `:native` → keep as-is (no change)
- Codes with `:introduced` → keep but set distribution_type to "introduced"
- Replace `remove_unselected/3` with `apply_remove_decisions/2`

**Testing:**
- Covered by updated PowoDiffReview integration test (apply sends correct structure)
- Verify in existing wcvp_test.exs that the full flow still works

### Task 4: Update tests

**Files:**
- Modify: `test/gallformers_web/live/admin/powo_diff_review_test.exs`
- Verify: `test/gallformers_web/live/admin/host_live/wcvp_test.exs`

**Testing:**
- Update rendering test: remove bucket shows cycle buttons, not checkboxes
- Update toggle interaction test: cycle through three states
- Update apply test: selections.remove is a map with decisions
- Verify existing wcvp integration tests still pass
