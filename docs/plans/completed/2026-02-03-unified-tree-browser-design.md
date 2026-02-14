# Unified Tree Browser Component Design

**Date**: 2026-02-03
**Status**: Draft
**Author**: Design session with Jeff

## Problem Statement

The Explore page and Family page both display taxonomic hierarchies (Family → Genus → Species) but use different implementations and UX patterns:

**Current issues:**
1. **Inconsistent navigation UX**: Explore page requires clicking an icon to navigate to family/genus pages, while species names are direct links. This is confusing.
2. **Buggy search behavior**: Searching on Explore page (e.g., "weldi") only auto-expands one branch even when multiple families/genera contain matches.
3. **Different visual styles**: Family page uses card/accordion UI with spacing and borders. Explore page uses tight hierarchical list. They should feel consistent.
4. **Duplicate logic**: Both pages implement tree rendering, expansion state, and filtering independently.
5. **Missing features**: Family page lacks search and expand/collapse controls that would be useful for large families.

## Design Goals

- **Consistent UX**: Same navigation pattern, visual style, and controls across both pages
- **Standard tree pattern**: Follow industry conventions (file explorer style)
- **Smart search**: Auto-expand when helpful, don't overwhelm when too many results
- **Reusable component**: Single implementation shared by both pages
- **Keep it simple**: Client-side filtering, load everything upfront (sufficient for current dataset)

## Design Overview

Create a shared `tree_browser` component that both Explore and Family pages will use. The component is presentational (doesn't own state), with parent LiveViews handling state management and events.

---

## Component Architecture

### New Component: `tree_browser`

**Location**: `lib/gallformers_web/components/tree_components.ex` (new file)

**Component API:**
```elixir
<.tree_browser
  id="galls-tree"
  nodes={@tree_data}              # Tree structure from Explore context
  expanded={@expanded_keys}       # MapSet of expanded node keys
  search_query={@search_query}    # Current filter text
  show_search={true}              # Show search input
  show_controls={true}            # Show expand/collapse all buttons
  on_toggle="toggle_node"         # Event when clicking chevron
  on_expand_all="expand_all"      # Event for expand all button
  on_collapse_all="collapse_all"  # Event for collapse all button
  on_search="search"              # Event for search input
/>
```

**Tree data structure** (already used by Explore page):
```elixir
[
  %{
    key: "f-123",                    # Unique identifier
    label: "Cynipidae (Wasp)",       # Display text
    url: "/family/123",              # Navigation target
    nodes: [                         # Children (recursive)
      %{
        key: "g-456",
        label: "Andricus",
        url: "/genus/456",
        nodes: [
          %{
            key: "s-789",
            label: "Andricus californicus",
            url: "/gall/789"
            # Leaf nodes have no `nodes` field
          }
        ]
      }
    ]
  }
]
```

**Responsibilities:**
- **Component**: Renders tree UI, emits events, handles recursion
- **Parent LiveView**: Owns state, handles events, implements smart expand logic

---

## Visual Structure & Navigation UX

### Standard Tree Pattern (file explorer style)

```
▶ Cynipidae (Wasp) (5)  🔗        ← Family: chevron left, name clickable, count, link icon
  ▶ Andricus (1)  🔗               ← Genus: indented, same pattern
    Andricus californicus          ← Species: more indented, no chevron
  ▶ Burnettweldia (5)  🔗
    Burnettweldia californicordazi ← Expanded species list
    Burnettweldia conalis
```

### Navigation Behavior

**Chevron button (left side):**
- Click to expand/collapse children
- Uses `ph-caret-right` icon, rotates 90° when expanded
- Only visible for branch nodes (families/genera with children)
- Emits `on_toggle` event with node key

**Name/label text:**
- Click to navigate to detail page:
  - Families → `/family/:id`
  - Genera → `/genus/:id`
  - Species → `/gall/:id` or `/host/:id`
- Styled as link with hover underline

**Link icon (right side):**
- `ph-arrow-square-out` icon for families and genera
- Visual indicator that name is navigable
- Species don't need icon (obvious they're links)

### Visual Styling (tight hierarchy)

**Spacing:**
- Tight vertical: `py-1` per item
- Level 0 (families): no left margin
- Level 1 (genera): `ml-5`
- Level 2 (species): `ml-10`

**Appearance:**
- No borders, no background colors, no card wrappers
- Family names: `text-gf-maroon font-medium`
- Genus names: `font-medium`
- Species names: `italic` (using `<em>` tag)

**Child count badges:**
- Show count next to families/genera: `(5)`
- Styled: `text-xs text-gray-400 ml-1`

---

## Search & Smart Expand Behavior

### Search Mechanics

When user types in search input (300ms debounce):

**1. Client-side filtering:**
- Filter tree to show only branches containing matches
- If species name matches: show family → genus → species path
- If genus name matches: show genus and all its species
- If family name matches: show entire family subtree
- Reuse current `filter_tree/2` logic from Explore page

**2. Smart expand with two thresholds:**

**Global threshold**: Only auto-expand if ≤ 3 families contain matches

