# Host Detail Page - V1 vs V2 Comparison

**Route**: `/host/[id]`

## File Locations

| Layer | V1 File | V2 File |
|-------|---------|---------|
| Page/LiveView | `/Users/jeff/dev/gallformers/v1/pages/host/[id]/index.tsx` | `/Users/jeff/dev/gallformers/lib/gallformers_web/live/host_live.ex` |
| Business Logic | `/Users/jeff/dev/gallformers/v1/libs/db/host.ts` | `/Users/jeff/dev/gallformers/lib/gallformers/hosts.ex` |
| Taxonomy Logic | `/Users/jeff/dev/gallformers/v1/libs/db/taxonomy.ts` | `/Users/jeff/dev/gallformers/lib/gallformers/taxonomy.ex` |
| Images Component | `/Users/jeff/dev/gallformers/v1/components/images.tsx` | `/Users/jeff/dev/gallformers/lib/gallformers_web/components/data_display_components.ex` (`.image_gallery`) |
| Range Map | `/Users/jeff/dev/gallformers/v1/components/rangemap.tsx` | `/Users/jeff/dev/gallformers/lib/gallformers_web/components/data_display_components.ex` (`.range_map`) |
| Source List | `/Users/jeff/dev/gallformers/v1/components/sourcelist.tsx` | Inline in `host_live.ex` |
| See Also | `/Users/jeff/dev/gallformers/v1/components/seealso.tsx` | `/Users/jeff/dev/gallformers/lib/gallformers_web/components/ui_components.ex` (`.see_also`) |
| Synonymy/Aliases | `/Users/jeff/dev/gallformers/v1/components/speciesSynonymy.tsx` | Inline in `host_live.ex` |

---

## Comparison Table

| Aspect | V1 Implementation | V2 Implementation | Status | Notes |
|--------|-------------------|-------------------|--------|-------|
| **Rendering** | Next.js SSG with `getStaticProps`/`getStaticPaths` (line 210-232) | Phoenix LiveView with `mount/3` (line 18-106) | **Parity** | V2 loads synchronously on mount |
| **SEO** | `<Head>` component with title and meta description (line 71-73) | `page_title`, `page_description`, JSON-LD structured data (line 68-120) | **V2 Better** | V2 includes structured data for search engines |
| **Taxonomy Display** | Family, Section (optional), Genus with links (line 110-136) | Same structure with links (line 291-317) | **Parity** | Both link to `/family/`, `/section/`, `/genus/` |
| **Data Complete Badge** | Emoji-based (💯/❓) with Bootstrap tooltip (line 93-105) | Uses `.data_complete_badge` component (line 284-288) | **Parity** | V2 has configurable tooltips |
| **Abundance** | fp-ts Option handling (line 140-146) | Simple conditional display (line 319) | **Parity** | V2 cleaner without fp-ts |
| **Aliases/Synonymy** | `<SpeciesSynonymy>` component with DataTable expandable view | Inline display with comma separation (line 321-330) | **V1 Better** | V1 has expandable table showing alias details and notes |
| **Galls Table** | react-data-table-component with pagination (line 156-169) | Native HTML table with pagination (line 334-439) | **V2 Better** | V2 has sortable columns (name, datacomplete) |
| **Galls Sorting** | Default sort by name (line 66, 165) | Sortable by name or datacomplete with direction toggle (line 167-184) | **V2 Better** | V2 supports column click to toggle sort |
| **Image Gallery** | `<Images>` component with ImageCarousel, modal for details (line 174-178) | `.image_gallery` component with lightbox (line 444-450) | **Parity** | Both have carousel, attribution, lightbox |
| **Range Map** | react-simple-maps with react-tooltip (line 180-184) | D3.js-based with JS hook (`RangeMap`) (line 454) | **Parity** | Both show US/Canada with tooltips |
| **Source List** | `<SourceList>` with DataTable, selectable row, markdown rendering (line 188-195) | Inline card layout with click-to-expand modal (line 481-553) | **Different** | V1 has source selection changing main description; V2 shows all inline with modal for full text |
| **Gallformers Notes Alert** | Alert banner with "Show notes" button (line 128-144 in sourcelist.tsx) | Blue-bordered info banner (line 461-479) | **Parity** | Both highlight Gallformers Notes (source_id=58) |
| **See Also Links** | `<SeeAlso>` with iNat, BugGuide, Google Scholar, BHL logos (line 199-202) | `.see_also` component with same links (line 555) | **V2 Better** | V2 handles hosts (3 links) vs galls (4 links) appropriately |
| **Admin Edit Links** | `<Edit>` component with pencil icon (line 92) | Conditional pencil icon when `@current_user` (line 275-282) | **Parity** | Both show only for authenticated users |
| **Loading State** | `router.isFallback` shows "Loading..." (line 60-63) | No explicit loading state (mount is synchronous) | **N/A** | LiveView handles differently |
| **Error Handling** | Returns 404 via `notFound: true` (line 228) | Assigns `:error` with message display (line 23-35, 258-259) | **Parity** | Both handle invalid IDs gracefully |
| **ID Link** | Host name links to ID tool with pre-filled host filter (line 81-88) | Host name links to ID tool with `h=` param (line 268-273) | **Parity** | Both link to filtered ID search |
| **Pagination** | DataTable built-in pagination (line 167) | Custom pagination with Previous/Next (line 405-434) | **Parity** | V2 shows item range and page count |
| **Data Complete Column** | Not shown in galls table | Shows check/X with sortable header (line 382-402) | **V2 Better** | V2 shows datacomplete status per gall |
| **Gall Edit Links** | Edit button per gall row (line 35-36) | Pencil icon linking to `/admin/gallhost` (line 393-401) | **V2 Better** | V2 links to gall-host mapping editor |
| **Source Modal** | Image Details modal only | Full source modal with font size controls (line 563-644) | **V2 Better** | V2 has accessible reading with A+/A- |
| **Font Size Controls** | Not available | Modal has increase/decrease font size (line 198-214, 574-592) | **V2 Better** | Accessibility improvement |

