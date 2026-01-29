# Admin Source Page: V1 vs V2 Comparison

## Overview

| Aspect | V1 | V2 |
|--------|----|----|
| **Route** | `/admin/source` | `/admin/sources` (index), `/admin/sources/new`, `/admin/sources/:id` |
| **Technology** | React + Next.js | Phoenix LiveView |
| **Architecture** | Single page with typeahead selection | Separate list and form pages |

---

## 1. UI Layer

### V1 Implementation

**File**: `v1/pages/admin/source.tsx` (lines 1-269)

**Layout Pattern**: Single-page admin with typeahead selector for CRUD operations.

**Key UI Elements**:
- **Title field**: AsyncTypeahead for searching/selecting existing sources or creating new (line 116)
- **Rename button**: Opens modal to rename selected source (lines 117-127)
- **Author field**: Text input, required (lines 133-144)
- **Publication Year**: Text input with 4-digit year validation (lines 147-163)
- **Reference Link**: Text input, required (lines 168-179)
- **License dropdown**: Select with three options - Public Domain/CC0, CC-BY, All Rights Reserved (lines 184-196)
- **License Link**: Text input, conditionally required for CC-BY (lines 200-218)
- **Citation**: Textarea with MLA format link, required (lines 222-239)
- **Data Complete checkbox**: Tracks if all source data has been entered (lines 241-251)
- **Save/Delete buttons**: Rendered via `useAdmin` hook (lines 102-106)

**Form State Management**: Uses `react-hook-form` via `useAdmin` hook (`v1/hooks/useAdmin.tsx`).

**Validation** (line 148-162, 202-208):
- Author: Required
- Publication year: Required, pattern `/([12][0-9]{3}$)/`
- Link: Required
- License: Required
- License link: Required when license is CC-BY
- Citation: Required

### V2 Implementation

**Files**:
- Index: `lib/gallformers_web/live/admin/source_live/index.ex` (lines 1-256)
- Form: `lib/gallformers_web/live/admin/source_live/form.ex` (lines 1-239)

**Layout Pattern**: Separate list page and form page (standard LiveView pattern).

**Index Page (list view)**:
- Search input with 300ms debounce (lines 104-111)
- "New Source" button linking to form (lines 114-116)
- Sortable table with columns: Title, Author, Year, Complete (lines 121-176)
- Action buttons per row: Edit, Map Species, View, Delete (lines 179-205)
- Truncated title/author display (lines 158, 162)

**Form Page**:
- Title input (lines 108-115)
- Author/Year side-by-side (lines 118-131)
- Reference Link URL input (lines 134-142)
- License dropdown with all CC license variants (lines 145-182)
- License Link - auto-filled for most CC licenses, editable for Public Domain and All Rights (lines 156-181)
- Citation textarea with MLA generator link (lines 185-206)
- Data Complete checkbox (lines 209-215)
- Delete button (edit mode only) with confirmation (lines 220-228)
- Cancel/Create|Save buttons via `form_actions` component (line 230)

**Form State Management**: Uses `GallformersWeb.Admin.FormHelpers` behaviour with standard CRUD helpers.

### UI Comparison Table

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| Source selection | AsyncTypeahead on same page | Separate list page with table | Different | V2 has better UX for browsing |
| List view | None (typeahead only) | Full table with sorting | V2 better | V2 merged browse functionality |
| Search | Typeahead search as you type | Dedicated search input | Equivalent | Both work similarly |
| Create new | Type new name in typeahead | "New Source" button + form | Different | V2 is clearer |
| Form layout | Single page | Dedicated form page | Different | V2 is more standard |
| Rename | Modal dialog | Edit title field directly | Different | V2 simpler approach |
| License options | 3 options | 8 options (all CC variants) | V2 better | V2 expanded license choices |
| License link auto-fill | None | Auto-fills for CC licenses | V2 better | Smart UX improvement |
| Dirty state tracking | Via react-hook-form | Via FormHelpers | Equivalent | Both track changes |
| Discard confirmation | Browser-native | Custom modal | V2 better | Better UX |
| Delete confirmation | Via useConfirmation hook | data-confirm attribute | Equivalent | Both confirm before delete |
| Real-time updates | None | PubSub subscription | V2 better | Multi-user collaboration |
| Pagination | None | 100-item limit | Partial | Neither has full pagination |

---

## 2. Business Logic

### V1 Implementation

