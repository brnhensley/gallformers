# Change: Svelte Public Site

## Why

The v2 rewrite replaces the current Next.js public site with a Svelte SPA. This proposal covers all public-facing pages that don't require authentication. The public site is the primary interface for users identifying galls, browsing the database, and learning about gall biology.

This is **Phase 3** of the `rewrite-gallformers-v2` umbrella proposal.

## What Changes

### Public Pages to Implement

| Route | Purpose | Complexity |
|-------|---------|------------|
| `/` | Home page with random gall | Low |
| `/gall/{id}` | Gall species detail | Medium |
| `/host/{id}` | Host plant detail | Medium |
| `/family/{id}` | Taxonomic family page | Low |
| `/genus/{id}` | Taxonomic genus page | Low |
| `/source/{id}` | Source/reference detail | Low |
| `/section/{id}` | Section detail | Low |
| `/place/{id}` | Geographic place detail | Low |
| `/id` | ID tool (gall identification) | **High** |
| `/globalsearch` | Global search | Medium |
| `/explore` | Explore/browse tree view | Medium |
| `/filterguide` | Filter guide | Low |
| `/glossary` | Glossary | Low |
| `/resources` | Resources page | Low |
| `/about` | About page | Low |
| `/404` | Not found page | Low |

**Excluded** (handled by `add-articles-system`):
- `/ref/{slug}` - Reference article pages
- `/refindex` - Reference article index

### Components

**From shared library (`add-svelte-common`):**
- `RangeMap` - Geographic distribution map
- `Typeahead` - Search-as-you-type select
- `Table` - Sortable, paginated table
- `Button`, `Spinner`, `Alert` - UI primitives

**Public-specific components:**
| Component | Purpose |
|-----------|---------|
| `ImageGallery` | Image carousel/gallery with lightbox |
| `SourceList` | Citation list with selection |
| `ExternalLinks` | Links to iNaturalist, BugGuide, Google Scholar, BHL |
| `TaxonomyBreadcrumb` | Family/Genus/Species navigation |
| `TreeMenu` | Hierarchical tree browser (explore page) |

### Technical Approach

- **Dynamic rendering**: All pages fetch data from Go API endpoints at request time (no static generation)
- **API integration**: All data comes from Go API endpoints (from `add-go-api`)
- **URL preservation**: All routes must match current URL structure exactly (SEO)
- **Tailwind CSS**: Following patterns from umbrella design decisions
- **Caching**: API responses use appropriate Cache-Control headers; SvelteKit prefetches links on hover

## Impact

- **Specs affected**: New `public-site` capability
- **Code affected**: `v2/web/` only
- **Dependencies**:
  - `define-v2-foundation` (Svelte app scaffold)
  - `add-svelte-common` (shared UI component library)
  - `add-go-api` (API endpoints for all entity types)
  - `add-image-processing` (image display integration)

## Success Criteria

1. All public pages render with visual parity to current site
2. URL structure matches exactly (`/gall/123`, `/host/456`, etc.)
3. Global search returns same results as current implementation
4. ID tool filters produce same results as current implementation
5. Pages load quickly with no perceptible lag on navigation
6. Mobile responsive layout maintained
7. SEO metadata preserved (titles, descriptions, Open Graph)

## Risk Areas

### ID Tool Complexity

The ID tool (`/id`) is 52KB of TypeScript with complex filter state management:
- Multiple filter fields (location, texture, shape, color, season, etc.)
- Host/genus typeahead selection
- Results filtering with AND/OR logic
- URL query parameter state persistence

**Mitigation**: Dedicate separate design phase for ID tool architecture before implementation.

### Range Map - Shared Component

The range map is used in both public and admin contexts:
- **Public pages** (view-only): Two states (in-range / not)
- **Admin pages** (editable): Three states (in-range / excluded / neither), click-to-toggle, bulk actions

**Decision**: One shared `RangeMap.svelte` component with `editable` prop. Admin wraps it with `EditableRangeMap.svelte` adding toggle logic, legend, and action buttons. Uses d3-geo for projection math with existing `usa-can-topo.json`. See design.md for implementation details.
