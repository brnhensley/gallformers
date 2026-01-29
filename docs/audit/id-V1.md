# ID Tool: V1 vs V2 Comprehensive Comparison

**Route**: `/id`

## File Locations

### V1 (Next.js)
- **Primary**: `/Users/jeff/dev/gallformers/v1/pages/id.tsx` (1080 lines)
- **API Route**: `/Users/jeff/dev/gallformers/v1/pages/api/search/index.ts` (35 lines)
- **Filter Logic**: `/Users/jeff/dev/gallformers/v1/libs/utils/gallsearch.ts` (81 lines)
- **DB Queries**: `/Users/jeff/dev/gallformers/v1/libs/db/gall.ts` (lines 300-460)
- **Filter Fields**: `/Users/jeff/dev/gallformers/v1/libs/db/filterfield.ts`
- **API Types**: `/Users/jeff/dev/gallformers/v1/libs/api/apitypes.ts` (lines 496-513, 660-674)

### V2 (Phoenix LiveView)
- **Primary**: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/id_live.ex` (1107 lines)
- **Context**: `/Users/jeff/dev/gallformers/lib/gallformers/id_tool.ex` (480 lines)
- **Host Search**: `/Users/jeff/dev/gallformers/lib/gallformers/hosts.ex` (search_hosts)
- **Genus Search**: `/Users/jeff/dev/gallformers/lib/gallformers/taxonomy.ex` (search_genera_and_sections)

---

## Architecture Comparison

### V1 Architecture

```
User Action
    |
    v
React Component State (useState hooks)
    |
    v
useEffect (on hostOrTaxon change)
    |
    v
fetch() to /api/search
    |
    v
API Route (pages/api/search/index.ts)
    |
    v
Prisma Queries (libs/db/gall.ts)
    |
    v
Returns all matching galls (GallIDApi[])
    |
    v
Client-side filtering (checkGall in gallsearch.ts)
    |
    v
URL updated via router.replace (shallow)
```

**Key Insight**: V1 performs **client-side filtering**. All galls for a host/genus are fetched at once, then filtered in JavaScript using the `checkGall()` function.

### V2 Architecture

```
User Action
    |
    v
LiveView handle_event
    |
    v
push_patch (updates URL)
    |
    v
handle_params parses URL
    |
    v
apply_url_filters
    |
    v
IDTool.filter_galls (context module)
    |
    v
Ecto Query Builder (server-side filtering)
    |
    v
Results returned to socket assigns
```

**Key Insight**: V2 performs **server-side filtering**. Each filter change triggers a new database query with all filters applied.

---

## Filter Comparison Table

| Filter | V1 Implementation | V2 Implementation | Status | Notes |
|--------|-------------------|-------------------|--------|-------|
| **Host** | Typeahead, clears genus | Typeahead, clears genus | **Match** | Both mutually exclusive with genus |
| **Genus/Section** | Typeahead, clears host | Typeahead, clears host | **Match** | Both mutually exclusive with host |
| **Location** | Multi-select typeahead | Multi-select typeahead | **Match** | V1 has "leaf (anywhere)" virtual filter |
| **Detachable** | Typeahead (single) | Dropdown (single) | **Match** | Options: integral/detachable/both |
| **Place** | Typeahead (single) | Dropdown (single) | **Match** | US states/CAN provinces |
| **Family** | Typeahead (single) | Dropdown (single) | **Match** | Dynamically populated from results |
| **Textures** | Multi-select typeahead | Multi-select typeahead | **Match** | Advanced filter |
| **Alignment** | Typeahead (single) | Dropdown (single) | **Match** | Advanced filter |
| **Form** | Typeahead (single) | Dropdown (single) | **Partial** | V1 has "gall" virtual filter |
| **Walls** | Typeahead (single) | Dropdown (single) | **Match** | Advanced filter |
| **Cells** | Typeahead (single) | Dropdown (single) | **Match** | Advanced filter |
| **Shape** | Typeahead (single) | Dropdown (single) | **Match** | Advanced filter |
| **Color** | Typeahead (single) | Dropdown (single) | **Match** | Advanced filter |
| **Season** | Typeahead (single) | Dropdown (single) | **Match** | Advanced filter |
| **Undescribed** | Checkbox | Checkbox | **Match** | Advanced filter |
| **Show Non-Galls** | N/A | Checkbox | **V2 Only** | New in V2 |

---

## Filter Logic Differences

### V1 Client-Side Filtering (`gallsearch.ts:34-80`)

```typescript
export const checkGall = (g: GallIDApi, q: SearchQuery): boolean => {
    const alignment = dontCare(q.alignment) || (!!g.alignments && checkArray(g.alignments, q.alignment));
    const cells = dontCare(q.cells) || (!!g.cells && checkArray(g.cells, q.cells));
    // ... all filters combined with AND
    return alignment && cells && color && ... && family;
};
```

**V1 Logic**:
- All filters combined with AND
- Empty filter means "don't care" (no filtering)
- `checkArray()` requires ALL selected values to be present in gall
- Special handling for "leaf (anywhere)" virtual location
- Special handling for "gall" form (excludes non-gall forms)
- Detachable uses special matching: "both" matches everything, specific values also match "both"

### V2 Server-Side Filtering (`id_tool.ex:70-92`)

```elixir
def filter_galls(filters \\ %{}) do
  base_query()
  |> apply_host_filter(filters[:host_ids])
  |> apply_genus_filter(filters[:genus_id])
  |> apply_family_filter(filters[:family_id])
  |> apply_location_filter(filters[:location_ids])
  # ... chain of filter applications
  |> Repo.all()
  |> attach_images()
