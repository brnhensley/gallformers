# Admin Species-Source: V1 vs V2 Comparison

## Overview

The Species-Source admin page manages the many-to-many relationship between species (galls/hosts) and their scientific source references. Each mapping can include a description (what the source says about the species), an external link (e.g., BHL page), and a "use as default" flag.

## V1 Implementation

**Route**: `/admin/speciessource?id={speciesId}`
**Primary File**: `v1/pages/admin/speciessource.tsx` (lines 1-446)

### Architecture

V1 uses a single-page workflow centered on selecting a species first, then managing its source mappings.

#### UI Layer

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Page component | `v1/pages/admin/speciessource.tsx` | 64-429 | Main admin page with species-centric workflow |
| Admin wrapper | `v1/libs/pages/admin.tsx` | 61-224 | Shared admin layout with navigation tabs |
| Picker modal | `v1/components/picker.tsx` | 1-56 | Modal for selecting a new source to map |
| useAdmin hook | `v1/hooks/useAdmin.tsx` | 89-391 | Shared admin state management and CRUD |
| Typeahead | react-bootstrap-typeahead | - | Species picker and source picker components |

**Key UI Elements**:
- Species Typeahead picker at top (lines 293-296)
- Mapped sources dropdown (lines 308-330)
- "Add New Mapped Source" button that opens Picker modal (lines 338-339)
- Description textarea with Edit/Preview tabs using ReactMarkdown (lines 348-371)
- External link text input (lines 373-384)
- "Use as Default?" checkbox (lines 385-395)
- Shortcuts to edit species or manage images (lines 408-425)

#### Business Logic

| Function | File | Lines | Purpose |
|----------|------|-------|---------|
| fetchSources | `v1/pages/admin/speciessource.tsx` | 52-62 | Fetch sources mapped to a species via API |
| toUpsertFields | `v1/pages/admin/speciessource.tsx` | 70-81 | Convert form data to API insert format |
| updatedFormFields | `v1/pages/admin/speciessource.tsx` | 83-132 | Update form when species selection changes |
| onSubmit | `v1/pages/admin/speciessource.tsx` | 187-257 | Custom submit handling for upsert/delete |
| addMappedSource | `v1/pages/admin/speciessource.tsx` | 163-185 | Add a new source mapping to local state |
| sourceToDisplay | `v1/libs/pages/renderhelpers.tsx` | 95-96 | Format source for display: `author: (year) title` |
| defaultSource | `v1/libs/pages/renderhelpers.tsx` | 41-56 | Find the default source for a species |

**Form Fields** (FormFields type, lines 39-44):
- `mainField: SimpleSpecies[]` - Selected species
- `sources: SpeciesSourceApi[]` - Mapped sources
- `description: string` - Description text (markdown)
- `externallink: string` - Direct link to source page
- `useasdefault: boolean` - Is this the default source

#### Data Layer

| Function | File | Lines | Purpose |
|----------|------|-------|---------|
| sourcesBySpecies | `v1/libs/db/speciessource.ts` | 34-45 | Get all sources for a species with Prisma |
| speciesSourceByIds | `v1/libs/db/speciessource.ts` | 18-32 | Get specific mapping by species+source IDs |
| deleteSpeciesSourceByIds | `v1/libs/db/speciessource.ts` | 47-87 | Delete a mapping using fp-ts TaskEither |
| upsertSpeciesSource | `v1/libs/db/speciessource.ts` | 89-134 | Upsert with transaction for default flag |
| allSpeciesSimple | `v1/libs/db/species.ts` | - | Get all species for picker (loaded SSR) |
| allSources | `v1/libs/db/source.ts` | - | Get all sources for picker (loaded SSR) |

**API Routes**:

| Route | File | Method | Purpose |
|-------|------|--------|---------|
| `/api/speciessource?speciesid={id}` | `v1/pages/api/speciessource/index.ts` | GET | Get all sources for a species |
| `/api/speciessource?speciesid={}&sourceid={}` | `v1/pages/api/speciessource/index.ts` | GET | Get specific mapping |
| `/api/speciessource?speciesid={}&sourceid={}` | `v1/pages/api/speciessource/index.ts` | DELETE | Delete a mapping |
| `/api/speciessource/upsert` | `v1/pages/api/speciessource/upsert.ts` | POST | Create or update a mapping |

**Database Table**: `speciessource`
- `id` - Primary key
- `species_id` - FK to species
- `source_id` - FK to source
- `description` - Markdown text
- `useasdefault` - Integer (0/1)
- `externallink` - URL string
- `alias_id` - FK to alias (optional, for name-specific citations)

---

## V2 Implementation

**Routes**:
- `/admin/species-sources/add` (Add from Source)
- `/admin/species-sources/find` (Quick Find)

**Primary Files**:
- `lib/gallformers_web/live/admin/species_source_live/add_from_source.ex`
- `lib/gallformers_web/live/admin/species_source_live/quick_find.ex`

### Architecture

