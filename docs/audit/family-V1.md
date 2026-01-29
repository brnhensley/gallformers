# Family Detail Page Comparison: V1 vs V2

**Route**: `/family/:id`
**V1 File**: `v1/pages/family/[id]/index.tsx` (lines 1-113)
**V2 File**: `lib/gallformers_web/live/family_live.ex` (lines 1-208)

## Summary

Displays information about a taxonomic family with its genera and species in an expandable tree view. Links to individual genus and species detail pages. Both implementations are functionally equivalent with some UI/UX differences.

---

## Comparison Table

| Aspect | V1 (Next.js) | V2 (Phoenix LiveView) | Status | Notes |
|--------|--------------|----------------------|--------|-------|
| **Rendering** | Static (SSG with ISR) | Server-side LiveView | Equivalent | V1 uses `getStaticProps` with `revalidate: 1`; V2 renders on mount |
| **Tree Component** | `react-simple-tree-menu` library | Custom accordion implementation | Equivalent | V2 uses native accordion with `MapSet` for tracking expanded |
| **Initial Expansion** | Family node auto-expanded | All collapsed by default | Gap | V1 passes `initialOpenNodes={[fam.id.toString()]}` |
| **Admin Edit Link** | Conditional via `<Edit>` component | Not present on public page | Gap | V1 shows edit pencil for logged-in admins |
| **Header Display** | `{name} - {description}` format | Same format | Equivalent | Both show family name with description |
| **Genera Sorting** | Alphabetical (`localeCompare`) | Alphabetical (`order_by: t.name`) | Equivalent | |
| **Species Sorting** | Alphabetical (`localeCompare`) | Alphabetical (`order_by: s.name`) | Equivalent | |
| **Species Count** | Not shown | Shown in genus row | V2 Better | V2 displays `({length(genus.children)} species)` |
| **Genus Labels** | `formatWithDescription(name, description)` | `{genus.name} - {genus.description}` | Equivalent | |
| **Species Links** | Routes to `/gall/:id` or `/host/:id` based on taxoncode | Same routing logic | Equivalent | Both check `taxoncode` for gall vs host |
| **Error Handling** | Next.js `ErrorPage` with 404 | Error message in red div | Equivalent | |
| **SEO Metadata** | `<Head>` with title and meta description | `page_title`, `page_description` assigns | Equivalent | |
| **Fallback State** | "Loading..." during SSG fallback | N/A (server-rendered) | N/A | |
| **Empty State** | Not explicitly handled | "No genera or species found" message | V2 Better | |
| **Chevron Animation** | Via CSS from tree library | `transition-transform rotate-180` | Equivalent | |
| **Tree Click Handler** | Navigate via `router.push(item.url)` | Standard `<.link href={...}>` | Equivalent | |
| **Type Validation** | Relies on `taxonomyTreeForId` filtering | Explicit `if family.type != "family"` check | V2 More Explicit | |

---

## UI Layer Analysis

### V1 Implementation (lines 42-64)

```tsx
<Container className="pt-2" fluid>
  <Card>
    <Card.Header>
      <Edit id={fam.id} type="taxonomy" />  // Admin edit link (conditional)
      <h1>{fam.name} - {fam.description}</h1>
    </Card.Header>
    <Card.Body>
      <TreeMenu data={tree} onClickItem={handleClick} initialOpenNodes={[fam.id.toString()]} />
    </Card.Body>
  </Card>
</Container>
```

Key UI elements:
- Uses React Bootstrap `Container`, `Card` components
- Includes `<Edit>` component for admin users (shows pencil icon, links to `/admin/taxonomy?id=X`)
- Uses `react-simple-tree-menu` for expandable tree with keyboard navigation
- Family node automatically expanded on load

### V2 Implementation (lines 130-206)