---

## UI Layer Analysis

### V1 (Next.js) - `/Users/jeff/dev/gallformers/v1/pages/host/[id]/index.tsx`

**Layout**: Two-column responsive grid using React Bootstrap
- Left column (sm:12, md:6, lg:8): Species details, taxonomy, galls table
- Right column (sm:12, md:6, lg:4): Image gallery, range map

**Key Components Used**:
- `<DataTable>` - react-data-table-component for galls list (line 156-169)
- `<Images>` - Custom carousel with lightbox (line 174-178)
- `<RangeMap>` - react-simple-maps choropleth (line 180-184)
- `<SourceList>` - Selectable source table with markdown rendering (line 188-195)
- `<SeeAlso>` - External reference links (line 199-202)
- `<SpeciesSynonymy>` - Alias display with expandable table (line 151)
- `<Edit>` - Admin edit button (line 92)

**Data Flow**:
1. `getStaticPaths` calls `allHostIds()` for ISR paths (line 232)
2. `getStaticProps` calls `hostById(id)` and `taxonomyForSpecies(id)` (line 212-216)
3. Source descriptions linked to glossary terms (line 215)
4. Props passed to component, sorted on render (line 66)

### V2 (Phoenix LiveView) - `/Users/jeff/dev/gallformers/lib/gallformers_web/live/host_live.ex`

**Layout**: CSS Grid (grid-cols-1, md:grid-cols-2, lg:grid-cols-3)
- Left area (lg:col-span-2): Species details, taxonomy, galls table
- Right area (lg:col-span-1): Image gallery, range map

**Key Components Used**:
- `.image_gallery` - JS hook-based carousel with lightbox (line 444-450)
- `.range_map` - D3.js hook-based map (line 454)
- `.data_complete_badge` - Tooltip-enhanced badge (line 284-288)
- `.see_also` - External links (line 555)
- `.modal` - Source detail with font controls (line 563-644)

