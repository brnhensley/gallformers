# Source Detail Page - V1 vs V2 Comparison

**V1 Route**: `/source/[id]`
**V2 Route**: `/source/:id`

## Summary

Displays detailed information about a scientific source/reference. Shows title, author, publication year, citation, link, license information, data completeness status, and lists all species connected to this source.

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Route** | `/source/[id]` | `/source/:id` | Equivalent | Same URL structure |
| **Page Title** | `source.title` | `source.title` | Equivalent | Both use source title |
| **Meta Description** | `source.citation` | Custom text with title/author | V2 Enhanced | V2 adds "A source referenced on Gallformers" |
| **Data Rendering** | SSG with `getStaticProps` | LiveView mount | Different approach | Both prerender data |
| **Fallback Loading** | "Loading..." text | Error message | V2 Enhanced | V2 shows error state for invalid IDs |
| **Edit Button** | Emoji link for logged-in users | Pencil icon for logged-in users | V2 Enhanced | V2 uses Phosphor icon |
| **Data Complete Badge** | Tooltip with emoji button | Badge with tooltip | V2 Enhanced | V2 uses text badge ("Complete"/"In Progress") |
| **Source Link** | Plain anchor tag | `.link` component with `noopener noreferrer` | V2 Enhanced | V2 adds security attributes |
| **Authors Display** | Simple text | Text with "Not specified" fallback | V2 Enhanced | V2 handles null gracefully |
| **License Display** | Plain text or link | Plain text or link with fallback | Equivalent | Both support licenselink |
| **Publication Year** | Simple text | Text with "Not specified" fallback | V2 Enhanced | V2 handles null gracefully |
| **Citation Display** | Italic text | Italic text with conditional render | Equivalent | Both render citation in italics |
| **Species Table** | react-data-table-component | Native HTML table with gf-table styles | Different approach | Both functional |
| **Species Sorting** | Client-side (DataTable sortable) | Server-side sort by name | V2 Simplified | V1 allows column sorting |
| **Species Links** | Link to `/gall/[id]` or `/host/[id]` | Link to `/gall/:id` or `/host/:id` | Equivalent | Both route based on taxoncode |
| **Species Type Display** | "Gall Former" / "Host" | "Gall" / "Host" | V2 Simplified | V2 uses shorter labels |
| **Pagination** | DataTable built-in | Custom pagination component | V2 Enhanced | V2 shows "X of Y results" |
| **Images** | Not displayed | Image gallery component | V2 Enhanced | V2 shows source images |
| **Layout** | Bootstrap rows/columns | Tailwind grid | Different approach | Both responsive |
| **SEO** | `<Head>` with title/description | LiveView assigns for meta | Equivalent | Both set meta tags |

---

## UI Layer Analysis

### V1 Implementation
**File**: `v1/pages/source/[id]/index.tsx` (lines 1-111)

```tsx
// Header with title and edit button
<Row className="pb-4">
    <Col>
        <h2>{source.title}</h2>
        <span><a href={source.link}>{source.link}</a></span>
    </Col>
    <Col xs={2}>
        <Edit id={source.id} type="source" />
        <OverlayTrigger placement="left" overlay={<Tooltip>...</Tooltip>}>
            <Button variant="outline-light">{source.datacomplete ? '100' : '?'}</Button>
        </OverlayTrigger>
    </Col>
</Row>

// Authors and License row
<Row className="pb-1">
    <Col><strong>Authors:</strong> {source.author}</Col>
    <Col><strong>License:</strong> {licenseLink || source.license}</Col>
</Row>

// Publication year
<Row className="pb-4">
    <Col><strong>Publication Year:</strong> {source.pubyear}</Col>
</Row>

// Citation
<Row className="pb-4">
    <Col><strong>Citation (MLA Form):</strong> <i>{source.citation}</i></Col>
</Row>

// Connected species table
<Row>
    <Col>
        <strong>Connected Species:</strong>
        <SpeciesTable species={source.species} />
    </Col>
</Row>
```

**Components Used**:
- `Edit` (`v1/components/edit.tsx`, lines 1-25): Shows pencil emoji link to admin for authenticated users
- `SpeciesTable` (`v1/components/speciesTable.tsx`, lines 1-61): Wrapper around react-data-table-component
- `DataTable` (`v1/components/DataTable.tsx`, lines 1-12): Wrapper for react-data-table-component with mount check

### V2 Implementation
**File**: `lib/gallformers_web/live/source_live.ex` (lines 129-268)

