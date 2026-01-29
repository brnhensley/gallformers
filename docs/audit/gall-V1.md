# Gall Detail Page: V1 vs V2 Comparison

**V1 Route**: `/gall/[id]`
**V2 Route**: `/gall/:id`

## File Locations

### V1 (Next.js)
| Layer | File | Purpose |
|-------|------|---------|
| Page | `v1/pages/gall/[id]/index.tsx` (L1-332) | Main page component with SSG |
| API/DB | `v1/libs/db/gall.ts` (L1-759) | Database queries via Prisma |
| Components | `v1/components/images.tsx` (L1-303) | Image gallery with carousel |
| Components | `v1/components/rangemap.tsx` (L1-66) | Geographic range map |
| Components | `v1/components/sourcelist.tsx` (L1-242) | Source list with DataTable |
| Components | `v1/components/seealso.tsx` (L1-120) | External links (iNat, BugGuide, etc.) |
| Components | `v1/components/speciesSynonymy.tsx` (L1-96) | Alias/synonymy display |
| Components | `v1/components/edit.tsx` (L1-26) | Admin edit button |
| Components | `v1/components/infotip.tsx` (L1-31) | Tooltip component |

### V2 (Phoenix LiveView)
| Layer | File | Purpose |
|-------|------|---------|
| LiveView | `lib/gallformers_web/live/gall_live.ex` (L1-629) | Main LiveView |
| Context | `lib/gallformers/species.ex` (L1-1196) | Species/gall business logic |
| Context | `lib/gallformers/sources.ex` (L1-378) | Source data access |
| Context | `lib/gallformers/hosts.ex` (L1-847) | Host data & range queries |
| Context | `lib/gallformers/gall_summary.ex` (L1-263) | SEO description generator |
| Components | `lib/gallformers_web/components/data_display_components.ex` | `.image_gallery`, `.range_map` |
| Components | `lib/gallformers_web/components/ui_components.ex` | `.see_also`, `.info_tip`, `.pagination` |
| Components | `lib/gallformers_web/components/core_components.ex` | `.data_complete_badge`, `.modal` |

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Rendering** | SSG via `getStaticProps` | LiveView (SSR + WebSocket) | Complete | V2 is dynamic, no revalidation needed |
| **Species Name Display** | `<h2><em>{species.name}</em></h2>` (L115-117) | Same pattern (L252) | Complete | Identical styling |
| **Data Complete Badge** | Custom tooltip with emoji `💯`/`❓` (L120-134) | `.data_complete_badge` component (L262-266) | Complete | V2 uses text "Complete"/"In Progress" instead of emoji |
| **Undescribed Banner** | Conditional row with danger text + copy button (L137-144) | Styled alert box with CopyToClipboard hook + iNat link (L269-302) | **Enhanced** | V2 adds direct iNat observation link and learn more link |
| **Taxonomy Links** | Family + Genus with `formatWithDescription` (L146-157) | Family + Genus with `|` separator (L306-326) | Complete | V2 omits genus description |
| **Hosts List** | `species.hosts.map(hostLinker)` with edit button (L159-163) | Loop with `/` separator + admin edit (L328-348) | Complete | Both show hosts as italic links |
| **Morphology Fields** | Two-column layout with 11 fields (L165-247) | Two-column grid with all fields (L350-368) | Complete | Same fields: detachable, color, texture, abundance, shape, season, alignment, walls, location, form, cells |
| **Related Galls** | Inline links from `getRelatedGalls()` (L206-219) | **Missing** | **Gap** | V2 does not fetch or display related galls |
| **Range Map** | `<RangeMap>` with react-simple-maps (L248-255) | `.range_map` with D3.js hook (L370-378) | Complete | Different libraries, same visual |
| **Excluded Range** | `excludedPlaces` computed via `species.places` | `excluded_range` via `get_excluded_places_for_gall()` | Complete | V2 shows excluded as coral color |
| **Range InfoTip** | Detailed tooltip explaining range computation (L250-253) | **Missing** | **Gap** | V2 lacks the explanatory tooltip |
| **Synonymy/Aliases** | `<SpeciesSynonymy>` with DataTable, pagination, show/hide (L259-263) | Inline table with pagination (L381-414) | Complete | V2 shows type and notes in table |
| **Common Names** | Filtered from aliases by type (V1 component L38-44) | **Missing** | **Gap** | V2 aliases table shows all types but no separate "Common Names" section |
| **Image Gallery** | `<Images>` with carousel + info modal (L265-272) | `.image_gallery` with JS hook (L417-424) | Complete | Both have carousel, lightbox, info dialog |
| **Image Edit Button** | Session-gated admin link (L280-294) | `@current_user` gated link (L163-169) | Complete | Same pattern |
| **Gallformers Notes Alert** | Dismissible alert with "Show notes" button (L129-144) | Blue-bordered alert with icon (L429-459) | Complete | Same UX, different styling |
| **Source List** | `<SourceList>` with DataTable, row selection, prev/next (L284-292) | List with description preview + modal (L461-533) | **Different** | V2 uses expandable cards instead of table |
| **Source Description Display** | ReactMarkdown with inline quotes (L177-207) | Modal with Markdown.render! and font size controls (L543-624) | **Enhanced** | V2 adds adjustable font size |
| **Source Default Selection** | URL param + state for `selectedSource` (L43-44) | Click-to-expand modal (L196-205) | Different | V1 has prev/next navigation |
| **See Also Links** | `<SeeAlso>` with logo images (L297-299) | `.see_also` component (L535) | Complete | Same external links: iNat, BugGuide, Scholar, BHL |
| **Undescribed See Also** | Shows only iNat with Gallformers Code search (L94-114) | Currently hidden for undescribed (L634 condition) | **Gap** | V2 hides entire section for undescribed |
| **Phenology Tool Link** | Banner at top linking to Shiny app (L83-106) | **Missing** | **Gap** | V2 does not show phenology tool link |
| **Copy Gallformers Code** | `navigator.clipboard.writeText` with toast (L61-69) | `CopyToClipboard` JS hook with flash (L168-181) | Complete | Both copy to clipboard with feedback |
| **Edit Buttons** | `<Edit>` component multiple places (L121, 161, 216, 150) | Inline links with pencil icon (L253-261, L340-347, L492-500) | Complete | Same admin-only edit links |
| **SEO Meta** | `<Head>` with `createSummaryGall()` (L74-77) | `GallSummary.for_seo()` + JSON-LD (L77-99) | **Enhanced** | V2 adds structured data |
| **Error Handling** | `ErrorPage` for 404, fallback loader (L50-55) | Assign-based error display (L244-246) | Complete | Both handle missing galls |
| **Loading State** | `router.isFallback` check (L50-51) | LiveView connected state | N/A | Different paradigms |

