# Admin Gall Page Comparison: V1 vs V2

**Route**: `/admin/gall` (V1), `/admin/galls` and `/admin/galls/:id` (V2)
**Analysis Date**: 2026-01-28

## Executive Summary

The Admin Gall page is a complex CRUD form for managing gall entries with extensive morphological attributes, taxonomy associations, host relationships, and aliases. V2 provides a complete re-implementation with improved architecture, better state management, and enhanced UX patterns.

---

## File Inventory

### V1 Files
| File | Purpose | Lines |
|------|---------|-------|
| `v1/pages/admin/gall.tsx` | Main gall admin page component | 654 |
| `v1/components/UndescribedFlow.tsx` | Modal for creating undescribed galls | 310 |
| `v1/hooks/useAdmin.tsx` | Generic admin form hook | 394 |
| `v1/hooks/useSpecies.tsx` | Species-specific form logic | ~200 |
| `v1/libs/db/gall.ts` | Gall database operations | 759 |
| `v1/libs/pages/admin.tsx` | Admin page wrapper component | 225 |
| `v1/pages/api/gall/index.ts` | Search/fetch API | 40 |
| `v1/pages/api/gall/upsert.ts` | Create/update API | 7 |
| `v1/pages/api/gall/[id].ts` | Delete API | 6 |

### V2 Files
| File | Purpose | Lines |
|------|---------|-------|
| `lib/gallformers_web/live/admin/gall_live/index.ex` | Gall list view | 184 |
| `lib/gallformers_web/live/admin/gall_live/form.ex` | Gall edit form | 1404 |
| `lib/gallformers_web/live/admin/gall_live/undescribed.ex` | Undescribed gall flow | 500 |
| `lib/gallformers_web/live/admin/form_helpers.ex` | Shared form utilities | 515 |
| `lib/gallformers_web/live/admin/deferred_changes.ex` | Change tracking module | 248 |
| `lib/gallformers/species.ex` | Species context (gall operations) | ~1200 |
| `lib/gallformers/species/gall.ex` | Gall schema | 90 |
| `lib/gallformers/species/gall_species.ex` | Gall-Species join schema | 41 |

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Framework** | Next.js + React | Phoenix LiveView | Complete | Full rewrite in Elixir |
| **State Management** | useState + react-hook-form | LiveView assigns + DeferredChanges | Complete | V2 has explicit change tracking |
| **List View** | Inline in main page | Separate `index.ex` | Enhanced | V2 has dedicated list with search |
| **Edit Form** | Single component | Separate `form.ex` | Enhanced | Better separation of concerns |
| **Undescribed Flow** | Modal component | Separate page | Enhanced | V2 uses URL params for handoff |
| **Typeahead Search** | react-bootstrap-typeahead | Custom `.typeahead` component | Complete | V2 uses ARIA-accessible component |
| **Form Validation** | react-hook-form + yup | Ecto changesets | Complete | V2 has server-side validation |
| **API Layer** | REST APIs with axios | LiveView events | Complete | No separate API needed |
| **Transaction Handling** | Prisma $transaction | Ecto.Repo.transaction | Complete | Both use atomic transactions |
| **Dirty State Tracking** | isDirty from form lib | Custom `form_dirty` assign | Complete | V2 has discard confirmation modal |
| **Delete Confirmation** | useConfirmation hook | data-confirm attribute | Complete | V2 uses browser confirm |
| **Rename Modal** | EditName component | Custom modal in form | Complete | V2 integrates rename into form |
| **PubSub Updates** | Not implemented | Phoenix.PubSub | Enhanced | V2 has real-time updates |
| **Error Handling** | Alert component + toast | Flash messages | Complete | Both handle errors appropriately |

---

## UI Layer Analysis

### V1 UI Components (`v1/pages/admin/gall.tsx`)

**Main Form Structure (lines 294-622)**:
- `<Admin>` wrapper handles auth, nav tabs, save/delete buttons
- AsyncTypeahead for gall search/create (line 339-343)
- Genus/Family typeaheads (lines 362-438)
- Hosts AsyncTypeahead with multi-select (lines 441-470)
- Filter field typeaheads via `createGallPropertyField()` helper (lines 265-292)
- Detachable dropdown (lines 473-514)
- AliasTable component (lines 560-577)
- Checkboxes for datacomplete and undescribed (lines 579-619)