```elixir
<div class="mx-auto max-w-7xl">
  <div class="bg-white rounded border border-gray-200 shadow-sm">
    <div class="px-4 py-3 border-b border-gray-200">
      <h1 class="text-2xl font-bold text-gf-maroon">
        {@family.name}
        <span :if={@family.description} class="text-lg font-normal text-gray-600">
          - {@family.description}
        </span>
      </h1>
    </div>
    <div class="p-4">
      <div class="space-y-2">
        <div :for={genus <- @tree_data} class="border rounded">
          <button phx-click="toggle_genus" phx-value-id={genus.id} ...>
            <em class="font-medium">{genus.name}</em>
            <span :if={genus.description}> - {genus.description}</span>
            <span class="text-sm text-gray-500 ml-2">({length(genus.children)} species)</span>
            <svg class={"... #{if MapSet.member?(@expanded_keys, genus.id), do: "rotate-180"}"}>...</svg>
          </button>
          <div :if={MapSet.member?(@expanded_keys, genus.id)} class="border-t bg-white">
            <ul class="divide-y">
              <li :for={species <- genus.children} class="px-6 py-2 hover:bg-gray-50">
                <.link href={species.url} class="hover:underline"><em>{species.name}</em></.link>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

Key UI elements:
- Custom Tailwind CSS styling (no external tree library)
- Uses `MapSet` to track expanded genera (lines 78, 115-127)
- Custom accordion with chevron rotation on expand
- Shows species count per genus
- No admin edit link on public page

---

## Business Logic Analysis

### V1 Tree Building (lines 67-85)

```typescript
const toTreeNodeInArray = (tree: TaxonomyTree): TreeNodeInArray[] => [
  {
    key: tree.id.toString(),
    label: tree.name,
    nodes: tree.taxonomy
      .sort((a, b) => a.name.localeCompare(b.name))  // Sort genera
      .map((tt) => ({
        key: tt.id.toString(),
        label: formatWithDescription(tt.name, tt.description),
        nodes: tt.speciestaxonomy
          .sort((a, b) => a.species.name.localeCompare(b.species.name))  // Sort species
          .map((st) => ({
            key: st.species.id.toString(),
            label: st.species.name,
            url: `/${st.species.taxoncode === TaxonCodeValues.GALL ? 'gall' : 'host'}/${st.species.id}`,
          })),
      })),
  },
];
```

### V2 Tree Building (lines 85-112)

```elixir
defp build_tree_data(genera) do
  Enum.map(genera, fn genus ->
    species_ids = Taxonomy.get_species_ids_for_genus(genus.id)
    species =
      case species_ids do
        [] -> []
        ids -> get_species_info(ids)
      end
    %{
      id: genus.id,
      name: genus.name,
      description: genus.description,
      type: :genus,
      children: species
    }
  end)
end

defp get_species_info(species_ids) do
  Gallformers.Species.list_species_by_ids(species_ids)
  |> Enum.map(fn s ->
    url = if s.taxoncode == "gall", do: "/gall/#{s.id}", else: "/host/#{s.id}"
    Map.put(s, :url, url)
  end)
end
```

**Key Difference**: V1 receives the complete tree from `taxonomyTreeForId` in a single Prisma query with nested includes. V2 makes separate queries: first `get_children` for genera, then `get_species_ids_for_genus` + `list_species_by_ids` for each genus.

---

## Data Layer Analysis

### V1 Data Fetching (`v1/libs/db/taxonomy.ts`, lines 143-177)

```typescript
export const taxonomyTreeForId = (id: number): TE.TaskEither<Error, O.Option<TaxonomyTree>> => {
  const sps = () =>
    db.taxonomy.findFirst({
      include: {
        parent: true,
        speciestaxonomy: {
          include: { species: true },
        },
        taxonomy: {  // Child genera
          include: {
            speciestaxonomy: {  // Species under each genus
              include: { species: true },
            },
            taxonomy: true,
            taxonomyalias: true,
            taxonomytaxonomy: true,
          },
        },
        taxonomyalias: true,
      },
      where: { id: id },
    });
  // ...
};
```

**Query Pattern**: Single deeply-nested Prisma query that fetches family -> genera -> species in one round trip.

### V2 Data Fetching (`lib/gallformers/taxonomy.ex`)

```elixir
# Line 99-106: Get children (genera) of a taxonomy
def get_children(taxonomy_id) do
  from(t in Taxonomy, where: t.parent_id == ^taxonomy_id, order_by: t.name)
  |> Repo.all()
end

# Line 444-451: Get species IDs for a genus
def get_species_ids_for_genus(genus_id) do
  from(st in "speciestaxonomy", where: st.taxonomy_id == ^genus_id, select: st.species_id)
  |> Repo.all()