---

## Detailed Analysis

### 1. UI Layer

#### Header Section
- **V1** (L108-163): Title + data complete emoji badge + edit button
- **V2** (L248-267): Title + data complete text badge + edit icon

Both display the gall name in italics with an edit link for authenticated users. V2 uses a cleaner text-based badge ("Complete"/"In Progress") vs V1's emoji (`💯`/`❓`).

#### Undescribed Gall Banner
- **V1** (L137-144): Red danger text + "Copy gallformers code" button
- **V2** (L269-302): Amber alert box with code, copy button, iNat link, and "learn more" link

**V2 Enhancement**: Adds direct link to iNaturalist observations using the Gallformers Code observation field, plus a link to documentation explaining how to contribute observations.

#### Morphology Display
Both implementations display the same 11 morphology fields in a two-column layout:
- Column 1: Detachable, Color, Texture, Abundance, Shape, Season
- Column 2: Alignment, Walls, Location, Form, Cells

V1 includes a "Related" field showing other galls by the same inducer (L206-219), which is **missing in V2**.

#### Range Map
- **V1** (L248-255): Uses `react-simple-maps` with `ComposableMap`, `Geographies`, `Geography` components
- **V2** (L370-378): Uses D3.js via `RangeMap` JS hook with `phx-hook="RangeMap"`

Both show US and Canadian states/provinces. V2 adds visual distinction for excluded regions (coral color).

**Gap**: V1 includes an InfoTip explaining how the range is computed from host ranges (L250-253). V2 lacks this explanation.

#### Source List
- **V1** (L284-292): Uses `DataTable` with row selection, prev/next navigation, inline description with quote marks
- **V2** (L461-533): Uses card-based list with expandable descriptions via modal

V1 allows cycling through sources with prev/next buttons. V2 requires clicking "Read more" to see full description in a modal.

**V2 Enhancement**: Modal includes font size adjustment (A+/A-) for accessibility.

#### Synonymy/Aliases
- **V1** (L259-263): `SpeciesSynonymy` component with expandable DataTable, separates common names from scientific names
- **V2** (L381-414): Inline table with Name, Type, Notes columns, uses `.pagination` component

