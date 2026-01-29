# Taxonomy Admin - V1 vs V2 Comparison

## Overview

| Aspect | V1 | V2 |
|--------|----|----|
| **Route** | `/admin/taxonomy` | `/admin/taxonomy` (list), `/admin/taxonomy/new`, `/admin/taxonomy/:id` |
| **Main File** | `v1/pages/admin/taxonomy.tsx` | `lib/gallformers_web/live/admin/taxonomy_live/index.ex`, `form.ex` |
| **Framework** | Next.js + React | Phoenix LiveView |
| **Architecture** | Single-page with inline editing | List + separate form pages |

## Summary

**V1**: Family-focused admin with inline editable genus table. Supports family CRUD, genus management via `EditableDataTable`, genus renaming via modal, and moving genera between families. Uses `useAdmin` hook for standard CRUD patterns. Single monolithic page with all operations.

**V2**: Unified taxonomy list (families, genera, sections) with separate create/edit form. Uses `FormHelpers` pattern for standard CRUD. Simpler flat list view with type filtering. **Missing**: Inline genus editing, genus move functionality, and genus rename modal.

---

## UI Layer Comparison

### V1 UI Components

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Main Admin Page | `v1/pages/admin/taxonomy.tsx` | 1-349 | Family CRUD with embedded genera table |
| EditableDataTable | `v1/components/EditableDataTable.tsx` | 1-246 | Inline editable data table for genera |
| MoveFamily Modal | `v1/components/movefamily.tsx` | 1-80 | Move genera to different family |
| RenameGenus Modal | `v1/components/renamegenus.tsx` | 1-106 | Rename a genus with validation |
| Admin Layout | `v1/libs/pages/admin.tsx` | - | Standard admin wrapper |
| useAdmin Hook | `v1/hooks/useAdmin.tsx` | 1-394 | CRUD patterns, form management |

**V1 UI Features:**
- Family name typeahead search (lines 276-279)
- Description dropdown for family type: gall/plant/etc (lines 281-289)
- Rename button for family (lines 291-303)
- Inline editable genera table with columns: Name, Friendly Name (lines 69-86)
- Add New genus button in table
- Custom actions: Rename, Move genera (lines 323-326)
- Delete confirmation dialog (lines 89-91)

### V2 UI Components

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Index (List) | `lib/gallformers_web/live/admin/taxonomy_live/index.ex` | 1-333 | Taxonomy list with search/filter |
| Form | `lib/gallformers_web/live/admin/taxonomy_live/form.ex` | 1-245 | Create/edit taxonomy entry |
| FormHelpers | `lib/gallformers_web/live/admin/form_helpers.ex` | 1-515 | Standard CRUD patterns |

**V2 UI Features:**
- Search input with debounce (lines 183-191 in index.ex)
- Type filter dropdown: Family/Genus/Section (lines 192-200)
- Sortable table columns: Name, Type, Description, Parent (lines 212-236)
- Pagination (lines 298-310)
- Type badges with color coding (lines 316-332)
- Action buttons: Edit, View public page, Delete (lines 267-286)
- Form page with type-conditional parent selector (lines 183-205 in form.ex)
- Help card explaining taxonomy hierarchy (lines 224-239 in form.ex)

### UI Status Table

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| List taxonomies | No (family-focused) | Yes | **V2 Better** | V2 shows all types in unified list |
| Search | Typeahead for families | Full-text search all types | **V2 Better** | V2 more comprehensive |
| Filter by type | Implicit (families only) | Explicit dropdown | **V2 Better** | V2 can filter families/genera/sections |
| Sorting | No | Yes (4 columns) | **V2 Better** | V2 has sortable columns |
| Pagination | No | Yes (50 per page) | **V2 Better** | V2 handles large datasets |
| Inline genus editing | Yes | No | **V1 Only** | Critical V1 feature missing |
| Move genera | Yes | No | **V1 Only** | Critical V1 feature missing |
| Rename genus | Yes (modal) | Edit form | **Parity** | V2 uses form approach |
| Delete confirmation | Yes | Disabled | **V1 Only** | V2 disabled pending soft delete |
| Help text | Minimal | Detailed help card | **V2 Better** | V2 explains hierarchy |
| Dirty state tracking | Via react-hook-form | Via FormHelpers | **Parity** | Both track unsaved changes |

