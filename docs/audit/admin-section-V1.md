# Admin Section - V1 vs V2 Comparison

## Overview

**V1**: Section Admin was a dedicated page at `/admin/section` (`v1/pages/admin/section.tsx`)
**V2**: Section management is integrated into Taxonomy Admin at `/admin/taxonomy` (`lib/gallformers_web/live/admin/taxonomy_live/`)

This document analyzes whether all V1 Section Admin functionality is available in V2's unified Taxonomy Admin.

---

## V1 Section Admin Analysis

### Route and Files

| Component | V1 Location |
|-----------|-------------|
| Page | `v1/pages/admin/section.tsx` (lines 1-259) |
| API - List/Search | `v1/pages/api/taxonomy/section/index.ts` (lines 1-39) |
| API - Get/Delete | `v1/pages/api/taxonomy/section/[id].ts` (lines 1-7) |
| API - Upsert | `v1/pages/api/taxonomy/upsert.ts` (lines 1-6) |
| DB Queries | `v1/libs/db/taxonomy.ts` (section-related functions) |
| Form Hook | `v1/hooks/useAdmin.tsx` |

### V1 Capabilities

#### 1. Section Selection/Search
- Async typeahead search for sections (`searchEndpoint: /api/taxonomy/section?q=`) (line 166)
- Lists all sections initially from `allSections()` (line 101, taxonomy.ts lines 267-278)
- Can create new sections inline via typeahead

#### 2. Form Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | Typeahead text | Yes | Main field for selection/creation |
| `description` | Textarea | Yes | "A short friendly name/description, e.g., Red Oaks" (lines 185-198) |
| `species` | Multi-select typeahead | Yes | Searches hosts via `/api/host?q=` (line 135) |

#### 3. Species Association
- Species are directly linked to sections via the `speciestaxonomy` join table
- Multi-select async typeahead to search/add host species (lines 202-234)
- Species must all be from the same genus (validation at line 51)
- Genus is auto-determined from the first species selected (line 51)

#### 4. CRUD Operations

| Operation | API Endpoint | Handler |
|-----------|--------------|---------|
| Create | `POST /api/taxonomy/upsert` | `upsertTaxonomy()` (taxonomy.ts lines 574-610) |
| Read | `GET /api/taxonomy/section?sectionid=N` | `sectionById()` (taxonomy.ts lines 474-497) |
| Update | `POST /api/taxonomy/upsert` | `upsertTaxonomy()` (taxonomy.ts lines 574-610) |
| Delete | `DELETE /api/taxonomy/:id` | `deleteTaxonomyEntry()` (taxonomy.ts lines 531-564) |
| Rename | Client-side rename + save | `renameSection()` (line 33-37) |

#### 5. Key Business Logic

**Creating/Updating a Section** (`upsertTaxonomy` at taxonomy.ts:574-610):
- Deletes all existing species-taxonomy links for this section
- Re-creates links for all species in the update
- Parent is auto-set to the genus of the first species

**Deleting a Section** (`deleteTaxonomyEntry` at taxonomy.ts:531-564):
- Cascading delete: removes species-taxonomy links
- Super admin required for delete (line 153)

**Species/Genus Relationship**:
- V1 enforces all species in a section must be from the same genus (UI message at lines 235-239)
- Parent genus is derived from first species (line 51)

---

## V2 Taxonomy Admin Analysis

### Route and Files

| Component | V2 Location |
|-----------|-------------|
| Index/List | `lib/gallformers_web/live/admin/taxonomy_live/index.ex` (lines 1-333) |
| Form (New/Edit) | `lib/gallformers_web/live/admin/taxonomy_live/form.ex` (lines 1-244) |
| Context | `lib/gallformers/taxonomy.ex` (lines 1-835) |
| Schema | `lib/gallformers/taxonomy/taxonomy.ex` (lines 1-61) |

### V2 Capabilities

#### 1. Listing/Filtering
- Lists all taxonomy types (family, genus, section) in one table (index.ex line 197)
- Type filter dropdown: Families, Genera, Sections (index.ex lines 196-198)
- Search by name (index.ex lines 183-190)
- Sortable columns: name, type, description, parent_name (index.ex lines 212-235)

#### 2. Form Fields (form.ex)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | Text input | Yes | (line 157) |
| `type` | Select dropdown | Yes | family/genus/section (lines 163-169) |
| `description` | Text input | No | (lines 173-179) |
| `parent_id` | Select dropdown | No | Dynamic options based on type (lines 183-204) |

#### 3. Parent Selection Logic (form.ex lines 64-79)
- For **families**: No parent options (top-level)
- For **genera**: Parent can be a family or section
- For **sections**: Parent must be a family

#### 4. CRUD Operations

| Operation | Context Function | Notes |
|-----------|------------------|-------|
| Create | `create_taxonomy/1` (taxonomy.ex lines 581-587) | Broadcasts `:taxonomy_created` |
| Read | `get_taxonomy!/1` (taxonomy.ex lines 67-69) | |
| Update | `update_taxonomy/2` (taxonomy.ex lines 593-598) | Broadcasts `:taxonomy_updated` |
| Delete | `delete_taxonomy/1` (taxonomy.ex lines 603-607) | **Currently disabled** (form.ex lines 107-118) |