end
```

And from `lib/gallformers/species.ex` (lines 205-215):

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

**Query Pattern**: Multiple queries - 1 for genera, then N queries for species (one per genus). This could be optimized with a single query joining family -> genera -> species.

---

## Admin Integration

### V1 (`v1/components/edit.tsx`, lines 1-26)

```tsx
const Edit = ({ id, type }: Props): JSX.Element => {
  const { data: session } = useSession();
  return (
    <>
      {mounted && session && (
        <Link href={`/admin/${type}?id=${id}`} className="p-1">✎</Link>
      )}
    </>
  );
};
```

Conditionally renders edit link for authenticated users.

### V2 Admin (`lib/gallformers_web/live/admin/taxonomy_live/form.ex`, lines 126-129)

```elixir
defp taxonomy_public_url(%{type: "family", id: id}), do: ~p"/family/#{id}"
defp taxonomy_public_url(%{type: "genus", id: id}), do: ~p"/genus/#{id}"
defp taxonomy_public_url(%{type: "section", id: id}), do: ~p"/section/#{id}"
```

V2 has admin pages at `/admin/taxonomy/:id` but the public family page (`family_live.ex`) does not include a link to admin for logged-in users.

---

## Gaps and Recommendations

### 1. Missing Admin Edit Link (Medium Priority)
**Gap**: V2 public family page does not show an edit link for authenticated admin users.

**Recommendation**: Add conditional admin edit button similar to other detail pages:
```elixir
<.edit_button
  :if={@current_user && @current_user.role in [:admin, :curator]}
  href={~p"/admin/taxonomy/#{@family.id}"}
/>
```

### 2. Initial Expansion State (Low Priority)
**Gap**: V2 starts with all genera collapsed; V1 has the family node expanded by default.

**Recommendation**: Consider initializing `expanded_keys` with a default expanded genus or all genera if the count is small:
```elixir
# In load_family/2, instead of MapSet.new():
expanded_keys: if length(genera) <= 3, do: MapSet.new(Enum.map(genera, & &1.id)), else: MapSet.new()
```

### 3. Query Optimization (Medium Priority)
**Gap**: V2 makes N+1 queries (1 for genera, N for species per genus).

**Recommendation**: Optimize with a single query that joins through the taxonomy hierarchy:
```elixir
def get_family_tree(family_id) do
  from(g in Taxonomy,
    left_join: st in "speciestaxonomy", on: st.taxonomy_id == g.id,
    left_join: s in Species, on: st.species_id == s.id,
    where: g.parent_id == ^family_id,
    order_by: [g.name, s.name],
    select: %{
      genus_id: g.id,
      genus_name: g.name,
      genus_description: g.description,
      species_id: s.id,
      species_name: s.name,
      taxoncode: s.taxoncode
    }
  )
  |> Repo.all()
  |> Enum.group_by(&{&1.genus_id, &1.genus_name, &1.genus_description})
  # ... transform to tree structure
end
```

### 4. formatWithDescription Utility (Low Priority)
**Gap**: V1 uses a shared `formatWithDescription` helper that handles various description formats (strings, arrays). V2 handles inline.

**Recommendation**: Consider extracting a shared helper if this pattern is used in multiple places.

---

## File References

| Component | V1 Location | V2 Location |
|-----------|-------------|-------------|
| Main Page | `v1/pages/family/[id]/index.tsx:1-113` | `lib/gallformers_web/live/family_live.ex:1-208` |
| Tree Building | `v1/pages/family/[id]/index.tsx:67-85` | `lib/gallformers_web/live/family_live.ex:85-112` |
| Data Access | `v1/libs/db/taxonomy.ts:143-177` | `lib/gallformers/taxonomy.ex:99-106, 444-451` |
| Species Lookup | `v1/libs/db/taxonomy.ts` (via Prisma include) | `lib/gallformers/species.ex:205-215` |
| Admin Edit | `v1/components/edit.tsx:1-26` | `lib/gallformers_web/live/admin/taxonomy_live/form.ex:1-244` |
| Error Handling | `v1/pages/family/[id]/index.tsx:29-31` | `lib/gallformers_web/live/family_live.ex:33-45` |
| Router | `v1/pages/family/[id]/index.tsx` (file-based) | `lib/gallformers_web/router.ex:146` |

---

## Status Summary

| Category | Status |
|----------|--------|
| Core Functionality | Complete |
| UI Parity | 95% (minor differences in tree behavior) |
| Admin Integration | Gap (no edit link on public page) |
| Performance | Needs optimization (N+1 queries) |
| Error Handling | Complete |
| SEO | Complete |
