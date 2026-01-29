# Global Search Page Comparison: V1 vs V2

## Overview

| Aspect | V1 (Next.js) | V2 (Phoenix LiveView) |
|--------|--------------|----------------------|
| Route | `/globalsearch?searchText=...` | `/globalsearch?q=...` |
| Main File | `v1/pages/globalsearch.tsx` | `lib/gallformers_web/live/search_live.ex` |
| Search Logic | `v1/libs/db/search.ts` | `lib/gallformers/search.ex` |
| Ranking | None (alphabetical) | `lib/gallformers/search/ranking.ex` |

## File Locations

### V1 Files
- **Page**: `v1/pages/globalsearch.tsx` (lines 1-215)
- **Search Context**: `v1/libs/db/search.ts` (lines 1-199)
- **Header Search Form**: `v1/layouts/header.tsx` (lines 55-75)
- **Data Table Component**: `v1/components/DataTable.tsx` (wrapper for react-data-table-component)

### V2 Files
- **LiveView**: `lib/gallformers_web/live/search_live.ex` (lines 1-369)
- **Search Context**: `lib/gallformers/search.ex` (lines 1-560)
- **Ranking Module**: `lib/gallformers/search/ranking.ex` (lines 1-79)
- **Search Input Component**: `lib/gallformers_web/components/form_components.ex` (lines 81-99)
- **Header Search Form**: `lib/gallformers_web/components/layouts.ex` (lines 109-126, 207-226)

---

## UI Layer Comparison

### Search Input

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Location | Header navbar | Header navbar + dedicated page | Equivalent | Both use header form |
| Input Type | `<FormControl type="search">` | `<input type="search">` | Equivalent | |
| Query Param | `searchText` | `q` | Different | V2 uses shorter param |
| Debounce | None (form submit only) | 300ms via `phx-debounce` | V2 Enhanced | Real-time as-you-type |
| URL Sync | Query param on submit | `push_patch` updates URL | V2 Enhanced | Bookmarkable results |
| ARIA Label | `aria-label="Search"` | `aria-label="Search"` | Equivalent | |

### Results Display

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Component | react-data-table-component | Custom HTML table | Different | V2 uses native Phoenix |
| Empty State | Text: "No results for '...'" | Styled card with icon | V2 Enhanced | Better UX |
| No Query State | N/A (server render) | Styled help text | V2 Enhanced | Guides user |
| Results Count | Not shown | "Found X result(s) for '...'" | V2 Enhanced | |
| Row Striping | Yes (`striped` prop) | Via `gf-table` CSS class | Equivalent | |
| Selected Row | Not supported | Yellow highlight (`!bg-canary`) | V2 Enhanced | Keyboard nav |

### Result Type Icons

| Type | V1 Icon | V2 Icon | Status | Notes |
|------|---------|---------|--------|-------|
| Gall | `/images/cynipid_R.svg` (45x45) | `gf-gall` (w-10 h-8) | Equivalent | Larger for galls |
| Host | `/images/host.svg` (25x25) | `gf-host` (w-6 h-6) | Equivalent | |
| Glossary | `/images/entry.svg` (25x25) | `gf-entry` (w-6 h-6) | Equivalent | |
| Source | `/images/source.svg` (25x25) | `gf-source` (w-6 h-6) | Equivalent | |
| Genus | `/images/taxon.svg` (25x25) | `gf-taxon` (w-6 h-6) | Equivalent | |
| Section | `/images/taxon.svg` (25x25) | `gf-taxon` (w-6 h-6) | Equivalent | |
| Family | `/images/taxon.svg` (25x25) | `gf-taxon` (w-6 h-6) | Equivalent | |
| Place | `/images/place.svg` (25x25) | `gf-place` (w-6 h-6) | Equivalent | |

### Table Columns

| Column | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Type | Icon only, sortable | Icon only, sortable | Equivalent | |
| Name | Linked, sortable | Linked, sortable | Equivalent | |
| Sort Indicator | None visible | ↑/↓ arrows | V2 Enhanced | |
| Default Sort | `pubyear` (bug?) | `relevance` | V2 Enhanced | V1 has wrong default |