```elixir
# Header with title and edit button
<div class="flex items-start justify-between gap-4 mb-2">
  <div class="flex items-center gap-2">
    <h1 class="text-2xl font-bold text-gf-maroon">{@source.title}</h1>
    <.link :if={@current_user} href={~p"/admin/sources/#{@source.id}"} ...>
      <.icon name="ph-pencil-simple" class="h-5 w-5" />
    </.link>
  </div>
  <.data_complete_badge complete={@source.datacomplete} ... />
</div>

# Source link
<.link href={@source.link} target="_blank" rel="noopener noreferrer" ...>
  {@source.link}
</.link>

# Grid layout for info and images
<div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
  # Source info (2 columns)
  <div class="lg:col-span-2 space-y-4">
    # Authors, License, Publication Year, Citation
  </div>

  # Images column (1 column)
  <div class="lg:col-span-1">
    <.image_gallery images={@images} id="source-images" />
  </div>
</div>

# Connected species table with pagination
<table class="gf-table gf-table-compact">
  <thead><tr><th>Species Name</th><th>Type</th></tr></thead>
  <tbody>
    <tr :for={species <- paginated_species(@species, @current_page, @page_size)}>
      <td><.link href={...}><em>{species.name}</em></.link></td>
      <td>{if species.taxoncode == "gall", do: "Gall", else: "Host"}</td>
    </tr>
  </tbody>
</table>
<.pagination :if={total_pages(@species, @page_size) > 1} ... />
```

**Components Used**:
- `.data_complete_badge` (`lib/gallformers_web/components/core_components.ex`, line 550): Text badge with tooltip
- `.image_gallery` (`lib/gallformers_web/components/data_display_components.ex`, line 33): Interactive gallery with lightbox
- `.pagination` (`lib/gallformers_web/components/ui_components.ex`, line 240): Pagination with item counts
- `.icon` (`lib/gallformers_web/components/core_components.ex`): Phosphor icon rendering

---

## Business Logic Analysis

### V1 Implementation
**File**: `v1/pages/source/[id]/index.tsx` (lines 91-107)

Data fetching uses Next.js Static Generation (SSG):

```typescript
export const getStaticProps: GetStaticProps = async (context) => {
    const source = await getStaticPropsWithContext(context, sourceById, 'source');
    if (!source[0]) throw new Error('404');
    return {
        props: { key: source[0]?.id, source: source[0] },
        revalidate: 1,  // ISR revalidation
    };
};

export const getStaticPaths: GetStaticPaths = async () =>
    getStaticPathsFromIds(allSourceIds);
```

- Pre-generates pages at build time
- Uses ISR with 1-second revalidation
- Returns 404 for missing sources

### V2 Implementation
**File**: `lib/gallformers_web/live/source_live.ex` (lines 14-78)

Data fetching in LiveView mount:

```elixir
def mount(%{"id" => id}, _session, socket) do
  case Integer.parse(id) do
    {source_id, ""} -> load_source(socket, source_id)
    _ -> {:ok, assign(socket, error: "Invalid source ID", ...)}
  end
end

defp load_source(socket, source_id) do
  case Sources.get_source(source_id) do
    nil -> {:ok, assign(socket, error: "Source not found", ...)}
    source ->
      species = Sources.get_species_for_source(source_id) |> Enum.sort_by(& &1.name)
      images = Images.list_images_for_source(source_id) |> format_images()
      {:ok, assign(socket, source: source, species: species, images: images, ...)}
  end
end
```

- Server-side data loading on every request
- Validates ID format before database lookup
- Loads source, species, and images in mount
- Client-side pagination (20 items per page)

---

## Data Layer Analysis

### V1 Implementation
**File**: `v1/libs/db/source.ts` (lines 30-61)

```typescript
export const sourceById = (id: number): TaskEither<Error, SourceWithSpeciesApi[]> => {
    const sources = () =>
        db.source.findMany({
            include: {
                speciessource: {
                    include: {
                        species: {
                            select: { id: true, name: true, taxoncode: true },
                        },
                    },
                },
            },
            where: { id: { equals: id } },
        });

    return pipe(
        TE.tryCatch(sources, handleError),
        TE.map((sources) =>
            sources.map((s) => ({
                ...s,
                species: s.speciessource.map((speciesSource) => ({
                    ...speciesSource.species,
                    taxoncode: taxonCodeAsStringToValue(speciesSource.species.taxoncode),
                })),
            })),
        ),
    );
};
```