V2 splits the functionality into two optimized workflows:
1. **Add from Source** - Source-first workflow for bulk adding species to a source
2. **Quick Find** - Search-based workflow for editing existing mappings

#### UI Layer

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| AddFromSource LiveView | `add_from_source.ex` | 1-567 | Bulk-add species from a source |
| QuickFind LiveView | `quick_find.ex` | 1-418 | Search and edit existing mappings |
| Typeahead component | `form_components.ex` | - | Reusable typeahead for species picker |
| Admin layout | `Layouts.admin` | - | Shared admin layout wrapper |

**AddFromSource UI Elements** (lines 324-565):
- Source search/picker with clear button (lines 344-405)
- Already-mapped species list with edit capability (lines 409-435)
- Species typeahead for adding new mappings (lines 437-458)
- Mapping form with description, external link, checkbox (lines 460-558)
- "Save & Add Another" and "Save & Done" buttons (lines 537-555)
- Delete button for existing mappings (lines 526-535)

**QuickFind UI Elements** (lines 231-416):
- Search input for species name, source title, author, or description (lines 249-261)
- Results list with inline edit expansion (lines 264-395)
- Edit form with description, external link, checkbox (lines 328-392)
- Delete button (lines 367-374)

#### Business Logic

**AddFromSource** (lines 107-319):
| Function | Lines | Purpose |
|----------|-------|---------|
| handle_event("search_sources") | 110-119 | Search sources by title/author |
| handle_event("select_source") | 122-126 | Select a source and load mapped species |
| handle_event("search_species") | 140-149 | Search species for adding |
| handle_event("select_species") | 152-178 | Select species, check for existing mapping |
| handle_event("edit_existing") | 181-201 | Edit an existing mapped species |
| handle_event("save") | 228-232 | Save mapping with add_another or done action |
| save_mapping | 260-293 | Create or update the mapping |
| load_species_form | 76-105 | Initialize form for new or existing mapping |

**QuickFind** (lines 84-217):
| Function | Lines | Purpose |
|----------|-------|---------|
| handle_event("search") | 84-101 | Search mappings by multiple fields |
| handle_event("edit") | 105-127 | Open inline edit form for a result |
| handle_event("cancel_edit") | 131-136 | Close edit form without saving |
| handle_event("validate") | 139-157 | Validate form changes |
| handle_event("save") | 161-189 | Save the mapping |
| handle_event("delete") | 193-210 | Delete the mapping |

**URL Parameter Support**:
- QuickFind: `?species_id=X&source_id=Y` - Pre-select a specific mapping
- QuickFind: `?q=search` - Pre-populate search query
- AddFromSource: `?source_id=X` - Pre-select a source

#### Data Layer

| Function | File | Lines | Purpose |
|----------|------|-------|---------|
| search_sources | `sources.ex` | 79-90 | Search sources by title/author |
| get_source | `sources.ex` | 52-55 | Get source by ID |
| get_species_for_source | `sources.ex` | 143-158 | Get all species mapped to a source |
| search_species | `species.ex` | - | Search species by name |
| get_species_source_by_ids | `sources.ex` | 262-267 | Get mapping by species+source IDs |
| create_species_source | `sources.ex` | 273-278 | Create a new mapping |
| update_species_source | `sources.ex` | 285-290 | Update an existing mapping |
| delete_species_source | `sources.ex` | 297-300 | Delete a mapping |
| change_species_source | `sources.ex` | 238-240 | Build changeset for validation |
| search_species_source_mappings | `sources.ex` | 318-348 | Search across species, source, description |
| get_species_source_for_edit | `sources.ex` | 354-376 | Get mapping with full details for editing |

**Schema**: `lib/gallformers/species/species_source.ex` (lines 1-58)
- Required fields: `species_id`, `source_id`
- Optional fields: `description`, `useasdefault`, `externallink`, `alias_id`
- Unique constraint on `[species_id, source_id]`