**UndescribedFlow Modal (`v1/components/UndescribedFlow.tsx`)**:
- Modal-based workflow (lines 132-306)
- Genus/Family conditional display (lines 161-223)
- Host typeahead search (lines 225-243)
- Auto-generated name from genus + host + description (lines 108-116)
- Validates name doesn't already exist (lines 76-91)

### V2 UI Components (`lib/gallformers_web/live/admin/gall_live/form.ex`)

**Form Structure (lines 1004-1402)**:
- `Layouts.admin` wrapper with admin navigation
- `Layouts.admin_edit_layout` for consistent edit page structure
- Typeahead for gall search/create with allow_new (lines 1068-1086)
- Read-only genus with genus_is_new indicator (lines 1099-1113)
- Family selection (editable when genus is new) (lines 1114-1142)
- `.multi_select_dropdown` for hosts with search (lines 1146-1171)
- Grid layout for filter fields (lines 1173-1338)
- `.alias_editor` component (line 1341-1345)
- Checkboxes for datacomplete and undescribed (lines 1348-1364)
- `.form_actions` for save/cancel with dirty state awareness (line 1379)
- `.rename_modal` for renaming (lines 1393-1398)
- `.discard_confirm_modal` for unsaved changes (line 1390)

**Undescribed Flow Page (`lib/gallformers_web/live/admin/gall_live/undescribed.ex`)**:
- Standalone page instead of modal (better UX for complex flow)
- Genus known checkbox toggle (lines 70-82)
- Conditional genus/family typeaheads (lines 84-129)
- Host typeahead (lines 131-148)
- Auto-generated name with manual edit option (lines 165-179)
- Validates name uniqueness before continue (lines 385-412)
- Navigates to form with URL params (line 410)

### Key UI Differences

1. **List View**: V2 has a dedicated list page with search, action buttons for edit/images/hosts/sources/view/delete. V1 only has inline search.

2. **Layout**: V2 uses consistent admin layout components. V1 uses Bootstrap grid.

3. **Filter Fields**: V2 uses `.multi_select_dropdown` component with unified API. V1 uses raw Typeahead with custom wrapper function.

4. **Undescribed Flow**: V2 uses separate page with URL params for handoff. V1 uses modal that passes data via callback.

5. **Rename**: V2 has integrated rename modal with "add old name as alias" option. V1 uses separate EditName component.

---

## Business Logic Analysis

### V1 Business Logic

**useAdmin Hook (`v1/hooks/useAdmin.tsx`)**:
- Generic admin CRUD operations (lines 89-391)
- Form state management via react-hook-form
- Delete with confirmation dialog (lines 233-251)
- Rename callback with validation (lines 331-350)
- Name exists check via API (lines 352-360)

**Form Submission (`v1/pages/admin/gall.tsx:208-244`)**:
- Checks for unknown genus needing creation (lines 220-229)
- Warns if Unknown genus/family but not marked undescribed (lines 232-241)
- Delegates to adminForm.formSubmit

**toUpsertFields (`v1/pages/admin/gall.tsx:92-114`)**:
- Converts form fields to API upsert format
- Extracts IDs from filter field objects
- Includes taxonomy (fgs), hosts, and all morphology attributes

### V2 Business Logic

**Form Event Handlers (`lib/gallformers_web/live/admin/gall_live/form.ex`)**:
- `handle_event("validate", ...)` - Real-time validation (lines 429-443)
- `handle_event("save", ...)` - Validates family selection, dispatches to save_gall (lines 445-459)
- `handle_event("search_gall", ...)` - Typeahead search (lines 390-404)
- `handle_event("select_gall", ...)` - Navigate to edit URL (lines 406-411)
- `handle_event("create_gall", ...)` - Initialize new gall state (lines 413-417)

