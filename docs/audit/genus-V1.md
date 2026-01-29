# Genus Detail Page - V1 vs V2 Comparison

## Overview

| Aspect | V1 (Next.js) | V2 (Phoenix LiveView) |
|--------|--------------|----------------------|
| **Route** | `/genus/[id]` | `/genus/:id` |
| **Main File** | `v1/pages/genus/[id]/index.tsx` | `lib/gallformers_web/live/genus_live.ex` |
| **Rendering** | Static Site Generation (SSG) | Server-side LiveView |
| **Data Fetching** | `getStaticProps` at build time | `mount/3` on page load |

## File Locations

### V1 Files
- **Page**: `v1/pages/genus/[id]/index.tsx` (lines 1-95)
- **Species Table Component**: `v1/components/speciesTable.tsx` (lines 1-61)
- **Data Table Wrapper**: `v1/components/DataTable.tsx` (lines 1-12)
- **Data Layer**: `v1/libs/db/taxonomy.ts` (lines 81-92, 422-447)
- **Types**: `v1/libs/api/apitypes.ts` (lines 162-166, 233-246)
- **Render Helpers**: `v1/libs/pages/renderhelpers.tsx` (lines 148-156)
- **Page Helpers**: `v1/libs/pages/nextPageHelpers.ts` (lines 76-90)

### V2 Files
- **LiveView**: `lib/gallformers_web/live/genus_live.ex` (lines 1-159)
- **Context**: `lib/gallformers/taxonomy.ex` (lines 56-62, 444-451)
- **Schema**: `lib/gallformers/taxonomy/taxonomy.ex` (lines 1-61)
- **Species Query**: `lib/gallformers/species.ex` (lines 205-216)

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| **Route Pattern** | `/genus/[id]` | `/genus/:id` | Equivalent | Same URL structure |
| **Page Title** | `{genus.name}` with description | `Genus {genus.name}` | Different | V2 prefixes with "Genus " |
| **Meta Description** | `Genus {genus.name}` | `{name} - A taxonomic genus documented...` | V2 Enhanced | V2 includes species count |
| **Genus Name Display** | Italic with optional description | Italic with optional description | Equivalent | Both use `formatWithDescription` pattern |
| **Family Link** | Link to `/family/{id}` with italic name | Link to `/family/{id}` with italic name | Equivalent | Same behavior |
| **Family Description** | Shown in parentheses | Shown in parentheses (conditional) | Equivalent | V2 uses `:if` for nil check |
| **Species Table** | react-data-table-component | Native HTML table with `.gf-table` | Different | V2 uses simpler HTML |
| **Table Columns** | Name + Taxon Type | Name only | V2 Missing | V1 shows "Gall Former" or "Host" column |
| **Table Sorting** | Client-side sortable | No sorting | V2 Missing | V1 uses DataTable sorting |
| **Species Links** | `/gall/{id}` or `/host/{id}` | `/gall/{id}` or `/host/{id}` | Equivalent | Both route by taxoncode |
| **Empty State** | No explicit empty state | "No species found for this genus." | V2 Enhanced | V2 has better UX |
| **Error Handling** | 404 ErrorPage component | Error div with red styling | Different | Both handle not-found |
| **Loading State** | "Loading..." during fallback | None (server-rendered) | Different | SSG vs SSR |
| **Data Validation** | Type guard `genus.length <= 0` | Pattern match on `%{type: "genus"}` | V2 Enhanced | V2 validates type |
| **SEO - noindex** | Not specified | `page_noindex: false` | V2 Enhanced | V2 manages indexing |
| **Species Count** | Not displayed | Shown in heading `Species (N)` | V2 Enhanced | Better UX |

---

## UI Layer Analysis

### V1 UI Structure (`v1/pages/genus/[id]/index.tsx` lines 36-65)

```tsx
<Container className="pt-2" fluid>
  <Head>
    <title>{fullName}</title>
    <meta name="description" content={`Genus ${gen.name}`} />
  </Head>
  <Row>
    <Col>
      <h1>Genus <i>{fullName}</i></h1>
    </Col>
  </Row>
  <Row>
    <Col>
      <strong>Family:</strong> <Link href={`/family/${fam.id}`}><i>{fam.name}</i></Link>
      {` (${fam.description})`}
    </Col>
  </Row>
  <Row className="pt-3">
    <Col>
      <SpeciesTable species={species} />
    </Col>
  </Row>
</Container>
```

### V2 UI Structure (`lib/gallformers_web/live/genus_live.ex` lines 89-157)

```heex
<div class="mx-auto max-w-7xl">
  <div class="mb-6">
    <div class="flex items-center justify-between mb-2">
      <h1 class="text-2xl font-bold text-gf-maroon">
        Genus <em>{format_with_description(@genus.name, @genus.description)}</em>
      </h1>
    </div>
    <div class="text-gray-700">
      <span class="font-semibold">Family:</span>
      <.link href={"/family/#{@family.id}"}><em>{@family.name}</em></.link>
      <span :if={@family.description}>({@family.description})</span>
    </div>
  </div>
  <div class="mt-6">
    <h2>Species ({length(@species)})</h2>
    <table class="gf-table">...</table>
  </div>
</div>
```

### Key UI Differences

1. **Layout**: V1 uses Bootstrap Container/Row/Col; V2 uses Tailwind with max-w-7xl
2. **Styling**: V1 uses Bootstrap classes; V2 uses Tailwind + custom `.gf-table`
3. **Title Placement**: Both show "Genus" before italicized name
4. **Species Count**: V2 shows count in section heading; V1 does not
5. **Table Features**: V1 has sortable DataTable with Taxon Type column; V2 has simple HTML table