---

## Business Logic Comparison

### V1 Business Logic

| Function | File | Lines | Purpose |
|----------|------|-------|---------|
| toUpsertFields | `v1/pages/admin/taxonomy.tsx` | 101-110 | Transform form to upsert payload |
| renameFamily | `v1/pages/admin/taxonomy.tsx` | 37-41 | Create renamed family object |
| move | `v1/pages/admin/taxonomy.tsx` | 148-173 | Move genera to new family |
| validateGenus | `v1/pages/admin/taxonomy.tsx` | 190-208 | Async genus name validation |
| genusNameExists | `v1/pages/admin/taxonomy.tsx` | 184-188 | Check genus name uniqueness |
| renameGenusCallback | `v1/pages/admin/taxonomy.tsx` | 210-216 | Update local genera after rename |
| updateGeneraFromTable | `v1/pages/admin/taxonomy.tsx` | 136-141 | Sync table changes to state |

**V1 Validation Rules:**
- Genus name cannot be empty (line 197-199)
- Genus name must be unique (line 202-205)
- Family must have description (line 285-287)

### V2 Business Logic

| Function | File | Lines | Purpose |
|----------|------|-------|---------|
| handle_event validate | `lib/gallformers_web/live/admin/taxonomy_live/form.ex` | 83-96 | Form validation with parent options |
| handle_event save | `lib/gallformers_web/live/admin/taxonomy_live/form.ex` | 105 | Delegates to FormHelpers |
| handle_event delete | `lib/gallformers_web/live/admin/taxonomy_live/form.ex` | 108-118 | Disabled with explanation |
| load_parent_options | `lib/gallformers_web/live/admin/taxonomy_live/form.ex` | 64-79 | Dynamic parent based on type |
| taxonomy_public_url | `lib/gallformers_web/live/admin/taxonomy_live/form.ex` | 126-129 | Generate public view URL |

**V2 Validation Rules:**
- Name required, 1-255 characters (`taxonomy.ex` line 53)
- Type required, must be family/genus/section (`taxonomy.ex` line 52)
- Name+type unique constraint (`taxonomy.ex` line 54)

### Business Logic Status Table

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| Family CRUD | Yes | Yes | **Parity** | Both support |
| Genus CRUD | Yes (inline) | Yes (form) | **Different Approach** | V1 inline, V2 separate form |
| Section CRUD | No (separate page) | Yes | **V2 Better** | V2 unified |
| Async name validation | Yes | No | **V1 Only** | V2 relies on changeset |
| Genus move | Yes | No | **V1 Only** | Critical missing feature |
| Cascade delete warning | Yes | Yes (disabled) | **V1 Only** | V2 delete disabled |
| Species name sync | Yes (line 628-641) | No | **V1 Only** | V1 updates species names on genus rename |
| Parent hierarchy rules | Implicit | Type-based | **V2 Better** | V2 explicit parent selection |
| PubSub real-time | No | Yes | **V2 Better** | V2 broadcasts changes |

---

## Data Layer Comparison

### V1 API Routes

| Route | File | Method | Purpose |
|-------|------|--------|---------|
| `/api/taxonomy/family` | `v1/pages/api/taxonomy/family/index.ts` | GET | List/search families |
| `/api/taxonomy/family/upsert` | `v1/pages/api/taxonomy/family/upsert.ts` | POST | Create/update family |
| `/api/taxonomy/family/[id]` | `v1/pages/api/taxonomy/family/[id].ts` | DELETE | Delete family |
| `/api/taxonomy/genus` | `v1/pages/api/taxonomy/genus/index.ts` | GET | List/search genera |
| `/api/taxonomy/genus/move` | `v1/pages/api/taxonomy/genus/move.ts` | POST | Move genera to new family |
| `/api/taxonomy/section` | `v1/pages/api/taxonomy/section/index.ts` | GET | List sections |

