# Place Detail Page: V1 vs V2 Comparison

**V1 Route**: `/place/[id]`
**V2 Route**: `/place/:id`

## Summary

The Place Detail page displays information about a geographic location (US state or Canadian province), showing the list of host plants found in that region. Both implementations provide similar core functionality but V2 adds client-side filtering and pagination.

---

## File Locations

### V1 Files
| Layer | File | Lines |
|-------|------|-------|
| Page Component | `v1/pages/place/[id]/index.tsx` | 1-127 |
| Database Access | `v1/libs/db/place.ts` | 74-108 (`placeById`) |
| API Types | `v1/libs/api/apitypes.ts` | 135-142, 615-621 |
| Edit Component | `v1/components/edit.tsx` | 1-26 |
| Table Styles | `v1/libs/utils/DataTableConstants.ts` | 1-28 |

### V2 Files
| Layer | File | Lines |
|-------|------|-------|
| LiveView | `lib/gallformers_web/live/place_live.ex` | 1-217 |
| Context | `lib/gallformers/places.ex` | 1-153 |
| Schema | `lib/gallformers/places/place.ex` | 1-63 |
| Host Query | `lib/gallformers/hosts.ex` | 147-162 (`get_hosts_for_place`) |

---

## UI Layer Comparison

### Page Header

| Feature | V1 | V2 | Status |
|---------|----|----|--------|
| Title format | `{name} - {code}` | `{name} - {code}` | Matched |
| Edit link | Unicode pencil (conditional on session) | Phosphor pencil icon (conditional on current_user) | Matched |
| Edit link destination | `/admin/place?id={id}` | `/admin/places/{id}` | Different routes |
| Parent info display | "a {type} of [the] {parent.name}" | "a {type} of [the] {parent.name}" | Matched |
| "the" prefix for US | Yes (hardcoded check for "United States") | Yes (same logic) | Matched |

### Host Plant List

| Feature | V1 | V2 | Status |
|---------|----|----|--------|
| Display method | react-data-table-component | Native HTML table | Different |
| Columns | Species Name, Aliases | Species Name only | **Gap: V2 missing aliases** |
| Sorting | Client-side, sortable columns | Pre-sorted by name (server-side) | Different approach |
| Default sort | "name" field | Already sorted | Matched |
| Name links | `/host/{id}` with italics | `/host/{id}` with italics | Matched |
| Row striping | Yes (DataTable `striped`) | Via `.gf-table` CSS | Matched |
| Search/filter | None | Real-time filter with debounce | **V2 Enhancement** |
| Pagination | None (all hosts shown) | 25 per page with navigation | **V2 Enhancement** |
| Empty state | None shown | "No host plants found for this location." | **V2 Enhancement** |
| No search results | N/A | "No hosts match '{query}'." | **V2 Enhancement** |

### SEO/Meta

| Feature | V1 | V2 | Status |
|---------|----|----|--------|
| Page title | `{place.name}` | `{place.name}` | Matched |
| Meta description | "Place {name}" | "{name} - Host plants found in this geographic location on Gallformers." | V2 improved |
| Canonical URL | None explicit | `/place/{id}` | **V2 Enhancement** |
| No-index on error | Not applicable (404 handled) | `page_noindex: true` | V2 explicit |

### Error Handling

| Feature | V1 | V2 | Status |
|---------|----|----|--------|
| Loading state | "Loading..." (router.isFallback) | N/A (server-rendered) | Different |
| Not found | Returns `notFound: true` (404 page) | Inline error message | Different |
| Invalid ID | 404 page | Inline "Invalid place ID" error | Different |

---

## Business Logic Comparison

### Data Assembly

**V1 (`v1/pages/place/[id]/index.tsx` lines 106-121)**
- Uses `getStaticProps` for static site generation
- Calls `placeById(id)` which returns `PlaceWithHostsApi`
- Place includes nested `hosts` array with aliases pre-loaded
- Sorting done client-side via DataTable

**V2 (`lib/gallformers_web/live/place_live.ex` lines 34-73)**
- Uses `mount/3` LiveView callback
- Makes 3 separate calls:
  1. `Gallformers.Places.get_place(place_id)` - basic place data
  2. `Gallformers.Places.get_parent_place(place_id)` - parent via join table
  3. `Gallformers.Hosts.get_hosts_for_place(place_id)` - hosts list
- Filtering/pagination done client-side in LiveView

### Key Differences

| Aspect | V1 | V2 | Notes |
|--------|----|----|-------|
| Rendering strategy | Static generation (ISR) | Server-side LiveView | V2 always fresh |
| Revalidation | 1 second | N/A (real-time) | Different caching |
| Data fetching | Single Prisma query with includes | 3 separate Ecto queries | V2 more explicit |
| Host aliases | Included in query | **Not fetched** | Gap |
| Search capability | None | Client-side filter | V2 enhancement |
| Pagination | None | 25 per page | V2 enhancement |

---

## Data Layer Comparison

### V1 Query (`v1/libs/db/place.ts` lines 74-108)

```typescript
db.place.findMany({
  include: {
    children: { include: { child: true, parent: true } },
    parent: { include: { child: true, parent: true } },
    species: {
      include: {
        species: {
          include: { aliasspecies: { include: { alias: true } } }
        }
      }
    },
  },
  where: { id: id },
  distinct: ['id'],
  orderBy: { name: 'asc' },
});
```