---

## Comparison Table

| Aspect | V1 (Section Admin) | V2 (Taxonomy Admin) | Status | Notes |
|--------|-------------------|---------------------|--------|-------|
| **Route** | `/admin/section` | `/admin/taxonomy` (unified) | Different | V2 consolidates all taxonomy types |
| **Create Section** | Yes | Yes | Equivalent | Type = "section" |
| **Edit Section** | Yes | Yes | Equivalent | |
| **Delete Section** | Yes (super admin) | **NO** (disabled) | GAP | V2 disabled all taxonomy deletion (form.ex lines 107-118) |
| **Rename Section** | Yes (modal) | Yes (via name field) | Equivalent | No dedicated rename modal in V2 |
| **Name Field** | Async typeahead | Text input | Different | V2 simpler but loses typeahead search |
| **Description Field** | Required (textarea) | Optional (text) | Different | V1 required, V2 optional |
| **Type Selection** | Implicit (always section) | Explicit dropdown | Different | V2 more flexible |
| **Parent Selection** | Auto-derived from species | Explicit select | Different | V1 derived from species genus; V2 manual |
| **Species Assignment** | Multi-select typeahead | **NOT AVAILABLE** | GAP | Major missing feature |
| **Species Validation** | Must be same genus | N/A | GAP | V2 has no species-section linking UI |
| **View Species** | Shows linked species | N/A | GAP | No species list on section edit |
| **Search/Filter** | Async typeahead | Text search | Equivalent | |
| **Delete Warning** | Super admin warning | N/A | N/A | Deletion disabled in V2 |
| **Real-time Updates** | No | Yes (PubSub) | V2 Better | |

---

## Critical Gaps in V2

### 1. Species Assignment to Sections (CRITICAL GAP)

**V1 Behavior**:
- Sections have a multi-select typeahead to search and add host species (lines 202-234)
- Species are linked via `speciestaxonomy` join table
- All species in a section must be from the same genus

**V2 Status**:
- The form at `/admin/taxonomy/:id` has NO UI for managing species-section relationships
- The database schema still supports this (`speciestaxonomy` table exists)
- Context has `get_species_for_section/1` to fetch species (taxonomy.ex lines 760-773)
- But there's no UI to add/remove species from sections

**Impact**: Sections can be created but cannot have species assigned to them through the admin UI.

### 2. Taxonomy Deletion Disabled

**V1 Behavior**:
- Super admins could delete sections with a warning

**V2 Status**:
- All taxonomy deletion is disabled (form.ex lines 107-118)
- Message: "Taxonomy deletion is temporarily disabled. Deleting a family or genus can cascade to hundreds of species records. This will be re-enabled once soft delete is implemented."

**Impact**: Sections cannot be deleted at all (intentional temporary restriction).

### 3. Parent Auto-Derivation

**V1 Behavior**:
- Parent genus is automatically derived from the first species selected (line 51)

**V2 Status**:
- For sections, parent must be manually selected from a dropdown of families (form.ex lines 77-79)
- Uses `list_families_for_select/0` to populate options

**Impact**: Slightly different UX but functionally equivalent for manual section creation.

---

## Supporting V2 Functionality

### Public Section Page (Equivalent)

**V1**: `v1/pages/section/[id]/index.tsx`
**V2**: `lib/gallformers_web/live/section_live.ex`

Both implementations show:
- Section name with description
- List of species in the section
- Links to individual species (host) pages

V2 section_live.ex uses `Taxonomy.get_species_for_section/1` (line 63) which queries the `speciestaxonomy` table.

### Section-Related Context Functions (taxonomy.ex)

| Function | Line | Purpose |
|----------|------|---------|
| `list_sections/0` | 52-54 | List all sections |
| `list_sections_for_select/0` | 729-736 | Dropdown options |
| `list_sections_for_family/1` | 713-723 | Sections in a family |
| `get_species_for_section/1` | 760-773 | Species linked to section |
| `list_families_for_select/0` | 696-704 | Parent options for sections |
| `list_parents_for_genus/0` | 809-817 | Includes sections as parent options for genera |

These functions exist but the species-linking functionality is not exposed in the UI.

---

## Recommendations

### Must Fix Before Go-Live

1. **Add Species Assignment UI for Sections**
   - Add multi-select typeahead to section edit form
   - Similar to V1 implementation
   - Query hosts via search
   - Link/unlink via `speciestaxonomy` table

### Nice to Have

2. **Re-enable Taxonomy Deletion with Soft Delete**
   - Implement soft delete pattern
   - Allow section deletion for super admins
   - Show warning about cascading effects

3. **Improve Parent Selection UX**
   - Consider auto-populating parent based on species (like V1)
   - Or keep explicit selection but with better guidance

---

## Conclusion

V2 Taxonomy Admin **partially** covers V1 Section Admin functionality. The core CRUD operations for sections as taxonomy entries work, but the critical **species-section relationship management** is missing from the UI. This must be addressed before V2 can fully replace V1 for section administration.

| Category | Status |
|----------|--------|
| Basic Section CRUD | Covered (except delete) |
| Species Assignment | **NOT COVERED** |
| Section Listing/Search | Covered |
| Public Section Display | Covered |