**DeferredChanges Module (`lib/gallformers_web/live/admin/deferred_changes.ex`)**:
- `init/2` - Initialize original + pending state (lines 49-57)
- `add_pending/4` - Add item with temp negative ID (lines 77-92)
- `remove_pending/4` - Remove by ID (lines 106-114)
- `exists?/4` - Check for duplicates (lines 131-135)
- `compute_changes/3` - Calculate to_add/to_remove sets (lines 157-184)
- `refresh/3` - Reset state after save (lines 197-204)

**Save Logic (`lib/gallformers_web/live/admin/gall_live/form.ex:804-922`)**:
- `save_gall(:new, ...)` - Creates in transaction (lines 804-867):
  1. Create species record
  2. Create gall record
  3. Link taxonomy (create Unknown genus if needed)
  4. Add hosts
  5. Add aliases
  6. Add filter values
  7. Set gall properties (detachable, undescribed)
- `save_gall(:edit, ...)` - Updates in transaction (lines 869-922):
  1. Update species
  2. Save alias changes (add/remove)
  3. Save host changes (add/remove)
  4. Save filter changes
  5. Save gall properties

**FormHelpers Module (`lib/gallformers_web/live/admin/form_helpers.ex`)**:
- Dirty state tracking (lines 151-171)
- Discard confirmation flow (lines 176-196)
- Species name validation (lines 216-218)
- CRUD helper pattern for simpler forms

---

## Data Layer Analysis

### V1 Data Layer (`v1/libs/db/gall.ts`)

**getGalls Query (lines 86-275)**:
- Complex Prisma include with all associations
- Joins: species, abundance, hosts, speciessource, image, speciestaxonomy, aliasspecies, places
- Gall-specific: gallalignment, gallcells, gallcolor, gallseason, galllocation, galltexture, gallshape, gallwalls, gallform
- Adapts DB results to API types via clean() function

**Gall Create (lines 615-647)**:
- `gallCreateSteps()` returns PrismaPromise array
- Creates species with taxontype connection
- Creates nested gall via gallspecies
- Creates all filter field associations

**Gall Update (lines 649-713)**:
- `gallUpdateSteps()` returns PrismaPromise array
- Updates species data
- Updates gall properties via nested update
- Deletes and recreates filter associations (deleteMany + create pattern)
- Updates hosts via delete + create
- Updates abundance separately

**upsertGall (lines 720-736)**:
- Wraps create/update in $transaction
- Returns updated gall after save

**deleteGall (lines 738-758)**:
- Deletes images first via S3
- Uses raw SQL for cascade delete

### V2 Data Layer (`lib/gallformers/species.ex`)

**get_gall_for_admin_edit (lines 966-981)**:
- Fetches gall data with filter_values map
- Uses get_gall_by_id for base data
- Merges filter values from get_gall_filter_values

**create_gall_for_species (lines 1177-1193)**:
- Creates gall record with defaults
- Creates gallspecies join record
- Returns {:ok, gall} tuple

**update_gall_properties (lines 1079-1089)**:
- Simple update of detachable/undescribed
- Returns {:ok, gall} or {:error, reason}

**Filter Field Operations (lines 1091-1175)**:
- `add_filter_field_to_gall/3` - Insert into join table
- `remove_filter_field_from_gall/3` - Delete from join table
- `get_gall_filter_values/1` - Fetch all filter values grouped by type

**Host Operations** (in `lib/gallformers/hosts.ex`):
- `get_hosts_for_gall/1` - Returns host associations
- Species context has add/remove host functions

**Alias Operations** (in species.ex):
- `get_aliases_for_species/1`
- `create_alias_for_species/2`
- `remove_alias_from_species/2`

### Schema Definitions

**V1 Types** (`v1/libs/api/apitypes.ts`):
- GallApi - Full gall with all associations
- GallUpsertFields - Fields for create/update
- FilterField - Generic {id, field} type

**V2 Schemas**:
- `Gallformers.Species.Gall` - Gall entity with many_to_many filter associations
- `Gallformers.Species.GallSpecies` - Join table schema
- Filter field schemas in `Gallformers.FilterFields.*`

---

## Parity Assessment

