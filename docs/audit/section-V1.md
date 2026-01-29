# Section Detail Page - V1 vs V2 Comparison

## Overview

The Section Detail page displays a taxonomic section (a subdivision within certain plant genera, primarily used for Quercus oaks) with its associated species list.

---

## V1 Implementation

**Route**: `/section/[id]`
**Main File**: `v1/pages/section/[id]/index.tsx` (lines 1-112)
**Database Functions**: `v1/libs/db/taxonomy.ts` (lines 474-498, 281-285, 435-447)
**API**: `v1/pages/api/taxonomy/section/index.ts` (lines 1-40)

### UI Layer

| Component | Description | Location |
|-----------|-------------|----------|
| Page Header | Section name with optional description in parens | lines 54-65 |
| Edit Button | Admin edit link (pencil icon) | lines 66-70, uses `Edit` component |
| Species Table | Sortable DataTable with italicized species names | lines 72-85 |
| Loading State | Shows "Loading..." during ISR | lines 43-46 |
| 404 State | Next.js ErrorPage component | lines 48-50 |

**Styling**: React Bootstrap (`Container`, `Row`, `Col`) with custom DataTable styles.

### Business Logic

The V1 page uses Next.js Static Site Generation (SSG) with Incremental Static Regeneration:

1. **`getStaticPaths`** (line 109): Fetches all section IDs via `allSectionIds()` for static generation
2. **`getStaticProps`** (lines 92-107): Loads section data via `sectionById()` with 1-second revalidation
3. **Component Logic**:
   - Uses `useMemo` to memoize column definitions (lines 29-40)
   - Sorts species by name client-side (line 76)
   - Formats display name: `name (description)` if description exists (line 54)

**Key Functions in `taxonomy.ts`**:

- `sectionById(id)` (lines 474-498): Fetches section with related species and aliases
- `allSectionIds()` (lines 281-285): Returns all section IDs as strings
- `getAllSpeciesForSectionOrGenus(id)` (lines 435-447): Generic species lookup

### Data Layer

**Query Pattern** (Prisma):
```typescript
db.taxonomy.findMany({
    select: {
        id: true,
        name: true,
        description: true,
        speciestaxonomy: { include: { species: true } },
        taxonomyalias: { include: { alias: true } },
    },
    where: {
        AND: [
            { id: { equals: id } },
            { type: { equals: 'section' } }
        ]
    },
})
```

**Response Shape** (`SectionApi` type):
```typescript
{
  id: number,
  name: string,
  description: string,
  species: SimpleSpecies[], // {id, taxoncode, name}
  aliases: AliasApi[]       // Not displayed on page
}
```

---

## V2 Implementation

**Route**: `/section/:id`
**Module**: `GallformersWeb.SectionLive` (`lib/gallformers_web/live/section_live.ex`, lines 1-151)
**Context**: `Gallformers.Taxonomy` (`lib/gallformers/taxonomy.ex`, lines 760-773)
**Schema**: `Gallformers.Taxonomy.Taxonomy` (`lib/gallformers/taxonomy/taxonomy.ex`)
**API**: `GallformersWeb.API.TaxonomyController.section/2` (`lib/gallformers_web/controllers/api/taxonomy_controller.ex`, lines 150-167)

### UI Layer

| Component | Description | Location |
|-----------|-------------|----------|
| Page Header | Section name with description in parens | lines 99-106 |
| Species Count | Count displayed in header `Species (N)` | lines 110-111 |
| Species Table | Static HTML table with italicized names | lines 114-135 |
| Error States | Red error boxes for invalid ID/not found | lines 95-97, 141-143 |
| Empty State | Italic "No species found" message | lines 136-138 |

**Styling**: Tailwind CSS with custom `gf-table` class and project colors (`text-gf-maroon`).

### Business Logic

LiveView-based with server-side rendering:

1. **`mount/3`** (lines 13-31): Parses ID, validates, loads data
2. **`load_section/2`** (lines 33-80):
   - Fetches taxonomy by ID
   - Validates type is "section"
   - Loads species via separate query
   - Sets SEO metadata
3. **`format_full_name/2`** (lines 82-88): Name formatting helper
4. **`render/1`** (lines 90-149): Inline HEEx template

**Key Functions in `Taxonomy` context**:

- `get_taxonomy(id)` (lines 59-62): Simple `Repo.get` by ID
- `get_species_for_section(section_id)` (lines 760-773): Dedicated section species query

### Data Layer

**Query Pattern** (Ecto):
```elixir
from(s in Species,
  join: st in "speciestaxonomy",
  on: st.species_id == s.id,
  where: st.taxonomy_id == ^section_id,
  order_by: s.name,
  select: %{
    id: s.id,
    name: s.name,
    taxoncode: s.taxoncode
  }
)
```

**API Response** (controller):
```json
{
  "id": 123,
  "name": "Lobatae",
  "type": "section",
  "description": "Red oaks",
  "species": [{"id": 1, "name": "Quercus rubra", "taxoncode": "plant"}]
}
```

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Route** | `/section/[id]` | `/section/:id` | Equivalent | Both use numeric ID |
| **Rendering** | SSG with ISR (1s) | LiveView SSR | Equivalent | V2 always fresh, V1 may be stale |
| **Page Title** | `Section {name}` | `Section {name}` | Equivalent | Both set meta title |
| **Name Display** | `name (description)` | `name (description)` | Equivalent | Same format |
| **Species Count** | Not shown | Shown in header | V2 Enhanced | V2 adds count |
| **Species Sorting** | Client-side via DataTable | Server-side ORDER BY | Equivalent | Same result, different location |
| **Table Sorting** | User-sortable columns | Static table | V1 Enhanced | V1 allows user sorting |
| **Edit Button** | Admin-only pencil icon | Missing | Gap | V2 lacks admin edit link |
| **Aliases** | Fetched but not displayed | Not fetched | N/A | Neither uses aliases |
| **Error Handling** | 404 ErrorPage | Inline red box | Equivalent | Different UI, same behavior |
| **Loading State** | "Loading..." text | N/A (SSR) | N/A | LiveView doesn't need loading |
| **Invalid ID** | 404 via getStaticProps | Error message | Equivalent | Different handling |
| **Type Validation** | In Prisma query WHERE | Explicit if-check | Equivalent | V2 more explicit |
| **SEO Description** | Static `Section {name}` | Dynamic with count | V2 Enhanced | V2 more descriptive |
| **API Endpoint** | `/api/taxonomy/section` | `/api/v2/sections/:id` | Equivalent | Both available |
| **Links to Hosts** | `/host/{id}` | `/host/{id}` | Equivalent | Same destination |

---

## Recommendations

### High Priority

1. **Add Admin Edit Button (V2)**
   - V1 shows edit pencil for logged-in admins
   - V2 should add `<.edit_button>` component to header
   - File: `section_live.ex`, add after line 105

### Medium Priority

2. **Add User-Sortable Table (V2)**
   - V1's DataTable allows sorting by column
   - V2 uses static HTML table
   - Consider adding sortable table component or accept simpler UI

### Low Priority / Deferred

3. **Aliases Display**
   - V1 fetches but doesn't display
   - V2 doesn't fetch
   - Low priority: unclear if sections have aliases in practice

4. **Consider Consistent Error Pages**
   - V1 uses full 404 page
   - V2 uses inline error
   - Could unify but both approaches are valid

---

## File References

### V1
- Page: `/Users/jeff/dev/gallformers/v1/pages/section/[id]/index.tsx`
- DB Functions: `/Users/jeff/dev/gallformers/v1/libs/db/taxonomy.ts` (lines 474-498)
- API: `/Users/jeff/dev/gallformers/v1/pages/api/taxonomy/section/index.ts`
- Types: `/Users/jeff/dev/gallformers/v1/libs/api/apitypes.ts` (lines 269-272)
- Edit Component: `/Users/jeff/dev/gallformers/v1/components/edit.tsx`
- DataTable Wrapper: `/Users/jeff/dev/gallformers/v1/components/DataTable.tsx`

### V2
- LiveView: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/section_live.ex`
- Context: `/Users/jeff/dev/gallformers/lib/gallformers/taxonomy.ex` (lines 760-773)
- Schema: `/Users/jeff/dev/gallformers/lib/gallformers/taxonomy/taxonomy.ex`
- API Controller: `/Users/jeff/dev/gallformers/lib/gallformers_web/controllers/api/taxonomy_controller.ex` (lines 134-167)
- Router: `/Users/jeff/dev/gallformers/lib/gallformers_web/router.ex` (line 149, 193)