**Hooks** (`v1/hooks/useAdmin.tsx`):
- `useAdmin` hook (lines 89-391): Generic admin form management
  - Form state via `react-hook-form`
  - Async typeahead search handling (lines 169-181)
  - Delete with confirmation dialog (lines 233-251)
  - Upsert handling via API calls (lines 323-328)
  - Rename flow with validation (lines 331-350)
  - Super admin check for delete permissions (line 107)

**Source-specific logic** (`v1/pages/admin/source.tsx`):
- `renameSource`: Simple title update (lines 21-25)
- `toUpsertFields`: Maps form fields to API format (lines 27-33)
- `updatedFormFields`: Populates form from selected source (lines 35-61)
- `createNewSource`: Template for new source (lines 63-73)

### V2 Implementation

**Context** (`lib/gallformers/sources.ex`, lines 1-377):
- `list_sources_paginated/2`: Paginated list query (lines 29-36)
- `search_sources/1`: Case-insensitive search on title/author (lines 79-90)
- `get_source!/1`: Load source by ID (lines 60-63)
- `create_source/1`: Insert with PubSub broadcast (lines 186-191)
- `update_source/2`: Update with PubSub broadcast (lines 197-202)
- `delete_source/1`: Delete with PubSub broadcast (lines 207-211)
- `subscribe/0`: PubSub subscription (lines 216-218)

**Schema** (`lib/gallformers/sources/source.ex`, lines 1-103):
- Required fields defined as module attribute (line 14)
- Implements `SchemaFields` behaviour for required field metadata
- License types sourced from `Licenses` module
- `normalize_empty_strings/2`: Handles NULL to empty string for licenselink (lines 69-76)
- `validate_license_link/1`: CC licenses (except CC0) require license link (lines 78-97)

**LiveView** (`lib/gallformers_web/live/admin/source_live/form.ex`):
- Uses `FormHelpers` behaviour with `crud_helpers: true` (line 6)
- Implements required callbacks: `entity_key`, `entity_struct`, `list_path`, etc. (lines 15-29)
- `prepare_params/1` override: Auto-fills license URL for read-only licenses (lines 33-41)

### Business Logic Comparison Table

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| Form validation | react-hook-form | Ecto changeset | Equivalent | Both validate required fields |
| Year validation | Regex pattern | Ecto format validation | Equivalent | Same pattern |
| License link validation | Custom validate function | Changeset validate | Equivalent | V2 expanded to all CC licenses |
| License URL auto-fill | None | `prepare_params/1` callback | V2 better | UX improvement |
| Super admin delete | Via session check | Not implemented | Gap | V2 missing role check |
| Name existence check | API endpoint | Not implemented | Gap | V2 allows duplicate titles (unique constraint will catch) |
| PubSub real-time | None | Full implementation | V2 better | Multi-user support |
| Search | API search endpoint | Context function | Equivalent | Both case-insensitive |

---

## 3. Data Layer

### V1 Implementation

**API Routes**:
- `v1/pages/api/source/index.ts` (lines 1-42): Search and fetch by species ID
- `v1/pages/api/source/upsert.ts` (lines 1-7): Create/update
- `v1/pages/api/source/[id].ts` (lines 1-5): Delete by ID
- `v1/pages/api/source/title/[title].ts` (lines 1-24): Check title existence

**Database Functions** (`v1/libs/db/source.ts`):
- `allSources()`: Get all sources ordered by title (lines 63-70)
- `searchSources(s)`: Search by title contains (lines 175-186)
- `getSourceByTitle(title)`: Exact title match (lines 188-198)
- `upsertSource(source)`: Prisma upsert (lines 142-173)
- `deleteSource(id)`: Raw SQL delete for cascade (lines 123-140)

**Type Definitions** (`v1/libs/api/apitypes.ts`):
- `SourceApi` (lines 170-180): id, title, author, pubyear, link, citation, datacomplete, license, licenselink
- `SourceUpsertFields` (lines 515-525): Same fields with Deletable mixin
- `ImageLicenseValues` enum (lines 300-305): PUBLIC_DOMAIN, CC_BY, ALL_RIGHTS

### V2 Implementation

**Schema** (`lib/gallformers/sources/source.ex`):
- Fields: title, author, pubyear, link, citation, datacomplete, license, licenselink (lines 29-36)
- Relationships: has_many images, has_many species_sources (lines 38-39)
- Changeset with full validation (lines 48-66)