**Type Definition** (`v1/libs/api/apitypes.ts`, lines 170-192):
```typescript
export type SourceApi = {
    id: number;
    title: string;
    author: string;
    pubyear: string;
    link: string;
    citation: string;
    datacomplete: boolean;
    license: string;
    licenselink: string;
};

export type SourceWithSpeciesApi = SourceApi & {
    species: SimpleSpecies[];
};
```

**Prisma Schema** (`v1/prisma/schema.prisma`, lines 247-259):
```prisma
model source {
  id            Int             @id @default(autoincrement())
  title         String          @unique
  author        String
  pubyear       String
  link          String
  citation      String
  datacomplete  Boolean         @default(false)
  license       String
  licenselink   String
  image         image[]
  speciessource speciessource[]
}
```

### V2 Implementation

**Context** (`lib/gallformers/sources.ex`, lines 49-158):

```elixir
@spec get_source(integer()) :: Source.t() | nil
def get_source(id) do
  Repo.get(Source, id)
end

@spec get_species_for_source(integer()) :: [map()]
def get_species_for_source(source_id) do
  from(ss in SpeciesSource,
    join: sp in Species,
    on: ss.species_id == sp.id,
    where: ss.source_id == ^source_id,
    order_by: sp.name,
    select: %{
      id: sp.id,
      name: sp.name,
      taxoncode: sp.taxoncode,
      description: ss.description,
      externallink: ss.externallink
    }
  )
  |> Repo.all()
end
```

**Schema** (`lib/gallformers/sources/source.ex`, lines 1-103):

```elixir
@required_fields [:title, :author, :pubyear, :link, :citation, :license]

schema "source" do
  field :title, :string
  field :author, :string
  field :pubyear, :string
  field :link, :string
  field :citation, :string
  field :datacomplete, :boolean, default: false
  field :license, :string
  field :licenselink, :string

  has_many :images, Gallformers.Species.Image
  has_many :species_sources, Gallformers.Species.SpeciesSource
end
```

**Images for Source** (`lib/gallformers/images.ex`, lines 400-414):

```elixir
@spec list_images_for_source(integer()) :: [ImageSchema.t()]
def list_images_for_source(source_id) do
  from(i in ImageSchema,
    join: src in assoc(i, :source),
    left_join: sp in Species,
    on: i.species_id == sp.id,
    where: i.source_id == ^source_id,
    order_by: [asc: sp.name, asc: i.id],
    preload: [source: src]
  )
  |> Repo.all()
end
```

---

## Key Differences

### V2 Enhancements
1. **Image Gallery**: V2 displays source-associated images; V1 does not
2. **Error Handling**: V2 shows user-friendly errors for invalid IDs
3. **Data Complete Badge**: V2 uses text badge vs V1's emoji button
4. **Null Handling**: V2 shows "Not specified" for missing fields
5. **Security**: V2 adds `rel="noopener noreferrer"` to external links
6. **SEO**: V2 generates page image from source images

### V1 Features Not in V2
1. **Client-side Sorting**: V1's DataTable allows sorting by name/type columns
2. **Type Label**: V1 uses "Gall Former" vs V2's shorter "Gall"

### Data Query Differences
- V1: Single Prisma query with nested includes
- V2: Separate queries for source, species, and images
- Both: Return same data structure (source with connected species)

---

## Recommendations

1. **Consider adding column sorting** to V2 species table for parity with V1
2. **Consistent type labels**: Decide between "Gall Former" (V1) and "Gall" (V2)
3. **Query optimization**: V2 could potentially combine species/images into single query
4. **Empty state**: Both handle empty species list, but V2's message is more polished

---

## File References

### V1 Files
- Page: `v1/pages/source/[id]/index.tsx`
- Data layer: `v1/libs/db/source.ts`
- Types: `v1/libs/api/apitypes.ts` (lines 170-192)
- Schema: `v1/prisma/schema.prisma` (lines 247-259)
- Components:
  - `v1/components/edit.tsx`
  - `v1/components/speciesTable.tsx`
  - `v1/components/DataTable.tsx`

### V2 Files
- LiveView: `lib/gallformers_web/live/source_live.ex`
- Context: `lib/gallformers/sources.ex`
- Schema: `lib/gallformers/sources/source.ex`
- Images: `lib/gallformers/images.ex` (lines 400-414)
- Components:
  - `lib/gallformers_web/components/core_components.ex` (data_complete_badge, icon)
  - `lib/gallformers_web/components/data_display_components.ex` (image_gallery)
  - `lib/gallformers_web/components/ui_components.ex` (pagination)
- Router: `lib/gallformers_web/router.ex` (line 148)