### V1 Database Functions (libs/db/taxonomy.ts)

| Function | Lines | Purpose |
|----------|-------|---------|
| allFamiliesWithGenera | 199-218 | Fetch all families with their genera |
| getGeneraForFamily | 454-472 | Get genera for a specific family |
| upsertFamily | 766-797 | Create or update family with genera |
| moveGenera | 799-829 | Move genera between families |
| deleteTaxonomyEntry | 531-565 | Cascade delete family and species |
| familySearch | 849 | Search families by name |
| generaSearch | 847 | Search genera by name |
| taxonomyEntryById | 81-92 | Fetch by ID |
| familyByName | 120-137 | Fetch family by name |

### V2 Context Functions (lib/gallformers/taxonomy.ex)

| Function | Lines | Purpose |
|----------|-------|---------|
| list_taxonomies | 16-18 | List all taxonomies |
| list_taxonomies_by_type | 24-30 | List by type |
| list_taxonomies_with_parent | 666-691 | List with parent info |
| get_taxonomy! | 68-69 | Get by ID (raise if not found) |
| create_taxonomy | 582-587 | Create with PubSub broadcast |
| update_taxonomy | 593-598 | Update with PubSub broadcast |
| delete_taxonomy | 604-607 | Delete with PubSub broadcast |
| search_taxonomies | 642-660 | Case-insensitive search |
| list_families_for_select | 696-704 | Dropdown options |
| list_parents_for_genus | 809-817 | Parent options for genus form |
| change_taxonomy | 573-576 | Create changeset |

### Data Layer Status Table

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| Basic CRUD | Yes | Yes | **Parity** | Both support |
| List with parent | Separate calls | Single query | **V2 Better** | V2 more efficient |
| Search | Contains match | LIKE pattern | **Parity** | Both case-insensitive |
| Transaction support | Yes (Prisma $transaction) | Yes (Ecto.Multi possible) | **Parity** | Both support |
| Cascade delete | Yes (raw SQL) | Simple Repo.delete | **Different** | V1 handles cascade manually |
| Move genera | Yes | No | **V1 Only** | Missing in V2 |
| Upsert with genera | Yes | No | **V1 Only** | V2 only creates one at a time |
| Real-time broadcast | No | Yes (PubSub) | **V2 Better** | V2 notifies subscribers |

---

## Gap Analysis

### Critical Missing in V2

1. **Genus Move Functionality** (V1: lines 143-173, 799-829)
   - V1 allows moving genera between families
   - Updates parent_id and taxonomytaxonomy relationships
   - Returns updated family list
   - **Impact**: Admin must delete and recreate genera to move them

2. **Inline Genus Editing** (V1: EditableDataTable)
   - V1 provides inline editable table for genus name/description
   - V2 requires navigating to separate form for each genus
   - **Impact**: Much slower workflow for managing genera

3. **Species Name Sync on Genus Rename** (V1: lines 628-641)
   - V1 updates species names when genus is renamed
   - `UPDATE species SET name = REPLACE(name, ...)`
   - **Impact**: Species names become inconsistent if genus renamed in V2

4. **Cascade Delete with Confirmation** (V1: lines 531-565)
   - V1 shows warning and performs cascade delete
   - V2 has delete disabled entirely
   - **Impact**: Cannot delete families/genera in V2

### Nice-to-Have in V2 Not in V1

