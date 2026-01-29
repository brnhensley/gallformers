# Explore Page - V1 vs V2 Comparison

**Route**: `/explore`
**Last Updated**: 2026-01-28

## Summary

The Explore page provides a tabbed interface for browsing taxonomic hierarchies. Both V1 and V2 implement three tabs (Galls, Undescribed Galls, Hosts) with tree-based navigation. V2 extends V1 functionality with additional features like search/filter, expand/collapse all controls, and species count badges.

## File Locations

| Component | V1 | V2 |
|-----------|----|----|
| Page/LiveView | `v1/pages/explore.tsx` | `lib/gallformers_web/live/explore_live.ex` |
| Data Fetching | `v1/libs/db/taxonomy.ts` (lines 347-404) | `lib/gallformers/explore.ex` |
| API Controller | N/A (static props) | `lib/gallformers_web/controllers/api/explore_controller.ex` |
| Helper Functions | `v1/libs/pages/renderhelpers.tsx` (lines 148-156) | Inline in `explore.ex` (lines 221-224) |

---

## UI Layer Comparison

### Tabs

| Feature | V1 | V2 | Notes |
|---------|----|----|-------|
| Tab names | "Galls", "Undescribed Galls", "Hosts" | "Galls", "Undescribed", "Hosts" | V2 uses shorter label |
| Tab component | React Bootstrap `<Tabs>` + `<Tab>` | Custom Tailwind buttons with border styling | V2: lines 201-229 |
| Default tab | "galls" (via `defaultActiveKey`) | "galls" (via `active_tab` assign) | Same behavior |
| Tab switching | React Bootstrap internal state | `phx-click="switch_tab"` event | V2: lines 46-53 |
| Species count badge | Not present | Shows count per tab in rounded pill | V2: lines 218-226, 178-189 |
| Active tab styling | React Bootstrap default | `border-gf-maroon text-gf-maroon` | V2 uses brand colors |

### Tree Menu Navigation

| Feature | V1 | V2 | Notes |
|---------|----|----|-------|
| Tree library | `react-simple-tree-menu` npm package | Custom recursive component `.tree_menu` | V2: lines 321-373 |
| Expand/collapse | Built into library, click to toggle | `phx-click="toggle_node"` with MapSet tracking | V2: lines 56-68 |
| Expand indicator | Library default (triangle) | Phosphor `ph-caret-right` with rotation | V2: lines 338-343 |
| Item click handling | `onClickItem` callback navigates | `<.link href={node.url}>` for leaves | V2: lines 362-368 |
| Styling | Library CSS (`react-simple-tree-menu/dist/main.css`) | Tailwind classes inline | V2 full control |
| Indentation | Library default | `ml-5` per level | V2: line 328 |

### Additional V2 UI Features

| Feature | Location | Notes |
|---------|----------|-------|
| Search/filter input | Lines 231-243 | `.search_input` component with debounce |
| Expand All button | Lines 245-250 | `phx-click="expand_all"` |
| Collapse All button | Lines 252-259 | `phx-click="collapse_all"` |
| Auto-expand on search | Lines 86-97 | Expands branches containing matches |
| Family name styling | Line 346 | Bold maroon for family-level nodes |
| Child count display | Lines 350-352 | Shows `(N)` count next to expandable nodes |
| Empty state messages | Lines 268-273, 284-289, 300-305 | Different messages for empty vs no-match |

---

## Business Logic Comparison

### Data Loading Strategy

| Aspect | V1 | V2 |
|--------|----|----|
| When loaded | Build time via `getStaticProps` | On LiveView mount |
| Caching | ISR with `revalidate: 1` | None (loaded per session) |
| All tabs loaded | Yes, all 3 trees at once | Yes, all 3 trees at once |
| Implementation | `v1/pages/explore.tsx:70-79` | `lib/gallformers_web/live/explore_live.ex:19-42` |

### Tree Building Logic

| Aspect | V1 | V2 |
|--------|----|----|
| Entry point | `toTree()` function (lines 81-98) | `build_tree()` function (lines 112-194) |
| Node structure | `{ key, label, nodes?, url? }` | `%{ key, label, nodes, url? }` |
| Key format | Numeric ID string (`"123"`) | Prefixed (`"f-123"`, `"g-123"`, `"s-123"`) |
| Sorting | In `toTree`: `.sort()` on child/species name | In query: `order_by: [f.name, g.name, s.name]` |
| Label formatting | `formatWithDescription(name, description)` | `format_label(name, description)` |

### Label Formatting

**V1** (`v1/libs/pages/renderhelpers.tsx:148-156`):
```typescript
export const formatWithDescription = (name, description, dash = false) => {
    if (!description || description.length === 0) {
        return name;
    } else if (Array.isArray(description)) {
        return `${name}${dash ? ' - ' : ' '}(${description.sort().join(', ')})`;
    } else {
        return `${name}${dash ? ' - ' : ' '}(${description})`;
    }
};
```

**V2** (`lib/gallformers/explore.ex:221-224`):
```elixir
defp format_label(name, nil), do: name
defp format_label(name, ""), do: name
defp format_label(name, "Plant"), do: name  # Special case to hide "Plant"
defp format_label(name, description), do: "#{name} (#{description})"
```

**Difference**: V2 explicitly hides "Plant" description for host families; V1 shows it.

### Tree Expansion State