### Complete Features (V2 matches or exceeds V1)
- [x] Search existing galls by name/alias
- [x] Create new gall with binomial name
- [x] Auto-populate genus from species name
- [x] Family selection (editable for new genus)
- [x] Host associations (multi-select with search)
- [x] All filter fields (color, shape, texture, alignment, walls, cells, location, form, season)
- [x] Detachable dropdown
- [x] Abundance selection
- [x] Alias management (add/remove)
- [x] Datacomplete checkbox
- [x] Undescribed checkbox
- [x] Undescribed flow (genus/family, host, auto-name)
- [x] Rename with optional alias creation
- [x] Delete with confirmation
- [x] Transaction-based saves
- [x] Form validation
- [x] Error handling

### Enhanced in V2
- [x] Dedicated list view with search and bulk actions
- [x] Real-time updates via PubSub
- [x] Discard confirmation for unsaved changes
- [x] URL-based navigation (bookmarkable edit URLs)
- [x] Explicit change tracking (DeferredChanges)
- [x] Better separation of concerns (form.ex vs index.ex)
- [x] Consistent admin layout components
- [x] ARIA-accessible typeahead components

### Potential Gaps (Verify in Testing)
- [ ] Unknown genus warning (V1 warns if Unknown but not undescribed) - V2 may silently allow
- [ ] Related galls link (V1 links to gallhost page from gall form)
- [ ] Super admin restrictions (V1 has isSuperAdmin checks)

---

## Recommendations

### High Priority
1. **Verify Unknown Genus Warning**: V1 shows confirmation if genus/family is "Unknown" but undescribed is unchecked. Ensure V2 has equivalent validation.

### Medium Priority
2. **Add Super Admin Checks**: Some V1 delete operations require super admin. V2 should have equivalent authorization.

3. **Test Host Genus Mapping**: V1 has link to gallhost page for mapping to entire host genus. Verify V2 provides equivalent quick access.

### Low Priority
4. **Consider Inline Editing**: V2's dedicated list view could benefit from inline quick-edit for common fields.

5. **Add Keyboard Shortcuts**: V2's typeahead components support keyboard navigation; consider adding shortcuts for power users.

---

## Testing Checklist

### Create Operations
- [ ] Create new gall with existing genus
- [ ] Create new gall requiring new genus (Unknown)
- [ ] Create undescribed gall via flow
- [ ] Verify taxonomy linkage is correct
- [ ] Verify host associations saved
- [ ] Verify filter fields saved
- [ ] Verify aliases saved

### Update Operations
- [ ] Edit existing gall morphology
- [ ] Add/remove hosts
- [ ] Add/remove filter values
- [ ] Add/remove aliases
- [ ] Toggle datacomplete/undescribed
- [ ] Rename gall
- [ ] Rename with alias creation

### Delete Operations
- [ ] Delete gall with confirmation
- [ ] Verify cascade deletes associations

### Edge Cases
- [ ] Empty hosts array (should require at least one)
- [ ] Duplicate alias names
- [ ] Invalid species name format
- [ ] Concurrent edit detection (PubSub)
- [ ] Discard unsaved changes flow

---

## File References

### V1 Key Locations
- Main form: `v1/pages/admin/gall.tsx:69-623`
- Undescribed modal: `v1/components/UndescribedFlow.tsx:33-307`
- Admin wrapper: `v1/libs/pages/admin.tsx:61-222`
- useAdmin hook: `v1/hooks/useAdmin.tsx:89-391`
- Gall DB operations: `v1/libs/db/gall.ts:86-758`
- API routes: `v1/pages/api/gall/*.ts`

### V2 Key Locations
- List view: `lib/gallformers_web/live/admin/gall_live/index.ex:1-183`
- Form view: `lib/gallformers_web/live/admin/gall_live/form.ex:1-1403`
- Undescribed flow: `lib/gallformers_web/live/admin/gall_live/undescribed.ex:1-499`
- Form helpers: `lib/gallformers_web/live/admin/form_helpers.ex:1-514`
- Deferred changes: `lib/gallformers_web/live/admin/deferred_changes.ex:1-247`
- Species context: `lib/gallformers/species.ex:966-1193` (gall operations)
- Gall schema: `lib/gallformers/species/gall.ex:1-89`