end
```

**V2 Logic**:
- Filters applied via Ecto query composition
- Each filter adds a JOIN and WHERE clause
- `nil` or `[]` means no filtering for that field
- Uses `WHERE x IN (list)` for multi-value filters
- Special handling for detachable (3 = both, matches with OR)

---

## Key Differences

### 1. Virtual Filters Missing in V2

**V1 "leaf (anywhere)"** (`gallsearch.ts:43-49`):
```typescript
if (q.locations.find((l) => l === LEAF_ANYWHERE)) {
    location = g.locations.some((l) => l.includes('leaf'));
    const locs = q.locations.filter((l) => l !== LEAF_ANYWHERE);
    location = location && (dontCare(locs) || (!!g.locations && checkArray(g.locations, locs)));
}
```
- V1 allows selecting "leaf (anywhere)" which matches any leaf-containing location
- **V2 Status**: Not implemented

**V1 "gall" form filter** (`gallsearch.ts:52-60`):
```typescript
if (q.form.find((f) => f === GALL_FORM)) {
    const forms = q.form.filter((f) => f !== GALL_FORM);
    form = !g.forms.find((f) => f === NONGALL_FORM);
    form = form && (dontCare(forms) || (!!g.forms && checkArray(g.forms, forms)));
}
```
- V1 allows selecting "gall" which excludes non-gall forms
- **V2 Status**: Replaced with "Show Non-Galls" checkbox (inverse logic)

### 2. Show Non-Galls (V2 Only)

V2 adds a new "Show Non-Galls" checkbox (`id_live.ex:964-980`):
```elixir
defp show_non_galls_filter(assigns) do
  ~H"""
  <.input type="checkbox" name="value" checked={@value} label="Show Non-Galls" />
  """
end
```

This is handled server-side (`id_tool.ex:426-440`):
```elixir
defp apply_exclude_non_gall_filter(query, true) do
  non_gall_gall_ids = from(gf in "gallform", ...)
  from [s, _gs, g] in query,
    where: g.id not in subquery(non_gall_gall_ids)
end
```

### 3. Multi-Value Filter Behavior

**V1**: Uses `checkArray()` which requires ALL selected values to be present
```typescript
const checkArray = (ts: string[], queryvals: string[]): boolean => {
    return queryvals.every((q) => ts.find((t) => t === q));
};
```

**V2**: Uses `WHERE x IN (list)` which matches ANY of the selected values
```elixir
defp apply_location_filter(query, location_ids) do
  from [s, _gs, g] in query,
    join: gl in "galllocation", on: gl.gall_id == g.id,
    where: gl.location_id in ^location_ids
