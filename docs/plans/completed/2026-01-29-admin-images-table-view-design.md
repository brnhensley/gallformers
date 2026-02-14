# Admin Images: Table View with Bulk Copy Metadata

**Bead:** gallformers-quh7
**Date:** 2026-01-29
**Status:** Design complete, ready for implementation

## Overview

Add a table view to the admin images page that displays all image metadata in columns, with a bulk copy feature that lets users copy metadata from one image to multiple others.

The existing grid view remains unchanged. A view toggle lets users switch between grid (visual browsing, reordering) and table (metadata management, bulk operations).

## Goals

1. Make image metadata scannable at a glance
2. Restore bulk copy functionality from V1
3. Keep grid view intact for visual work and ordering

## Non-Goals

- Changing the grid view
- Adding reordering to the table view (grid handles that)
- Partial field copying (copy all or nothing)

## Design

### View Toggle

Location: Inside the "Images (X)" card header, right-aligned.

```
┌─ Images (12) ──────────────────────────────────────────────── [⊞] [≡] ─┐
```

- `[⊞]` Grid icon - current view (default)
- `[≡]` Table/list icon - table view
- Active view: maroon background, white icon
- Inactive view: outlined/ghost style
- Clicking switches views instantly
- Selection state (species) preserved across toggles

### Table Layout

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ [ ] │ Image    │ Def │ Creator   │ License │ Source  │ Src Link │ ... │ Actions   │
├─────┼──────────┼─────┼───────────┼─────────┼─────────┼──────────┼─────┼───────────┤
│     │ [thumb]  │  ✓  │ J. Smith  │ CC-BY   │ iNat    │ link...  │     │ [⋯] menu  │
│     │ [thumb]  │     │ —         │ —       │ —       │ —        │     │ [⋯] menu  │
│     │ [thumb]  │     │ A. Jones  │ CC0     │ Paper   │ link...  │     │ [⋯] menu  │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Columns:**

| Column | Width | Notes |
|--------|-------|-------|
| Checkbox | 40px | Hidden until copy mode active |
| Image | 120px | Thumbnail, reasonably sized |
| Default | 60px | Checkmark if default image |
| Creator | 120px | Creator/photographer name |
| License | 100px | License type (CC-BY, CC0, etc.) |
| Source | 150px | Linked source name (if associated) |
| Source Link | 150px | Truncated URL, opens in new tab |
| License Link | 150px | Truncated URL, opens in new tab |
| Attribution | flex | Additional attribution notes |
| Caption | flex | Image caption |
| Actions | 80px | Row action menu |

- Table horizontally scrolls on smaller screens
- Empty cells show "—" dash
- URLs truncated with ellipsis, full URL on hover/title

**Row Actions Menu:**

Each row has an actions menu (kebab ⋮ or inline buttons) with:
- **Copy from** - Enter copy mode with this image as source
- **Edit** - Open edit modal (same as grid view)
- **Delete** - Delete with confirmation (same as grid view)

### Copy Mode

#### Entering Copy Mode

1. User clicks "Copy from" on any row
2. UI transitions:

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ [☐] │ Image    │ Def │ Creator   │ License │ Source  │ ...  │ Actions             │
├─────┼──────────┼─────┼───────────┼─────────┼─────────┼──────┼─────────────────────┤
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│ SRC │ [thumb]  │  ✓  │ J. Smith  │ CC-BY   │ iNat    │ ...  │ [Apply] [Cancel]    │ ← yellow
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│ [ ] │ [thumb]  │     │ —         │ —       │ —       │ ...  │                     │
│ [✓] │ [thumb]  │     │ A. Jones  │ CC0     │ Paper   │ ...  │                     │ ← selected
└────────────────────────────────────────────────────────────────────────────────────┘
                                                              ☐ Select all