**PubSub Events**:
- `:species_source_created`
- `:species_source_updated`
- `:species_source_deleted`

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Primary Workflow** | Species-first (select species, manage its sources) | Split: Source-first bulk add + Search-based edit | Enhanced | V2 optimizes for two common use cases |
| **Route** | `/admin/speciessource` | `/admin/species-sources/add`, `/admin/species-sources/find` | Changed | V2 uses cleaner URL naming |
| **Species Selection** | Typeahead with all species loaded SSR | Typeahead with live search | Enhanced | V2 avoids loading all species upfront |
| **Source Selection** | Dropdown of mapped sources + modal picker | Typeahead search | Enhanced | V2 is more consistent and faster |
| **Bulk Add Workflow** | Not optimized - must re-select species each time | "Save & Add Another" keeps source locked | Enhanced | V2 dramatically improves bulk entry |
| **Search Existing** | Must know species first | Search by species, source, author, or description | Enhanced | V2 adds powerful search |
| **Inline Editing** | N/A | Click result to expand inline form | Enhanced | V2 has smoother UX |
| **Deep Links** | `?id={speciesId}` | `?species_id=X&source_id=Y`, `?q=search`, `?source_id=X` | Enhanced | V2 supports more linking options |
| **Markdown Preview** | ReactMarkdown with tabs | Not implemented | Missing | V2 lacks markdown preview for description |
| **Description Field** | Textarea with Edit/Preview tabs | Plain textarea | Partial | V2 missing preview functionality |
| **External Link** | Text input | URL input with validation | Enhanced | V2 uses proper URL input type |
| **Use as Default** | Checkbox | Checkbox | Parity | Same functionality |
| **Shortcut Links** | Links to edit species, manage images | Not implemented | Missing | V2 lacks navigation shortcuts |
| **Delete Confirmation** | useConfirmation hook with modal | Browser `data-confirm` attribute | Simplified | V2 uses simpler native confirm |
| **Validation** | React Hook Form | LiveView changeset | Equivalent | Both validate properly |
| **Error Display** | Alert component in Admin wrapper | Flash messages | Simplified | V2 uses standard Phoenix pattern |
| **Real-time Updates** | N/A | PubSub broadcasts | Enhanced | V2 supports multi-user scenarios |
| **Default Flag Handling** | Transaction to clear other defaults | Not implemented | Missing | V2 may allow multiple defaults |
| **SSR Data Loading** | `getServerSideProps` loads all species/sources | On-demand search queries | Enhanced | V2 is more scalable |
| **State Management** | useAdmin hook + useState | LiveView assigns | Different | Both work well for their framework |
| **Navigation Context** | Admin navbar with all admin sections | Back link to sources only | Reduced | V2 has less cross-navigation |

---

## Detailed Findings

### V2 Improvements

1. **Workflow Optimization**: V2 splits the page into two purpose-built interfaces:
   - **Add from Source** is optimized for "I have a paper and want to document all species in it"
   - **Quick Find** is optimized for "I need to fix a specific mapping"

2. **Scalability**: V2 avoids loading all species/sources upfront, using live search instead

3. **Better Search**: V2's `search_species_source_mappings` searches across species name, source title, author, AND description text

4. **URL Parameters**: V2 supports more flexible deep linking for external tools

5. **PubSub Integration**: Changes broadcast to other connected clients

### V2 Gaps

1. **Markdown Preview**: V1 has a two-tab interface for editing and previewing markdown descriptions. V2 only has a plain textarea with a note "Supports Markdown formatting" but no preview.

2. **Default Flag Transaction**: V1's `upsertSpeciesSource` uses a transaction to ensure only one source is marked as default per species. V2's implementation does not appear to handle this - setting a new default won't automatically clear others.

3. **Navigation Shortcuts**: V1 has links to "Edit the Species" and "Add/Edit Images for this Species" that are missing in V2.

4. **Cross-Admin Navigation**: V1's Admin component has a full navbar across all admin sections. V2 only has a "Back to Sources" link.

5. **No Species-First Entry Point**: Users who want to manage all sources for a specific species must use Quick Find and search by species name, rather than having a dedicated species-first view.

---

## Recommendations

### High Priority

1. **Add markdown preview** to the description field in both V2 LiveViews. Use the existing markdown rendering approach from species detail pages.

2. **Implement default flag transaction logic** in `Sources.update_species_source/2` and `Sources.create_species_source/1` to clear other defaults when setting a new one.

3. **Add navigation shortcuts** to V2 forms - links to edit the species and manage images.

### Medium Priority

4. **Consider adding a species-first entry point** that shows all sources for a selected species, similar to V1's approach. Could be a third route like `/admin/species-sources/by-species`.

5. **Add cross-admin navigation** - at minimum breadcrumbs or a navigation dropdown.

### Low Priority

6. **Consolidate confirmation dialogs** - decide whether to use browser native confirms or a modal component consistently across admin pages.

---

## File Reference

### V1 Files
- `v1/pages/admin/speciessource.tsx` - Main page component
- `v1/libs/pages/admin.tsx` - Admin layout wrapper
- `v1/components/picker.tsx` - Modal picker component
- `v1/hooks/useAdmin.tsx` - Shared admin hook
- `v1/libs/db/speciessource.ts` - Database functions
- `v1/pages/api/speciessource/index.ts` - API route (GET, DELETE)
- `v1/pages/api/speciessource/upsert.ts` - API route (POST)
- `v1/libs/pages/renderhelpers.tsx` - Display helpers
- `v1/libs/api/apitypes.ts` - TypeScript types (lines 187-194, 527-534)

### V2 Files
- `lib/gallformers_web/live/admin/species_source_live/add_from_source.ex` - Add from source LiveView
- `lib/gallformers_web/live/admin/species_source_live/quick_find.ex` - Quick find LiveView
- `lib/gallformers/sources.ex` - Context module with species-source functions (lines 230-376)
- `lib/gallformers/species/species_source.ex` - Ecto schema
- `lib/gallformers_web/router.ex` - Routes (lines 83-84)