end
```

**This is a semantic difference**: V1 filters are AND (must have all), V2 filters are OR (must have any).

### 4. URL Parameter Encoding

**V1**: Uses long parameter names
```typescript
const queryUrlParams = [
    'hostOrTaxon', 'type', 'detachable', 'alignment', 'walls',
    'locations', 'textures', 'color', 'shape', 'cells',
    'season', 'form', 'undescribed', 'place', 'family',
];
```

**V2**: Uses short codes for compact URLs
```elixir
@url_params %{
  host: "h", genus: "g", genus_type: "gt",
  locations: "lo", color: "co", shape: "sh",
  textures: "te", alignment: "al", detachable: "de",
  place: "pl", family: "fa", form: "fo",
  walls: "wa", cells: "ce", season: "se",
  undescribed: "un", show_non_galls: "ng"
}
```

**V1 also stores filter values as strings**, V2 stores as IDs (integers).

### 5. Family Filter Population

**V1**: Families extracted from results after initial fetch (`id.tsx:245`):
```typescript
setGallFamilies([...new Set(g.map((gg) => gg.family))].sort());
```

**V2**: Families loaded based on host/genus selection (`id_live.ex:161-177`):
```elixir
defp load_families_for_selection(host, nil) do
  Taxonomy.list_gall_families_for_host(host.id)
end
```

### 6. Data Completeness Warning

Both versions show a warning for incomplete hosts:

**V1** (`id.tsx:875-883`):
```jsx
{!isHostComplete(hostOrTaxon) && isHost(hostOrTaxon) && (
    <Alert variant="warning" className="small ps-2 py-1">
        This host does not yet have all of the known galls added...
    </Alert>
)}
```

**V2** (`id_live.ex:1018-1022`):
```elixir
<%= if @selected_host && !@selected_host.datacomplete do %>
  <div class="mb-3 p-2 bg-yellow-50 ...">
    This host does not yet have all known galls added...
  </div>
<% end %>
```

---

## Results Display Comparison

| Aspect | V1 | V2 |
|--------|----|----|
| Layout | Bootstrap Card grid (4 cols) | Tailwind grid (2/3/4 cols responsive) |
| Image | Card.Img with fallback | img with lazy loading |
| Name | Link with Card.Title | Link with italic text |
| Summary | Shown if no image | Shown if no image (generated server-side) |
| Badges | Datacomplete emoji, Edit button | Undescribed/Non-gall badges |
| Count | "Showing X of Y galls:" | "Showing X of Y species:" |

### V2 Improvements
- Lazy loading images (`loading="lazy"`)
- Better visual distinction for undescribed/non-gall entries
- Server-side summary generation for imageless galls
- More responsive grid layout

---

## Query Patterns

### V1 Initial Data Fetch

Host search (`gall.ts:410-412`):
```typescript
export const gallsByHostName = (hostName: string): TaskEither<Error, GallIDApi[]> => {
    return gallsByHostGenusForID([{ species: { hosts: { some: { hostspecies: { name: { equals: hostName } } } } } }]);
};
```

The query fetches ALL gall data for the host including all filter values, then client-side filtering happens.

### V2 Query Pattern

Each filter adds to the query (`id_tool.ex:260-268`):
```elixir
defp apply_location_filter(query, location_ids) do
  from [s, _gs, g] in query,
    join: gl in "galllocation",
    on: gl.gall_id == g.id,
    where: gl.location_id in ^location_ids
end
```

---

## Recommendations

### High Priority

1. **Multi-value filter semantics**: V2 should match V1's AND semantics (all selected values must be present) rather than OR (any selected value). This changes filtering behavior.

2. **"leaf (anywhere)" virtual filter**: Consider adding this convenience filter to V2's location options.

### Medium Priority

3. **URL backward compatibility**: V2 uses different parameter names. Consider supporting V1 parameter names for existing bookmarks.

4. **"gall" form virtual filter**: The V2 "Show Non-Galls" checkbox provides similar functionality but with inverse logic. Document this difference for users.

### Low Priority

5. **Edit button for admins**: V1 shows an edit button for logged-in users. V2 does not show this on the ID page.

6. **Phenology tool link**: V1 has a link to the phenology tool at the top. Consider adding to V2.

---

## Summary

The V2 implementation is largely feature-complete compared to V1, with a cleaner architecture (server-side filtering vs client-side). Key differences:

- **Architecture**: V1 client-side filtering, V2 server-side filtering
- **Filter semantics**: V1 AND (all values), V2 OR (any value) - needs alignment
- **Virtual filters**: "leaf (anywhere)" missing, "gall" replaced with "Show Non-Galls"
- **URL params**: Different encoding, not backward compatible
- **New feature**: V2 adds "Show Non-Galls" checkbox

The V2 approach is more scalable (less data transferred, filtering happens in DB) but the filter logic difference could cause user confusion during migration.