**Data Flow**:
1. `mount/3` parses ID and calls `load_host/2` (line 18-36)
2. `load_host/2` makes separate calls:
   - `Hosts.get_host(id)` - Basic host data (line 40)
   - `Hosts.get_galls_for_host(id)` - Associated galls (line 56)
   - `Species.get_images_for_species(id)` - Images (line 57)
   - `Sources.get_sources_for_species(id)` - Sources (line 58)
   - `Species.get_aliases_for_species(id)` - Aliases (line 59)
   - `Taxonomy.get_taxonomy_for_species(id)` - Taxonomy (line 60)
   - `Hosts.get_places_for_host(id)` - Range (line 61)
3. Data assigned to socket, galls sorted alphabetically (line 56)

---

## Business Logic Analysis

### V1 Data Fetching - `/Users/jeff/dev/gallformers/v1/libs/db/host.ts`

**Main Function**: `hostById(id)` -> `getHosts([{ id: id }])` (line 253)

**Query Pattern** (line 197-246):
- Uses Prisma with nested includes
- Single query fetches all related data:
  - `abundance` - Abundance level
  - `host_galls.gallspecies` - Associated galls
  - `speciessource.source` - Source references
  - `image.source.speciessource` - Image with source
  - `aliasspecies.alias` - Aliases
  - `places.place` - Geographic range
- Taxonomy fetched separately via `taxonomyForSpecies(id)` (line 237-240)

**Adaptor Pattern** (line 74-106):
- Transforms DB response to `HostApi` type
- Flattens nested relationships
- Handles optional fields with fp-ts `Option`

### V2 Data Fetching - `/Users/jeff/dev/gallformers/lib/gallformers/hosts.ex`

**Main Function**: `get_host(id)` (line 68-83)

**Query Pattern**:
- Multiple separate queries (not a single join):
  - `get_host(id)` - Species record with abundance (line 68-83)
  - `get_galls_for_host(id)` - Joins host, species, gallspecies, gall (line 128-145)
  - `get_places_for_host(id)` - Joins speciesplace, place (line 168-176)
- Taxonomy via `Taxonomy.get_taxonomy_for_species(id)` (line 123-124)
- Images via `Species.get_images_for_species(id)`
- Sources via `Sources.get_sources_for_species(id)`

**Return Types**: Maps with selected fields, not full structs

---

## Data Layer Analysis

### V1 Taxonomy - `/Users/jeff/dev/gallformers/v1/libs/db/taxonomy.ts`

**Function**: `taxonomyForSpecies(id)` (line 294-341)

**Query Pattern**:
- Fetches `speciestaxonomy` with `taxonomy.parent` included
- Finds genus (type === 'genus') and its parent (family)
- Finds section if exists (type === 'section')
- Returns `FGS` (Family/Genus/Section) object with fp-ts Options

### V2 Taxonomy - `/Users/jeff/dev/gallformers/lib/gallformers/taxonomy.ex`

**Function**: `get_taxonomy_for_species(species_id)` (line 391-439)

**Query Pattern**:
- Two separate queries:
  1. Genus query with left join to family (line 394-407)
  2. Section query (line 410-420)
- Returns map with `genus`, `genus_id`, `section`, `section_id`, `family`, `family_id`
- Handles missing section gracefully

---

## Component Deep Dive

### Image Gallery

**V1** (`/Users/jeff/dev/gallformers/v1/components/images.tsx`):
- Uses `next/image` for optimization
- Custom `ImageCarousel` component
- Modal for image details (source, license, attribution, creator, uploader)
- Copyright popover
- Admin edit button
- No-image fallback with different images for gall/host

**V2** (`/Users/jeff/dev/gallformers/lib/gallformers_web/components/data_display_components.ex:33-340`):
- Uses `phx-hook="ImageGallery"` JS hook
- Prev/Next buttons overlaid on image
- Counter badge (1/N)
- Caption display
- Attribution line with source link
- Info dialog (modal) with detailed metadata
- Lightbox for full-size viewing
- Admin edit link
- No-image placeholder support