**Per-node threshold**: Only expand a specific family/genus if it has ≤ 5 matching children

**Logic:**
```elixir
# Step 1: Count how many families have matches
matching_families = count_matching_families(filtered_tree)

if matching_families <= 3 do
  # Step 2: Selectively expand families/genera with ≤5 direct matches
  expanded = collect_branch_keys_with_limit(filtered_tree, max_children: 5)
else
  # Too many families match - don't auto-expand anything
  expanded = current_expanded
end
```

**Example with "weldi" search:**
- Matches in Cecidomyiidae (1), Cynipidae (5), and 1 other family → 3 families total ✓
  - Cecidomyiidae (1 species) → expands ✓
  - Cynipidae → expands ✓
    - Andricus (1 species) → expands ✓
    - Burnettweldia (5 species) → expands ✓
    - Diplolepis (8 species) → stays collapsed ✗ (>5 children)

**3. Visual feedback for non-expanded matches:**
- When not auto-expanding, show count badges to hint at matches
- Example: `Diplolepis (8)` indicates 8 matches but node stays collapsed

**4. Clear search:**
- Empty string restores original tree
- Keep expansion state as-is (don't auto-collapse)

### Expand/Collapse All Controls

**"Expand All" button:**
- Adds all branch node keys to `expanded` MapSet
- Works independently of search (can expand all while filtering)

**"Collapse All" button:**
- Clears the `expanded` MapSet
- Resets view to fully collapsed state

**Control placement:**
- Right side of page, above tree
- Same layout as current Explore page (lines 251-267)

---

## Implementation Strategy

### Phase 1: Extract Shared Component

**Create `lib/gallformers_web/components/tree_components.ex`:**
- Extract `tree_menu` logic from `explore_live.ex` (lines 333-390)
- Generalize to work with any tree structure
- Add props for search, controls, event handlers
- Include recursive tree rendering with indentation

**Implement smart expand helpers:**
- `count_matching_families/1` - counts families with matches
- `collect_branch_keys_with_limit/2` - collects keys respecting per-node limit
- Keep `filter_tree/2` logic (already works well)

### Phase 2: Refactor Explore Page

**Update `lib/gallformers_web/live/explore_live.ex`:**
- Replace inline `tree_menu/1` with `tree_browser/1`
- Update `handle_event("search", ...)` with two-threshold smart expand
- Keep tab switching logic (page-specific)
- Simplify render function (lines 199-326)

**Test:**
- Verify same visual appearance
- Test smart expand with various searches
- Verify search bug is fixed (all matches expand, not just one)

### Phase 3: Refactor Family Page

**Update `lib/gallformers_web/live/family_live.ex`:**
- Replace accordion UI (lines 163-201) with `tree_browser/1`
- Add search query and expanded keys to state
- Add event handlers for toggle, search, expand/collapse all
- Update `build_tree_data/1` to match Explore's tree structure format

**Adjust data loading:**
- Family page already uses `Taxonomy.get_children/1` for genera
- Already uses `Gallformers.Species.list_species_by_ids/1` for species
- Just needs to format into tree structure with correct keys/labels/urls

### Phase 4: Cleanup & Polish

**Remove duplicated code:**
- Delete old `tree_menu` component from `explore_live.ex`
- Delete old accordion rendering from `family_live.ex`

**Add tests:**
- Unit tests for smart expand logic
- LiveView tests for search behavior
- E2E tests for navigation patterns

---

## Migration Checklist

- [ ] Create `tree_components.ex` with `tree_browser/1` component
- [ ] Implement smart expand helper functions
- [ ] Refactor Explore page to use new component
- [ ] Test Explore page (visuals, search, navigation)
- [ ] Refactor Family page to use new component
- [ ] Test Family page (same controls now work)
- [ ] Add unit tests for smart expand thresholds
- [ ] Add E2E tests for tree navigation
- [ ] Remove old code
- [ ] Update CLAUDE.md to document tree_browser component

---

## Future Enhancements (Out of Scope)

**Not included in this design:**
- Lazy loading (load all upfront is sufficient for now)
- Keyboard navigation (arrow keys, etc.) - nice to have
- URL state for expansion (persist expanded nodes in URL)
- Adjustable thresholds (admin setting for 3/5 limits)
- Search highlighting (bold matching text)

These can be added later if needed.

---

## Open Questions

**Threshold tuning:**
- The 3-family and 5-children thresholds are initial guesses
- May need adjustment based on real usage patterns
- Easy to change - just update constants in search handler

**Genus detail page:**
- Design assumes `/genus/:id` route exists
- Need to verify this route/page is implemented
- If not, remove link icon from genera or implement page

---

## Success Criteria

✓ Single tree component used by both Explore and Family pages
✓ Consistent navigation UX (chevron expands, name navigates)
✓ Smart expand works correctly (expands all matches when ≤3 families, respects ≤5 per-node limit)
✓ Visual style matches current Explore tight hierarchy (no cards/borders)
✓ Family page gains search and expand/collapse controls
✓ Code is DRY - no duplicated tree rendering logic