---

## Business Logic Analysis

### V1 Data Assembly (`v1/pages/genus/[id]/index.tsx` lines 69-90)

```typescript
export const getStaticProps: GetStaticProps = async (context) => {
  const genus = await getStaticPropsWithContext(context, taxonomyEntryById, 'genus');
  return {
    props: {
      key: genus[0].id ?? -1,
      genus: genus,
      species: await getStaticPropsWithContext(
        context,
        getAllSpeciesForSectionOrGenus,
        'species for genus',
        false,
        true,
      ),
    },
    revalidate: 1,
  };
};
```

### V2 Data Assembly (`lib/gallformers_web/live/genus_live.ex` lines 58-78)

```elixir
defp assign_genus_data(socket, genus, genus_id) do
  family = if genus.parent_id, do: Taxonomy.get_taxonomy(genus.parent_id), else: nil
  species_ids = Taxonomy.get_species_ids_for_genus(genus_id)
  species =
    if species_ids == [], do: [], else: Gallformers.Species.list_species_by_ids(species_ids)
  assign(socket,
    page_title: "Genus #{genus.name}",
    page_description: "#{genus.name} - A taxonomic genus documented...",
    genus: genus,
    family: family,
    species: species,
    error: nil
  )
end
```

### Key Logic Differences

1. **Fetching Strategy**: V1 builds at compile time (SSG); V2 fetches at request time
2. **Parent Lookup**: V1 uses `O.Option<TaxonomyEntry>` nested in genus; V2 makes separate call via `parent_id`
3. **Species Query**: V1 queries directly by taxonomy_id; V2 gets IDs first, then bulk fetches
4. **Type Validation**: V2 explicitly validates `type: "genus"` in pattern match; V1 trusts the data

---

## Data Layer Analysis

### V1 Query (`v1/libs/db/taxonomy.ts` lines 435-447)

```typescript
export const getAllSpeciesForSectionOrGenus = (id: number): TE.TaskEither<Error, SimpleSpecies[]> => {
  const sectionSpecies = () =>
    db.speciestaxonomy.findMany({
      where: { taxonomy_id: id },
      include: { species: true },
      orderBy: { species: { name: 'asc' } },
    });
  return pipe(
    TE.tryCatch(sectionSpecies, handleError),
    TE.map((s) => s.map((sp) => ({ ...sp.species }) as SimpleSpecies)),
  );
};
```

### V2 Query (`lib/gallformers/taxonomy.ex` lines 444-451)

```elixir
def get_species_ids_for_genus(genus_id) do
  from(st in "speciestaxonomy",
    where: st.taxonomy_id == ^genus_id,
    select: st.species_id
  )
  |> Repo.all()
end
```

Combined with (`lib/gallformers/species.ex` lines 205-216):

```elixir
def list_species_by_ids(species_ids) when is_list(species_ids) do
  from(s in Species,
    where: s.id in ^species_ids,
    order_by: s.name,
    select: %{id: s.id, name: s.name, taxoncode: s.taxoncode}
  )
  |> Repo.all()
end
```

### Key Data Layer Differences

1. **Query Approach**: V1 uses Prisma join; V2 uses two-step (IDs then bulk fetch)
2. **Return Type**: V1 returns `SimpleSpecies[]`; V2 returns `[%{id, name, taxoncode}]` maps
3. **Error Handling**: V1 uses fp-ts TaskEither; V2 uses Elixir pattern matching

---

## Parity Issues

### Missing in V2

1. **Taxon Type Column**: V1 shows "Gall Former" or "Host" in species table; V2 only shows name
2. **Table Sorting**: V1 DataTable is sortable; V2 table is static
3. **Striped Rows**: V1 uses `striped` prop; V2 may need `.gf-table` to include striping

### V2 Enhancements

1. **Species Count**: V2 shows count in "Species (N)" heading
2. **Empty State**: V2 shows "No species found for this genus." message
3. **Type Validation**: V2 validates the taxonomy is actually a genus type
4. **SEO Metadata**: V2 sets `page_noindex`, `page_url`, `page_json_ld` assigns
5. **Richer Description**: V2 meta description includes species count

---

## Recommendations

### High Priority

1. **Add Taxon Type Column**: V2 should display whether each species is a "Gall Former" or "Host" to match V1 parity
   - File: `lib/gallformers_web/live/genus_live.ex` lines 125-141
   - Change: Add second column showing `if species.taxoncode == "gall", do: "Gall Former", else: "Host"`

2. **Add Table Sorting**: Consider using AlpineJS or a JavaScript hook for client-side sorting
   - Currently at: `lib/gallformers_web/live/genus_live.ex` line 124
   - Data is already sorted by name in `list_species_by_ids`

### Low Priority

3. **Striped Table Rows**: Verify `.gf-table` CSS includes striping for readability

4. **Consider Caching**: V1 uses ISR with `revalidate: 1`; V2 could benefit from ETS caching for frequently accessed genera

---

## Summary

The V2 implementation successfully replicates the core functionality of the V1 Genus Detail page. The main structural elements (genus info, family link, species list) are all present. V2 improves on V1 with better empty states, species count display, and explicit type validation.

The primary gap is the missing "Taxon Type" column in the species table, which would help users distinguish between gall-formers and hosts at a glance. This is a minor enhancement that could be added to achieve full feature parity.