### Range Map

**V1** (`/Users/jeff/dev/gallformers/v1/components/rangemap.tsx`):
- Uses `react-simple-maps` with `ComposableMap`, `Geographies`, `Geography`
- Projection: geoConicEqualArea centered on US/Canada
- Zoomable group with pan limits
- Tooltip via `react-tooltip`
- Color: ForestGreen for in-range, White for out

**V2** (`/Users/jeff/dev/gallformers/lib/gallformers_web/components/data_display_components.ex:893-953`):
- Uses `phx-hook="RangeMap"` D3.js hook
- Data passed as JSON: `data-in-range`, `data-excluded-range`
- Supports editable mode with `data-editable`
- Loading state with animated icon
- Colors: Green for in-range, Coral for excluded, White for out

### Source Display

**V1** (`/Users/jeff/dev/gallformers/v1/components/sourcelist.tsx`):
- DataTable with selectable rows
- Selected source description shown in main area with markdown
- Navigation buttons (< >) to cycle sources
- Alert banner for Gallformers Notes
- Columns: Author, Year, Title (linked), License (icon)
- Quote marks around description
- Copyright tooltip with license info

**V2** (inline in `host_live.ex:481-553`):
- Card-style layout for each source
- Click source to open modal with full description
- Blue border highlighting for Gallformers Notes
- Info alert for notes availability
- Font size controls in modal (A+/A-)
- External link and source page link in modal footer

### Aliases/Synonymy

**V1** (`/Users/jeff/dev/gallformers/v1/components/speciesSynonymy.tsx`):
- Separates common names and scientific synonyms
- Collapsible/expandable DataTable for synonyms
- Shows Name and Notes columns
- Button to toggle visibility

**V2** (inline in `host_live.ex:321-330`):
- Simple inline display
- Shows all aliases with type in parentheses
- No expandable table
- Comma-separated list

---

## Recommendations

### Parity Items (No Action Needed)
1. **Taxonomy display** - Both versions show family/genus/section with links
2. **Data complete badge** - Both use emoji with tooltip
3. **Range map** - Both show US/Canada choropleth
4. **Image gallery** - Both have carousel, lightbox, attribution
5. **See Also links** - Both link to external references
6. **Admin edit links** - Both show for authenticated users
7. **ID tool link** - Both link host name to filtered ID search

### V2 Improvements Over V1
1. **SEO** - V2 has JSON-LD structured data
2. **Galls table sorting** - V2 supports sortable columns
3. **Data complete column** - V2 shows per-gall status
4. **Source modal font controls** - V2 has accessibility feature
5. **Gall edit links** - V2 links to gall-host mapping

### V2 Gaps (Consider Adding)

1. **Aliases expandable table** - V1 has richer alias display with notes
   - **Recommendation**: Add expandable DataTable or accordion for synonymy details
   - **Priority**: Medium
   - **V1 Reference**: `v1/components/speciesSynonymy.tsx:62-89`

2. **Source selection workflow** - V1 allows selecting a source to see its description inline
   - **Recommendation**: Consider adding source selection that shows description inline (current modal-only approach is also acceptable)
   - **Priority**: Low (modal approach is valid alternative)

3. **Common names separation** - V1 separates common names from scientific synonyms
   - **Recommendation**: Filter aliases by type and display common names separately
   - **Priority**: Low
   - **V1 Reference**: `v1/components/speciesSynonymy.tsx:13,39-43`

### Code Quality Notes

- V1 uses fp-ts for Option handling which adds complexity
- V2 uses simpler nil checks and Map.get with defaults
- V2 has cleaner separation between context modules (Hosts, Taxonomy, Species, Sources)
- V1 loads all data in single Prisma query with nested includes
- V2 makes multiple smaller queries which may have different performance characteristics