1. **Unified Taxonomy List** - V2 shows all types in one view
2. **Sortable Columns** - V2 has 4 sortable columns
3. **Pagination** - V2 handles large datasets
4. **Type Filter** - V2 can filter by family/genus/section
5. **PubSub Updates** - V2 broadcasts changes
6. **Help Card** - V2 explains taxonomy hierarchy
7. **View Public Page** - V2 links to public view

---

## Recommendations

### High Priority

1. **Implement Move Genera Feature**
   - Add `/admin/taxonomy/move` modal or page
   - Create `Taxonomy.move_genera/3` context function
   - UI: select genera, pick destination family

2. **Add Inline Genus Editing or Bulk Edit**
   - Option A: Add inline editing to list page
   - Option B: Add "Edit Genera" sub-page under each family
   - Consider: LiveView hooks for inline editing

3. **Implement Species Name Sync**
   - When genus renamed, update all species in that genus
   - Add confirmation: "This will rename X species"

4. **Enable Delete with Soft Delete**
   - Implement soft delete pattern (deleted_at column)
   - Show cascade warning before delete
   - Allow recovery of deleted entries

### Medium Priority

5. **Add Genus Add Button in Family Context**
   - From family edit page, "Add Genus to this Family"
   - Pre-populate parent_id

6. **Batch Operations**
   - Select multiple genera, move/delete together
   - Import genera from CSV

### Low Priority

7. **Async Name Validation**
   - Real-time uniqueness check on name input
   - Currently only validates on submit

---

## File Reference

### V1 Files

| Path | Lines | Purpose |
|------|-------|---------|
| `v1/pages/admin/taxonomy.tsx` | 1-349 | Main admin page |
| `v1/components/EditableDataTable.tsx` | 1-246 | Inline editable table |
| `v1/components/movefamily.tsx` | 1-80 | Move genera modal |
| `v1/components/renamegenus.tsx` | 1-106 | Rename genus modal |
| `v1/hooks/useAdmin.tsx` | 1-394 | Admin CRUD hook |
| `v1/libs/db/taxonomy.ts` | 1-850 | Database operations |
| `v1/pages/api/taxonomy/family/index.ts` | 1-40 | Family API |
| `v1/pages/api/taxonomy/family/upsert.ts` | 1-7 | Family upsert API |
| `v1/pages/api/taxonomy/genus/index.ts` | 1-42 | Genus API |
| `v1/pages/api/taxonomy/genus/move.ts` | 1-12 | Genus move API |

### V2 Files

| Path | Lines | Purpose |
|------|-------|---------|
| `lib/gallformers_web/live/admin/taxonomy_live/index.ex` | 1-333 | List page |
| `lib/gallformers_web/live/admin/taxonomy_live/form.ex` | 1-245 | Create/edit form |
| `lib/gallformers/taxonomy.ex` | 1-835 | Context module |
| `lib/gallformers/taxonomy/taxonomy.ex` | 1-62 | Ecto schema |
| `lib/gallformers_web/live/admin/form_helpers.ex` | 1-515 | Form patterns |

---

## Summary Status

| Category | V1 Features | V2 Features | Gap |
|----------|-------------|-------------|-----|
| **List/Browse** | Family typeahead only | Full list, search, filter, sort, pagination | V2 better |
| **Family CRUD** | Full support | Full support | Parity |
| **Genus CRUD** | Inline editing | Separate form | V1 more convenient |
| **Genus Move** | Yes | No | Critical gap |
| **Genus Rename** | Modal with validation | Form edit | Parity |
| **Section CRUD** | Separate page | Unified | V2 better |
| **Delete** | Cascade with warning | Disabled | Gap |
| **Species Sync** | Auto-update names | No | Gap |
| **Real-time** | No | PubSub | V2 better |
| **Help/Docs** | Minimal | Help card | V2 better |

**Overall**: V2 has a more modern architecture with better list management, but is missing critical V1 features for genus management (move, inline edit, species sync). The V1 admin was designed for efficient bulk genus management within families, while V2 treats each taxonomy entry as a separate entity.