### Keyboard Navigation

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| Arrow Up/Down | Not supported | Moves selection | V2 Only | |
| Enter to Navigate | Not supported | Opens selected result | V2 Only | |
| Visual Indicator | None | Highlighted row | V2 Only | |
| Help Text | None | Keyboard hints shown | V2 Only | |

### Result Formatting

| Type | V1 Format | V2 Format | Status | Notes |
|------|-----------|-----------|--------|-------|
| Gall | `<em>{name} (aliases)</em>` | `<em>{name}</em> (aliases)` | Equivalent | Aliases in gray |
| Host | `<em>{name} (aliases)</em>` | `<em>{name}</em> (aliases)` | Equivalent | |
| Glossary | `{Name}` (capitalized) | `{name}` | Slight diff | V1 capitalizes |
| Source | `{display}` (via sourceToDisplay) | `{author} ({year}): {title}` | Equivalent | Same format |
| Genus | `<em>Genus {name} (desc)</em>` | `<em>Genus {name}</em>` | Equivalent | |
| Section | `<em>Section {name} (desc)</em>` | `<em>Section {name}</em>` | Equivalent | |
| Family | `Family {name}` | `Family {name}` | Equivalent | Not italicized |
| Place | `{name} - {code}` | `{name} - {code}` | Equivalent | |

### Links

| Type | V1 Link | V2 Link | Status |
|------|---------|---------|--------|
| Gall | `/gall/{id}` | `/gall/{id}` | Equivalent |
| Host | `/host/{id}` | `/host/{id}` | Equivalent |
| Glossary | `/glossary#{word.toLowerCase()}` | `/glossary#{String.downcase(name)}` | Equivalent |
| Source | `/source/{id}` | `/source/{id}` | Equivalent |
| Genus | `/genus/{id}` | `/genus/{id}` | Equivalent |
| Section | `/section/{id}` | `/section/{id}` | Equivalent |
| Family | `/family/{id}` | `/family/{id}` | Equivalent |
| Place | `/place/{id}` | `/place/{id}` | Equivalent |

---

## Business Logic Comparison

### Search Query Processing

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Query Source | URL `searchText` param | URL `q` param | Different | |
| Whitespace Handling | Replaced with `%` | String.trim() | Different | V1 allows multi-word wildcards |
| Empty Query | Returns empty results | Returns empty results | Equivalent | |

### Entity Searches

| Entity | V1 Search Fields | V2 Search Fields | Status |
|--------|------------------|------------------|--------|
| Galls | `species.name`, `alias.name` | `species.name`, `alias.name` (via FTS5 or LIKE) | V2 Enhanced |
| Hosts | `species.name`, `alias.name` | `species.name`, `alias.name` (via FTS5 or LIKE) | V2 Enhanced |
| Glossary | `word`, `definition` (in-memory filter) | `word`, `definition` (SQL) | V2 Enhanced |
| Sources | `author`, `title` | `author`, `title` | Equivalent |
| Taxonomy | `name`, `description` | `name` only | V1 Better |
| Places | `name`, `code` | `name`, `code` | Equivalent |

### Alias Handling

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Search by Alias | Yes | Yes | Equivalent | |
| Return All Aliases | Via join, merged | Via separate query, batched | Equivalent | Different implementation |
| Deduplication | `species.find(s => s.id === o.id)` | `Enum.uniq_by(& &1.id)` | Equivalent | |

### Ranking/Sorting

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Default Order | Alphabetical by name | By relevance score | V2 Enhanced | |
| Relevance Scoring | None | 3-tier scoring (best/good/ok) | V2 Only | |
| FTS5 Integration | None | Uses BM25 ranking | V2 Only | |
| User-Sortable | Yes (type, name) | Yes (type, name, relevance) | V2 Enhanced | |

### V2 Ranking Details (lib/gallformers/search/ranking.ex)

The V2 ranking system provides intelligent match quality scoring:

- **Score 0 (Best)**: First word starts with first search term (e.g., "q alba" matches "Quercus alba")
- **Score 1 (Good)**: All search terms match word prefixes
- **Score 2 (OK)**: Partial/mid-word matches