```

- Source row: yellow background (`bg-canary`), "SRC" badge in checkbox column
- Source row actions replaced with [Apply] [Cancel]
  - Apply: primary/maroon style, disabled until targets selected
  - Cancel: outlined/secondary style
- All other rows: checkbox appears in first column
- Header row: "Select all" checkbox
- View toggle: disabled during copy mode

#### Selecting Targets

- Click individual checkboxes to select/deselect
- Click "Select all" to select all non-source rows
- Selected rows get subtle highlight (lighter than source)
- Apply button shows selection state: enabled when ≥1 selected

#### Applying Metadata

1. User clicks [Apply]
2. Confirmation modal appears:
   ```
   ┌─────────────────────────────────────────────┐
   │ Copy Image Metadata                         │
   ├─────────────────────────────────────────────┤
   │                                             │
   │  Copy metadata from:                        │
   │  [thumbnail]  (creator, license, etc.)      │
   │                                             │
   │  To 3 selected images?                      │
   │                                             │
   │  Fields copied: creator, license,           │
   │  license link, source link, attribution,    │
   │  caption, source                            │
   │                                             │
   │              [Cancel]  [Copy Metadata]      │
   └─────────────────────────────────────────────┘
   ```
3. On confirm:
   - Batch update all selected images
   - Success flash: "Copied metadata to 3 images"
   - Exit copy mode
   - Table refreshes with updated data

#### Canceling

- Click [Cancel] button, or
- Press Escape key
- Exits copy mode immediately, no changes

#### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Only 1 image | "Copy from" button hidden or disabled |
| Source missing metadata | Allow copy, but show warning in confirmation: "Source image is missing some metadata. Empty values will overwrite existing data." |
| Navigate away mid-copy | Exit copy mode, discard selection |
| Apply with 0 selected | Apply button disabled |

### Fields Copied

All metadata fields are copied (matching V1 behavior):

- `creator`
- `license`
- `licenselink`
- `sourcelink`
- `attribution`
- `caption`
- `source_id` (foreign key to Source)

Additionally, `lastchangedby` is updated to the current user on all target images.

**Not copied:** `default`, `sort_order`, `path` (these are image-specific)

## Technical Implementation

### LiveView State

New assigns in `ImagesLive`:

```elixir
:view_mode   # :grid | :table (default :grid)
:copy_mode   # nil | %{source_id: integer, selected_ids: MapSet.t()}
```

### Events

| Event | Params | Description |
|-------|--------|-------------|
| `toggle_view` | `%{"view" => "grid"\|"table"}` | Switch view mode |
| `start_copy` | `%{"id" => image_id}` | Enter copy mode with source |
| `toggle_copy_target` | `%{"id" => image_id}` | Toggle target selection |
| `select_all_targets` | - | Select all non-source images |
| `cancel_copy` | - | Exit copy mode |
| `apply_copy` | - | Show confirmation modal |
| `confirm_copy` | - | Execute batch update |

### Context Function

New function in `Gallformers.Images`:

```elixir
@doc """
Copy metadata from source image to target images.

Copies: creator, license, licenselink, sourcelink, attribution, caption, source_id
Updates: lastchangedby on all targets

Returns {:ok, count} on success, {:error, reason} on failure.
"""
@spec copy_metadata(source_id :: integer, target_ids :: [integer], updated_by :: String.t()) ::
  {:ok, integer} | {:error, term}
def copy_metadata(source_id, target_ids, updated_by)
```

### Component Structure

The table view can be extracted to a component if it grows complex:

```
lib/gallformers_web/live/admin/images_live.ex      # Main LiveView
lib/gallformers_web/components/admin/              # Admin-specific components (if needed)
```

For initial implementation, keep it in the main LiveView file. Extract if it exceeds ~200 lines.

## Migration Path

1. Add `view_mode` and `copy_mode` assigns
2. Add view toggle UI in card header
3. Implement table view rendering (no copy mode yet)
4. Add `copy_metadata/3` context function
5. Implement copy mode UI and events
6. Add confirmation modal
7. Test end-to-end

## Open Questions

None - all resolved during design discussion.

## References

- V1 implementation: `v1/pages/admin/images.tsx` (lines 99-178 for columns, 238-282 for copy logic)
- Current grid view: `lib/gallformers_web/live/admin/images_live.ex`