| Aspect | V1 | V2 |
|--------|----|----|
| State management | Library internal | MapSet per tab in assigns |
| Per-tab expansion | Unknown (library behavior) | Yes, separate `galls_expanded`, `undescribed_expanded`, `hosts_expanded` |
| Expand all | Not available | Collects all branch keys into MapSet |
| Collapse all | Not available | Sets MapSet to empty |

### Search/Filter Logic (V2 Only)

**Location**: `lib/gallformers_web/live/explore_live.ex:141-172`

- `filter_tree/2`: Recursively filters tree nodes by label match
- `collect_matching_branch_keys/2`: Finds keys of branches containing matches for auto-expand
- Case-insensitive matching via `String.downcase/1`

---

## Data Layer Comparison

### Database Queries

**V1** (`v1/libs/db/taxonomy.ts:347-404`):
```typescript
getFamiliesWithSpecies = (gall: boolean, undescribedOnly = false) => {
    // Uses Prisma with nested includes:
    // taxonomy -> taxonomytaxonomy -> child (genus) -> speciestaxonomy -> species
    // Filters by description ('Plant' vs not) and undescribed flag
}
```

**V2** (`lib/gallformers/explore.ex:44-110`):
```elixir
defp fetch_tree_data("gall", undescribed_only) do
  from f in Taxonomy,
    join: g in Taxonomy, on: g.parent_id == f.id and g.type == "genus",
    join: st in "speciestaxonomy", on: st.taxonomy_id == g.id,
    join: s in Species, on: s.id == st.species_id,
    join: gs in GallSpecies, on: gs.species_id == s.id,
    join: gall in Gall, on: gs.gall_id == gall.id,
    where: f.type == "family" and f.description != "Plant" and s.taxoncode == "gall"
    # ... select flattened map
end
```

### Query Structure Differences

| Aspect | V1 | V2 |
|--------|----|----|
| ORM | Prisma | Ecto |
| Join style | Nested includes | Explicit joins |
| Result shape | Nested objects (taxonomy.taxonomytaxonomy.child...) | Flat map (family_id, genus_id, species_id, etc.) |
| Tree building | During `toTree()` from nested structure | During `build_tree()` from flat rows |
| Sorting | Post-query in JavaScript | In query via `order_by` |

### API Endpoint (V2 Only)

**Location**: `lib/gallformers_web/controllers/api/explore_controller.ex`
**Route**: `GET /api/v2/explore`

Returns JSON with same tree structure for external API consumers. Uses separate query logic (lines 48-160) rather than shared context module.

**Note**: There is code duplication between `Gallformers.Explore` and `GallformersWeb.API.ExploreController`. The API controller builds the tree differently:
- Uses `left_join` for family (nullable)
- Groups by family/genus tuples
- Different key format (`"family-123"` vs `"f-123"`)

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Route | `/explore` | `/explore` | Complete | Same route |
| Three tabs | Yes | Yes | Complete | |
| Galls by family | Yes | Yes | Complete | |
| Undescribed galls | Yes | Yes | Complete | |
| Hosts by family | Yes | Yes | Complete | |
| Tree navigation | react-simple-tree-menu | Custom component | Complete | Different implementation |
| Click to expand | Yes | Yes | Complete | |
| Click species to navigate | Yes | Yes | Complete | |
| Static generation | Yes (ISR) | No | Changed | V2 loads on mount |
| Search/filter | No | Yes | V2 Enhanced | New feature |
| Expand all | No | Yes | V2 Enhanced | New feature |
| Collapse all | No | Yes | V2 Enhanced | New feature |
| Species count badges | No | Yes | V2 Enhanced | Shows total per tab |
| Child count in tree | No | Yes | V2 Enhanced | Shows `(N)` next to expandable |
| Meta tags | Basic | Full SEO | V2 Enhanced | page_title, page_description |
| API endpoint | No | Yes `/api/v2/explore` | V2 Enhanced | External API access |

---

## V2 Missing Features

None identified. V2 implements all V1 functionality.

---

## Implementation Differences

### 1. Tree Menu Implementation
- V1 uses third-party `react-simple-tree-menu` with default styling
- V2 uses custom recursive component with full control over styling and behavior
- V2's approach allows for the additional features (search, expand/collapse all)

### 2. State Management
- V1: Library manages expansion state internally
- V2: Explicit MapSet tracking per tab, enabling features like "expand all matching"

### 3. Data Loading
- V1: Static site generation with ISR (data baked at build time)
- V2: LiveView loads data on mount (always fresh but slower initial load)

### 4. Sorting
- V1: Client-side sorting in `toTree()` function
- V2: Database-level sorting via `order_by` clause

### 5. Code Duplication
- V2 has separate tree-building logic in `explore.ex` and `explore_controller.ex`
- Key formats differ (`f-123` vs `family-123`)
- Consider extracting shared tree-building logic

---

## Recommendations

1. **Consolidate API controller logic**: Move tree-building from `explore_controller.ex` into `Gallformers.Explore` context to eliminate duplication.

2. **Unify key formats**: Use consistent key format (`f-123`, `g-123`, `s-123`) across LiveView and API.

3. **Consider caching**: V1's ISR approach meant fast loads; V2 could benefit from ETS caching for the tree data since it changes infrequently.

4. **Add URL parameters for tab**: Allow deep-linking to specific tabs (e.g., `/explore?tab=hosts`).

5. **Lazy load tabs**: Currently all three trees load on mount. Consider loading only active tab's data initially.