**Gap**: V1 displays "Common Name(s)" as a separate section at the top. V2 shows all alias types in the same table without this separation.

### 2. Business Logic

#### Data Assembly
- **V1** (`v1/libs/db/gall.ts` L86-274): Complex Prisma query with nested includes for all associations, returns `GallApi` type with fp-ts Option handling
- **V2** (`lib/gallformers/species.ex` L174-197): Ecto query for species + gall join, then separate calls for hosts, images, sources, aliases, taxonomy, range

V1 uses a single mega-query pattern; V2 uses multiple focused queries assembled in the LiveView mount.

#### Related Galls Logic
- **V1** (`v1/libs/db/gall.ts` L468-492): `getRelatedGalls()` finds species with same binomial name prefix
- **V2**: **Not implemented** - no equivalent function

#### Source Sorting
- **V1** (`v1/libs/db/gall.ts` L214): Sorted by publication year
- **V2** (`lib/gallformers/sources.ex` L127-136): Sorted with priority: default first, Gallformers Notes second, then alphabetically

V2 has improved sorting logic to prioritize important sources.

#### SEO Generation
- **V1** (`v1/libs/pages/renderhelpers.ts` `createSummaryGall()`): Creates plain text summary
- **V2** (`lib/gallformers/gall_summary.ex` L1-263): Full module for generating summaries with mode options (short/medium/full), handles edge cases like non-gall forms

**V2 Enhancement**: Adds JSON-LD structured data for search engines (L119-132).

### 3. Data Layer

#### Gall Query
- **V1**: Single Prisma `findMany` with extensive `include` nesting (~50 lines of include config)
- **V2**: `Species.get_gall_by_id/1` returns basic gall data; filter values fetched separately via `get_gall_filter_values/1`

V2's separation allows for more targeted queries but requires more function calls.

#### Hosts Query
- **V1**: Included in main query via `hosts: { include: { hostspecies: { ... } } }`
- **V2**: `Hosts.get_hosts_for_gall/1` - dedicated Ecto query (L108-120)

#### Range Query
- **V1**: Computed client-side from host places (L46-48)
- **V2**: `Hosts.get_places_for_gall/1` returns place codes directly from DB (L182-193)

V2 has a cleaner server-side approach.

---

## Recommendations

### Priority 1 - Missing Features
1. **Related Galls**: Implement equivalent to V1's `getRelatedGalls()` function
2. **Phenology Tool Link**: Add banner linking to the Shiny phenology app
3. **Range Map InfoTip**: Add explanatory tooltip for how range is computed

### Priority 2 - Parity Improvements
4. **Common Names Section**: Display common name aliases separately from scientific synonyms
5. **Undescribed See Also**: Show iNat link for undescribed species (currently hidden)
6. **Source Navigation**: Consider adding prev/next source navigation like V1

### Priority 3 - V2 Enhancements to Keep
- Structured data (JSON-LD) for SEO
- Excluded range visualization (coral color)
- Font size controls in source modal
- Direct iNat observation link for undescribed galls
- Improved source sorting (default first, notes second)

---

## File References

### V1 Key Locations
- Page: `/Users/jeff/dev/gallformers/v1/pages/gall/[id]/index.tsx`
- DB: `/Users/jeff/dev/gallformers/v1/libs/db/gall.ts`
- Images: `/Users/jeff/dev/gallformers/v1/components/images.tsx`
- RangeMap: `/Users/jeff/dev/gallformers/v1/components/rangemap.tsx`
- SourceList: `/Users/jeff/dev/gallformers/v1/components/sourcelist.tsx`
- SeeAlso: `/Users/jeff/dev/gallformers/v1/components/seealso.tsx`
- Synonymy: `/Users/jeff/dev/gallformers/v1/components/speciesSynonymy.tsx`

### V2 Key Locations
- LiveView: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/gall_live.ex`
- Species Context: `/Users/jeff/dev/gallformers/lib/gallformers/species.ex`
- Sources Context: `/Users/jeff/dev/gallformers/lib/gallformers/sources.ex`
- Hosts Context: `/Users/jeff/dev/gallformers/lib/gallformers/hosts.ex`
- GallSummary: `/Users/jeff/dev/gallformers/lib/gallformers/gall_summary.ex`
- Data Components: `/Users/jeff/dev/gallformers/lib/gallformers_web/components/data_display_components.ex`
- UI Components: `/Users/jeff/dev/gallformers/lib/gallformers_web/components/ui_components.ex`
- Core Components: `/Users/jeff/dev/gallformers/lib/gallformers_web/components/core_components.ex`
