# Design: Svelte Public Site

## Context

This proposal implements all public-facing pages for gallformers v2. The primary challenge is replicating the complex ID tool while keeping the codebase maintainable.

### Current Implementation Summary

| Page | Current Tech | Data Source | Complexity |
|------|--------------|-------------|------------|
| Home | SSR, random gall query | `randomGall()` | Low |
| Entity detail pages | Static generation | `getStaticProps` per entity | Medium |
| ID Tool | SSR, client-side filtering | Multiple filter queries + client search | **High** |
| Global Search | SSR | `globalSearch()` single query | Medium |
| Explore | Static, tree menu | `getFamiliesWithSpecies()` | Medium |
| Static pages | Static markdown-ish | Hard-coded content | Low |

## Goals / Non-Goals

**Goals:**
- Visual and functional parity with current public site
- Improved code organization (current ID tool is 1400+ lines in one file)
- Mobile-responsive layout maintained
- Fast page loads with appropriate caching

**Non-Goals:**
- Redesigning the UI (that's a separate future effort)
- Adding new features to the ID tool
- Changing search behavior or results

## Decisions

### Decision 1: ID Tool Architecture

The current ID tool is a 52KB monolith. For v2:

**Approach: Decompose into composable stores and components**

```
v2/web/src/routes/id/
├── +page.svelte           # Main page, orchestrates components
├── stores/
│   ├── filters.ts         # Svelte store for filter state
│   ├── results.ts         # Derived store for filtered results
│   └── url.ts             # URL state sync
├── components/
│   ├── FilterPanel.svelte # All filter controls
│   ├── HostPicker.svelte  # Typeahead for host selection
│   ├── GenusPicker.svelte # Typeahead for genus selection
│   ├── ResultsGrid.svelte # Filtered results display
│   └── FilterChips.svelte # Active filter display
└── utils/
    └── gallsearch.ts      # Filter logic (port from libs/utils/gallsearch.ts)
```

**Rationale:**
- Svelte stores provide reactive state management without React Hook Form complexity
- URL state sync keeps filter state shareable (current behavior)
- Decomposition makes each piece testable
- Filter logic isolated in pure functions for easy porting

### Decision 2: Mapping Library

**Decision: Use shared RangeMap from `add-svelte-common`**

The `RangeMap` component is defined in the common component library. Public pages use it in view-only mode:

```svelte
<script>
  import { RangeMap } from '$lib/components';
</script>

<RangeMap inRange={speciesRange} />
```

See `add-svelte-common/design.md` for full implementation details.

**Notes:**
- Public uses view-only mode (default `editable=false`)
- Admin wraps with `EditableRangeMap` for three-state editing (see `add-svelte-admin`)
- Uses d3-geo + TopoJSON (lightweight, existing data file)

### Decision 3: Entity Detail Page Structure

All entity detail pages follow the same pattern:

```
/gall/{id}   → GallDetail.svelte
/host/{id}   → HostDetail.svelte
/family/{id} → FamilyDetail.svelte
...etc
```

**Shared abstractions:**
- `EntityLayout.svelte` - Common page structure (title, images, metadata)
- `TaxonomyBreadcrumb.svelte` - Family → Genus → Species navigation
- `SourceList.svelte` - Citations with selection state

**Data fetching pattern:**
```svelte
<!-- +page.svelte -->
<script>
  export let data;  // From +page.ts load function
</script>

<!-- +page.ts -->
export async function load({ params, fetch }) {
  const response = await fetch(`/api/v2/gall/${params.id}`);
  if (!response.ok) throw error(404);
  return { gall: await response.json() };
}
```

### Decision 4: Global Search Implementation

Current search queries multiple tables and merges results. Two options:

1. **Client-side merge**: Multiple API calls, merge in browser
2. **Server-side merge**: Single `/api/v2/search` endpoint returns unified results

**Decision: Server-side merge (existing pattern)**

The Go API will provide a `/api/v2/search?q={query}` endpoint that:
- Searches all relevant tables
- Returns typed results with `type` field
- Handles ranking/sorting server-side

This matches current behavior and keeps the Svelte component simple.

### Decision 5: Static Page Content

Pages like `/about`, `/resources`, `/filterguide` contain mostly static content.

**Options:**
1. Hard-code in Svelte components
2. Store as markdown, render at build time
3. Fetch from API

**Decision: Hard-code in Svelte components**

- Content rarely changes
- No build-time complexity
- Easy to edit directly
- Matches current implementation pattern

### Decision 6: Image Gallery Component

Species detail pages show image galleries with:
- Carousel navigation
- Source attribution per image
- Lightbox view

**Approach: Custom Svelte component**

Rather than importing a heavy carousel library, build a minimal component:

```svelte
<!-- ImageGallery.svelte -->
<script>
  export let images: Image[];
  let currentIndex = 0;
</script>

<div class="relative">
  <img src={images[currentIndex].url} alt={images[currentIndex].alt} />
  <div class="absolute bottom-0">
    <span>{images[currentIndex].creator} © {images[currentIndex].license}</span>
  </div>
  <button on:click={() => currentIndex--} disabled={currentIndex === 0}>←</button>
  <button on:click={() => currentIndex++} disabled={currentIndex === images.length - 1}>→</button>
</div>
```

Lightbox can use native `<dialog>` element for modal behavior.

## Component Inventory

### Page Components (in `routes/`)

| Component | Route | Notes |
|-----------|-------|-------|
| `+page.svelte` (home) | `/` | Random gall, intro content |
| `gall/[id]/+page.svelte` | `/gall/{id}` | Species detail |
| `host/[id]/+page.svelte` | `/host/{id}` | Host detail |
| `family/[id]/+page.svelte` | `/family/{id}` | Family taxonomy |
| `genus/[id]/+page.svelte` | `/genus/{id}` | Genus taxonomy |
| `source/[id]/+page.svelte` | `/source/{id}` | Source detail |
| `section/[id]/+page.svelte` | `/section/{id}` | Section taxonomy |
| `place/[id]/+page.svelte` | `/place/{id}` | Place detail |
| `id/+page.svelte` | `/id` | ID tool |
| `globalsearch/+page.svelte` | `/globalsearch` | Search results |
| `explore/+page.svelte` | `/explore` | Tree browser |
| `filterguide/+page.svelte` | `/filterguide` | Filter guide |
| `glossary/+page.svelte` | `/glossary` | Glossary |
| `resources/+page.svelte` | `/resources` | Resources |
| `about/+page.svelte` | `/about` | About |

### Shared Components

**From `add-svelte-common` (in `$lib/components/`):**

| Component | Purpose |
|-----------|---------|
| `RangeMap` | SVG map for geographic range |
| `Typeahead` | Search-as-you-type select |
| `Table` | Sortable, paginated table |
| `Button` | Action buttons |
| `Spinner` | Loading indicator |
| `Alert` | Error/info messages |

**Public-specific components (in `routes/` or `$lib/components/public/`):**

| Component | Purpose |
|-----------|---------|
| `ImageGallery.svelte` | Image carousel with attribution and lightbox |
| `SourceList.svelte` | Citation list with selection state |
| `ExternalLinks.svelte` | Links to iNaturalist, BugGuide, Google Scholar, BHL |
| `TaxonomyBreadcrumb.svelte` | Family/Genus/Species navigation |
| `TreeMenu.svelte` | Hierarchical tree browser for explore page |
| `EntityLayout.svelte` | Common page structure for entity detail pages |

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| ID tool filter logic differs from current | Port `gallsearch.ts` exactly, add comparison tests |
| SVG map doesn't match current interactivity | Current map is view-only anyway, SVG sufficient |
| Missing edge cases in entity pages | Manual testing checklist per entity type |
| Performance regression on large result sets | Implement virtual scrolling if needed |

## Resolved Questions

### Tree Menu Library

**Decision: Build custom component**

Rationale:
- The explore page tree is straightforward (family → genus → species hierarchy)
- External libraries add dependencies and may not match exact behavior needed
- Custom component gives full control over styling and click handling
- Current v1 uses `react-simple-tree-menu` which is lightweight - similar simplicity achievable in Svelte

Implementation: Simple recursive Svelte component with expand/collapse state and click-to-navigate.

### Rendering Strategy

**Decision: All pages are dynamically rendered (no static generation)**

All pages fetch data from the Go API at request time. There is no pre-rendering or static generation.

| Page Type | Rendering | Rationale |
|-----------|-----------|-----------|
| All pages | Dynamic (SSR/CSR) | Simplicity, data freshness, consistent architecture |

SEO is handled via proper meta tags, semantic HTML, and server-side rendering where SvelteKit provides it by default.

### Caching Strategy

**Decision: Multi-layer caching for performance**

| Layer | Strategy |
|-------|----------|
| **API responses** | Go API sets `Cache-Control` headers (e.g., `max-age=300` for entity data, `no-cache` for search) |
| **Link prefetching** | SvelteKit's `data-sveltekit-preload-data="hover"` prefetches on link hover |
| **Client-side stores** | Svelte stores cache fetched data during navigation (e.g., glossary terms, filter options) |
| **Browser cache** | Respects API Cache-Control headers for repeat visits |

This approach balances freshness with performance - frequently accessed data is cached, while searches always hit the API.