Returns `PlaceWithHostsApi`:
```typescript
type PlaceWithHostsApi = PlaceApi & {
    hosts: HostSimple[];  // includes id, name, aliases, datacomplete, places
};
```

### V2 Queries

**Place lookup (`lib/gallformers/places.ex` lines 39-41)**
```elixir
def get_place(id) do
  Repo.get(Place, id)
end
```

**Parent place (`lib/gallformers/places.ex` lines 54-68)**
```elixir
def get_parent_place(place_id) do
  from(p in "place",
    join: pp in "placeplace",
    on: pp.parent_id == p.id,
    where: pp.place_id == ^place_id,
    select: %{id: p.id, name: p.name, code: p.code, type: p.type},
    limit: 1
  )
  |> Repo.one()
end
```

**Hosts for place (`lib/gallformers/hosts.ex` lines 150-162)**
```elixir
def get_hosts_for_place(place_id) do
  from(s in Species,
    join: sp in "speciesplace",
    on: sp.species_id == s.id,
    where: sp.place_id == ^place_id and s.taxoncode == "plant",
    order_by: s.name,
    select: %{id: s.id, name: s.name}
  )
  |> Repo.all()
end
```

### Database Schema

**place table** (`priv/repo/structure.sql` lines 277-282):
```sql
CREATE TABLE IF NOT EXISTS "place" (
  id INTEGER PRIMARY KEY NOT NULL,
  name TEXT UNIQUE NOT NULL,
  code TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('continent', 'country', 'region', 'state', 'province', 'county', 'city'))
);
```

**placeplace join table** (lines 229-236):
```sql
CREATE TABLE placeplace (
    place_id INTEGER,
    parent_id INTEGER,
    FOREIGN KEY (place_id) REFERENCES place (id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES place (id) ON DELETE CASCADE,
    PRIMARY KEY (place_id, parent_id)
);
```

**speciesplace join table** (lines 237-243):
```sql
CREATE TABLE speciesplace (
    species_id INTEGER,
    place_id INTEGER,
    FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
    FOREIGN KEY (place_id) REFERENCES place (id) ON DELETE CASCADE,
    PRIMARY KEY (species_id, place_id)
);
```

---

## Full Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **UI - Header** |
| Place name + code | Yes | Yes | Matched | |
| Edit link (admin only) | Yes | Yes | Matched | Different route format |
| Parent relationship display | Yes | Yes | Matched | Same "the United States" logic |
| **UI - Host List** |
| Host name with link | Yes | Yes | Matched | |
| Host aliases column | Yes | No | **Gap** | V2 missing aliases |
| Sortable columns | Yes | No | Regression | V2 pre-sorted only |
| Client-side filtering | No | Yes | Enhancement | |
| Pagination | No | Yes (25/page) | Enhancement | |
| Empty state message | No | Yes | Enhancement | |
| **Business Logic** |
| Static generation | Yes (ISR) | No | Different | V2 real-time |
| Single query fetch | Yes | No (3 queries) | Different | V2 more explicit |
| Error handling | 404 page | Inline message | Different | |
| Loading state | Fallback text | N/A | Different | |
| **Data Layer** |
| Place basic data | Prisma include | Ecto Repo.get | Matched | |
| Parent via join | Prisma include | Raw SQL join | Matched | |
| Hosts with aliases | Yes | **No aliases** | **Gap** | |
| **SEO** |
| Page title | Yes | Yes | Matched | |
| Meta description | Basic | Improved | Enhancement | |
| Canonical URL | No | Yes | Enhancement | |

---

## Recommendations

### Critical Gaps

1. **Missing Host Aliases** (Priority: Medium)
   - V1 displays an "Aliases" column in the host table
   - V2 only shows species name, no aliases
   - **Fix**: Update `get_hosts_for_place/1` to join and include aliases:
     ```elixir
     # In lib/gallformers/hosts.ex
     def get_hosts_for_place(place_id) do
       from(s in Species,
         join: sp in "speciesplace", on: sp.species_id == s.id,
         left_join: als in "aliasspecies", on: als.species_id == s.id,
         left_join: a in "alias", on: a.id == als.alias_id,
         where: sp.place_id == ^place_id and s.taxoncode == "plant",
         group_by: [s.id, s.name],
         order_by: s.name,
         select: %{
           id: s.id,
           name: s.name,
           aliases: fragment("GROUP_CONCAT(?, ', ')", a.name)
         }
       )
       |> Repo.all()
     end
     ```
   - Then add "Aliases" column to the table in `place_live.ex`

### Enhancements in V2 (Keep)

1. **Client-side filtering** - Good UX for places with many hosts
2. **Pagination** - Handles large lists gracefully
3. **Improved SEO** - Better meta description and canonical URL
4. **Empty state messaging** - Better user feedback

### Potential Improvements

1. **Sortable columns** - V2 could add client-side sorting to match V1
2. **Loading indicator** - Could show skeleton while hosts load
3. **Error handling** - Consider redirecting to 404 for invalid places rather than inline error

---

## Status Summary

| Category | Count |
|----------|-------|
| Matched | 12 |
| V2 Enhancements | 6 |
| Gaps (V2 missing V1 feature) | 1 (aliases column) |
| Different Approaches | 5 |

**Overall Status**: Mostly complete with one notable gap (host aliases column missing in V2).