**Context** (`lib/gallformers/sources.ex`):
- `list_sources/0`: All sources ordered by title (lines 18-23)
- `list_sources_paginated/2`: With limit/offset (lines 29-36)
- `search_sources/1`: SQLite-compatible case-insensitive search (lines 79-90)
- `get_source_by_title/1`: Exact match (lines 69-74)
- Standard CRUD: create/update/delete with PubSub broadcasts

**Licenses** (`lib/gallformers/licenses.ex`):
- 8 license types vs V1's 3 (lines 22-31)
- Canonical URL mapping (lines 10-19)
- `url_readonly?/1`: Determines if URL is editable (lines 95-99)

### Data Layer Comparison Table

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| ORM | Prisma | Ecto | Equivalent | Both handle CRUD |
| Schema fields | Same | Same | Match | No migration needed |
| License types | 3 | 8 | V2 expanded | More CC options |
| License URLs | Not stored | Can auto-fill | V2 better | Canonical URLs in code |
| Cascade delete | Raw SQL | Ecto constraint | Equivalent | Both handle cascade |
| Search | Title contains | Title + author LIKE | V2 better | More comprehensive |
| Pagination | None | Implemented | V2 better | Large dataset support |
| Type safety | TypeScript types | Ecto types + specs | Equivalent | Both type-safe |

---

## 4. Key Differences Summary

### Architecture
1. **V1**: Single-page with typeahead selector - edit in place
2. **V2**: Separate list and form pages - standard CRUD pattern

### Improvements in V2
1. **License expansion**: 8 licenses vs 3, covering all CC variants
2. **License URL auto-fill**: Smart UX that auto-fills canonical URLs
3. **Real-time updates**: PubSub enables multi-user collaboration
4. **Better list view**: Full table with sorting, search, action buttons
5. **Discard confirmation**: Custom modal vs browser native
6. **FormHelpers abstraction**: Reusable pattern across admin forms

### Missing in V2
1. **Super admin delete protection**: V1 restricts delete to super admins
2. **Name existence check**: V1 explicitly checks before rename (V2 relies on DB constraint)

---

## 5. File Reference

### V1 Files
| File | Lines | Purpose |
|------|-------|---------|
| `v1/pages/admin/source.tsx` | 1-269 | Admin page component |
| `v1/hooks/useAdmin.tsx` | 1-394 | Generic admin form hook |
| `v1/libs/pages/admin.tsx` | 1-225 | Admin layout component |
| `v1/pages/api/source/index.ts` | 1-43 | Search/fetch API |
| `v1/pages/api/source/upsert.ts` | 1-7 | Upsert API |
| `v1/pages/api/source/[id].ts` | 1-5 | Delete API |
| `v1/pages/api/source/title/[title].ts` | 1-24 | Title check API |
| `v1/libs/db/source.ts` | 1-199 | Database functions |
| `v1/libs/api/apitypes.ts` | 170-180, 300-305, 515-525 | Type definitions |

### V2 Files
| File | Lines | Purpose |
|------|-------|---------|
| `lib/gallformers_web/live/admin/source_live/index.ex` | 1-256 | List page LiveView |
| `lib/gallformers_web/live/admin/source_live/form.ex` | 1-239 | Form page LiveView |
| `lib/gallformers/sources.ex` | 1-377 | Sources context |
| `lib/gallformers/sources/source.ex` | 1-103 | Source schema |
| `lib/gallformers/licenses.ex` | 1-107 | License definitions |
| `lib/gallformers_web/live/admin/form_helpers.ex` | 1-515 | Form helpers behaviour |
| `lib/gallformers_web/live/admin/form_components.ex` | 1-158 | Shared form components |

---

## 6. Recommendations

### High Priority
1. **Add super admin check for delete**: V1 restricts delete to super admins to prevent accidental data loss. V2 should add similar protection in `handle_delete/2`.

### Medium Priority
2. **Add title uniqueness check UX**: While V2 has a DB constraint, adding an explicit check with user feedback (like V1's `nameExistsEndpoint`) would improve UX.

### Low Priority
3. **Consider pagination**: V2 has `list_sources_paginated` but the index page loads 100 sources. Consider cursor-based pagination for large datasets.
4. **Sortable columns server-side**: V2 sorts in memory. For large datasets, consider server-side sorting.

### Already Complete
- License expansion (8 types)
- Real-time updates via PubSub
- List/browse view merged into index page
- Form dirty state tracking
- Discard confirmation modal