This ensures natural scientific names rank higher than compound names (e.g., "Quercus alba" ranks above "q-alba-gall" for search "q alba").

---

## Data Layer Comparison

### Tables Searched

| Table | V1 | V2 | Notes |
|-------|----|----|-------|
| species | Yes | Yes | Via Prisma / Ecto |
| alias | Yes | Yes | |
| aliasspecies | Yes | Yes | Junction table |
| gall | Yes (via species) | Yes (via gallspecies join) | |
| glossary | Yes | Yes | |
| source | Yes | Yes | |
| taxonomy | Yes (genus, family, section) | Yes (genus, family, section filtered) | |
| place | Yes | Yes | |

### Search Technology

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| ORM | Prisma | Ecto | Different | Both SQL-based |
| Full-Text Search | None | SQLite FTS5 with fallback | V2 Enhanced | |
| Case Sensitivity | Prisma `contains` (varies) | Explicit `lower()` + LIKE | V2 Better | Consistent behavior |
| Wildcards | `%` for spaces | No automatic wildcard | Different | |

### V2 FTS5 Implementation (lib/gallformers/search.ex lines 261-296)

V2 uses a hybrid search strategy:
1. **Primary**: FTS5 prefix matching via `species_fts` virtual table with BM25 ranking
2. **Fallback**: LIKE-based search for mid-word matches when FTS5 returns no results

```sql
-- V2 FTS5 query (simplified)
SELECT f.species_id, s.name, g.undescribed
FROM species_fts f
JOIN species s ON s.id = f.species_id
JOIN gallspecies gs ON gs.species_id = s.id
JOIN gall g ON g.id = gs.gall_id
WHERE s.taxoncode = 'gall' AND species_fts MATCH ?
ORDER BY bm25(species_fts)
LIMIT 100
```

### Result Combination

| Aspect | V1 | V2 | Status |
|--------|----|----|--------|
| Merge Strategy | Sequential concat | Sequential concat | Equivalent |
| Order | species → glossary → sources → places → taxa | galls → hosts → glossary → sources → taxonomy → places | Different |
| Unique ID | `{id}-{type}` composite | Index-based | Different |

---

## Performance Comparison

| Aspect | V1 | V2 | Notes |
|--------|----|----|-------|
| Rendering | Server-side (getServerSideProps) | LiveView (server-rendered, client-updated) | V2 better for interactivity |
| Initial Load | Full page reload for each search | WebSocket patch for updates | V2 faster |
| Debounce | None (submit only) | 300ms | V2 prevents rapid requests |
| FTS5 Indexing | N/A | Available | V2 faster for prefix searches |
| Result Limit | None | 100 per entity type | V2 bounded |

---

## Summary

### V2 Enhancements
1. **FTS5 full-text search** with BM25 ranking for faster, more relevant results
2. **Relevance-based sorting** that prioritizes natural name matches
3. **Keyboard navigation** (arrow keys + Enter) for power users
4. **Real-time search** with 300ms debounce (no form submission required)
5. **Better UX** with empty state guidance, result counts, and sort indicators
6. **URL sync** via push_patch for bookmarkable searches

### V1 Features Not in V2
1. **Taxonomy description search** - V1 searches `taxonomy.description`, V2 only searches `name`
2. **Glossary word capitalization** - V1 capitalizes the first letter of glossary entries in display

### Behavioral Differences
1. **Query parameter name**: `searchText` (V1) vs `q` (V2)
2. **Whitespace handling**: V1 replaces spaces with `%` for wildcards
3. **Default sort**: V1 incorrectly defaults to `pubyear`, V2 uses relevance

### Recommendations

1. **Add taxonomy description search to V2** - Minor feature gap that could affect search discoverability
2. **Consider V1's space-to-wildcard behavior** - May be useful for multi-word searches like "quercus alba" finding variations
3. **Glossary capitalization** - Minor cosmetic difference, V2 could add if desired

### Status: Functionally Equivalent with V2 Enhancements

The V2 implementation provides all V1 functionality plus significant improvements in search relevance, performance, and user experience. The taxonomy description search gap is minor and could be addressed if needed.
