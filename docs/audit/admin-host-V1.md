# Host Admin V1 vs V2 Comparison

**V1 Route**: `/admin/host`
**V2 Route**: `/admin/hosts` (list), `/admin/hosts/:id` (edit), `/admin/hosts/new` (create)

## Summary

Admin page for creating and modifying host plant entries. Manages plant taxonomy, common names, geographic range, and associated metadata.

---

## V1 Implementation

### Files

| File | Purpose | Lines |
|------|---------|-------|
| `/Users/jeff/dev/gallformers/v1/pages/admin/host.tsx` | Main page component | 1-485 |
| `/Users/jeff/dev/gallformers/v1/hooks/useSpecies.tsx` | Species-specific form logic | 1-260 |
| `/Users/jeff/dev/gallformers/v1/hooks/useAdmin.tsx` | Generic admin form hook | 1-394 |
| `/Users/jeff/dev/gallformers/v1/libs/pages/admin.tsx` | Admin wrapper component | 1-225 |
| `/Users/jeff/dev/gallformers/v1/components/aliastable.tsx` | Editable alias table | 1-81 |
| `/Users/jeff/dev/gallformers/v1/pages/api/host/index.ts` | Search API | 1-13 |
| `/Users/jeff/dev/gallformers/v1/pages/api/host/upsert.ts` | Create/Update API | 1-7 |
| `/Users/jeff/dev/gallformers/v1/pages/api/host/[id].tsx` | Delete API | 1-6 |
| `/Users/jeff/dev/gallformers/v1/libs/db/host.ts` | Database layer | 1-435 |

### UI Layer

#### Search/Selection (V1)
- **AsyncTypeahead** from `react-bootstrap-typeahead` (lines 191-213 in useAdmin.tsx)
- Searches via `/api/host?q={query}` endpoint
- Returns full HostApi objects with all nested data
- Allows creating new hosts inline with `allowNew` prop

#### Form Fields (host.tsx)
| Field | Type | Location | Required |
|-------|------|----------|----------|
| Name (binomial) | AsyncTypeahead | Lines 168-173 | Yes |
| Genus | Typeahead (disabled) | Lines 194-209 | Auto-filled |
| Family | Typeahead | Lines 216-259 | Yes (for new species) |
| Section | Typeahead | Lines 272-300 | No |
| Abundance | Typeahead | Lines 303-330 | No |
| Range Map | react-simple-maps | Lines 333-416 | No |
| Aliases | EditableDataTable | Lines 418-435 | No |
| Data Complete | Checkbox | Lines 437-456 | No |

#### Range Map (V1)
- Uses `react-simple-maps` with `ComposableMap`, `Geographies`, `Geography`, `ZoomableGroup`
- Interactive clickable regions for USA/Canada
- TopoJSON from `/usa-can-topo.json`
- Green fill for in-range, white for out-of-range
- Select All / Deselect All buttons

### Business Logic

#### Species/Host Hooks
- **useSpecies** (lines 117-257): Manages FGS (Family-Genus-Section) taxonomy
  - `fgsFromName()`: Extracts genus from species name, looks up family
  - `renameSpecies()`: Handles genus changes with confirmation dialog
  - `createNewSpecies()`: Creates empty SpeciesApi object
  - `toSpeciesUpsertFields()`: Converts form data to API format

- **useAdmin** (lines 89-391): Generic admin CRUD operations
  - Form validation with react-hook-form
  - Async search with caching
  - Delete confirmation dialog
  - Name exists checking
  - Toast notifications
  - URL state management (`?id=123`)

#### Rename Logic (useSpecies.tsx lines 145-198)
1. Extract genus from old and new names
2. If genus unchanged: simple rename
3. If genus changed and exists: update FGS reference
4. If genus changed and doesn't exist: show confirmation dialog to create new genus under current family

### Data Layer (host.ts)

#### Types
```typescript
type DBHost = species & {
  abundance: abundance | null;
  host_galls: (host & { gallspecies: { id, name } })[];
  speciessource: (speciessource & { source })[];
  aliasspecies: (aliasspecies & { alias })[];
  image: (image & { source })[];
  fgs: FGS;
  places: (speciesplace & { place })[];
};
```

#### Key Functions
| Function | Purpose | Lines |
|----------|---------|-------|
| `getHosts()` | Generic host query with includes | 197-247 |
| `hostById()` | Fetch host by ID | 253 |
| `hostsSearch()` | Search hosts by name | 419 |
| `upsertHost()` | Create or update host | 327-344 |
| `deleteHost()` | Delete host and cascade | 398-417 |
| `hostUpdateSteps()` | Transaction steps for update | 293-309 |
| `hostDeleteSteps()` | Transaction steps for delete | 351-391 |

#### Delete Cascade (lines 351-391)
1. Delete from `host` (gall-host relations)
2. Delete from `speciesplace` (range)
3. Delete from `speciessource` (source mappings)
4. Delete from `aliasspecies` (aliases)
5. Delete from `speciestaxonomy` (taxonomy links)
6. Delete from `species`
7. Clean up orphaned genera

---

## V2 Implementation

### Files

| File | Purpose | Lines |
|------|---------|-------|
| `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/host_live/index.ex` | List view | 1-169 |
| `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/host_live/form.ex` | Form view | 1-1017 |
| `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/form_helpers.ex` | Shared form helpers | 1-515 |
| `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/deferred_changes.ex` | Change tracking | 1-247 |
| `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/form_components.ex` | Shared form components | 1-157 |
| `/Users/jeff/dev/gallformers/lib/gallformers/hosts.ex` | Context module | 1-846 |
| `/Users/jeff/dev/gallformers/lib/gallformers/hosts/host.ex` | Schema (join table) | 1-39 |

### UI Layer

#### List View (index.ex)
- Separate dedicated list page (unlike V1's single-page approach)
- Search via `search_hosts/2` with debounce
- Table with name, data complete indicator, action buttons
- Links to: Edit, Edit Images, Map Sources, View Public, Delete
- PubSub subscription for real-time updates

#### Form View (form.ex)
| Field | Type | Location | Required |
|-------|------|----------|----------|
| Name (binomial) | Custom typeahead | Lines 747-781 | Yes |
| Genus | Text (disabled) | Lines 794-801 | Auto-filled |
| Family | Select (when new genus) | Lines 807-829 | Yes (for new genus) |
| Section | Select | Lines 838-857 | No |
| Abundance | Select | Lines 860-868 | No |
| Range Map | `.range_map` component | Lines 910-922 | No |
| Aliases | `.alias_editor` component | Lines 928-932 | No |
| Data Complete | Checkbox | Lines 935-940 | No |

#### Range Map (V2)
- Server-side rendered SVG via `.range_map` component
- LiveView events for toggle (`toggle_region`)
- Same visual style (green in-range, white out)
- Select All / Deselect All buttons
- Disabled in `:new` mode until host is saved

### Business Logic

#### Form Modes
- `:search` - Initial typeahead state for new hosts
- `:new` - Creating new host (after name selected)
- `:edit` - Editing existing host

#### DeferredChanges (deferred_changes.ex)
Tracks original vs pending state for related data:
- `init/2`: Initialize tracking with original data
- `add_pending/3`: Add item with temp negative ID
- `remove_pending/3`: Mark item for removal
- `compute_changes/2`: Returns `{to_add, to_remove}`
- `refresh/3`: Reset after save

#### Rename Flow (hosts.ex lines 584-724)
1. `rename_host/3`: Entry point
2. Check name availability
3. Compare old/new genus
4. If genus unchanged: `do_simple_rename/3`
5. If new genus exists: `do_rename_with_genus_update/4`
6. If new genus doesn't exist: Return `{:needs_genus_confirmation, info}`
7. UI shows confirmation modal
8. On confirm: `rename_host_with_new_genus/5` creates genus and renames

### Data Layer (hosts.ex)

#### Key Functions
| Function | Purpose | Lines |
|----------|---------|-------|
| `list_hosts/0` | All hosts | 18-30 |
| `list_hosts_paginated/2` | Paginated hosts | 35-50 |
| `search_hosts/2` | Multi-word search | 240-284 |
| `get_host_species/1` | Get Species struct | 398-404 |
| `create_host/1` | Create new host | 375-382 |
| `update_host/2` | Update host | 388-393 |
| `delete_host/1` | Delete with cascade | 416-441 |
| `update_host_places/2` | Bulk update range | 512-530 |
| `rename_host/3` | Rename with genus handling | 589-655 |

#### Delete Cascade (lines 429-441)
1. Delete S3 images via `Images.delete_images_from_s3_for_species/1`
2. Delete FTS index entry
3. Delete species record (DB triggers handle cascade)

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Routing** | Single page `/admin/host?id=X` | Separate routes `/admin/hosts`, `/admin/hosts/:id`, `/admin/hosts/new` | Complete | V2 follows Phoenix conventions |
| **List View** | Inline typeahead search | Dedicated table with actions | Complete | V2 has richer list UX |
| **Search** | AsyncTypeahead via API | LiveView + multi-word search | Complete | V2 supports "q alba" -> "Quercus alba" |
| **Create Host** | `allowNew` in typeahead | Typeahead with `create_event` | Complete | Same UX, different implementation |
| **Name Field** | Editable typeahead | Read-only + Rename button | Complete | V2 separates selection from editing |
| **Genus Field** | Typeahead (disabled) | Text (disabled) | Complete | Both auto-fill from name |
| **Family Field** | Typeahead | Dropdown select | Complete | V2 only when genus is new |
| **Section Field** | Typeahead | Dropdown select | Complete | V2 filters by family |
| **Abundance Field** | Typeahead | Dropdown select | Complete | Both pull from abundance table |
| **Range Map** | react-simple-maps (client) | Server-rendered SVG component | Complete | V2 uses LiveView events |
| **Map Interaction** | Click to toggle | Click to toggle | Complete | Same behavior |
| **Select All/Deselect All** | Buttons | Buttons | Complete | Same functionality |
| **Aliases** | EditableDataTable | Custom table component | Complete | V2 uses `.alias_editor` |
| **Alias Types** | common/scientific | common/scientific | Complete | Same options |
| **Data Complete** | Checkbox | Checkbox | Complete | Same field |
| **Rename** | Modal with confirm | Modal with confirm | Complete | Both handle genus changes |
| **Genus Creation** | In rename dialog | Separate confirmation modal | Complete | V2 has cleaner UX |
| **Delete** | Confirm dialog | Browser confirm | Complete | V2 uses `data-confirm` |
| **Delete Cascade** | DB transaction | DB cascade + S3 cleanup | Complete | V2 adds S3/FTS cleanup |
| **Form Validation** | react-hook-form | Ecto changeset | Complete | Different frameworks |
| **Dirty State** | `isDirty` from form | `form_dirty` assign | Complete | V2 manual tracking |
| **Discard Confirm** | Not implemented | Modal on cancel | Enhanced | V2 adds unsaved changes warning |
| **PubSub** | Not present | Real-time updates | Enhanced | V2 syncs across tabs |
| **Images Quick Link** | Via navbar | In form sidebar | Complete | V2 more prominent |
| **Source Map Link** | Via navbar | In form sidebar | Complete | V2 more prominent |
| **Error Handling** | Toast + alert | Flash messages | Complete | Both provide feedback |
| **Loading State** | isLoading flag | Not explicit | Equivalent | LiveView handles via socket |
| **Super Admin Check** | Via session | Not implemented | Missing | V2 needs super admin for delete? |

---

## Recommendations

### Missing in V2
1. **Super Admin Check for Delete**: V1 has `needSuperAdmin` for delete button (line 257-284 in useAdmin.tsx). V2 should consider adding role-based restrictions for destructive operations.

### Enhancements in V2
1. **Discard Confirmation**: V2 warns users about unsaved changes on cancel - this is better UX.
2. **PubSub**: V2 has real-time updates across browser tabs/sessions.
3. **Multi-word Search**: V2's search supports "q alba" matching "Quercus alba".
4. **Better S3 Cleanup**: V2 explicitly deletes S3 images before cascade.

### Architecture Differences
1. **State Management**: V1 uses React hooks + local state. V2 uses LiveView assigns with explicit dirty tracking.
2. **API Layer**: V1 has separate REST endpoints. V2 handles everything server-side in LiveView.
3. **Form Data**: V1 tracks complex nested objects (HostApi with FGS). V2 uses simpler flat assigns with DeferredChanges for related data.

### Migration Considerations
- Family/Section selection: V2 uses static dropdowns vs V1's typeaheads - acceptable since these lists are small
- Range map: V2's server-rendered approach is simpler but may be slower for large interactions - monitor performance
- Alias editing: V2's table is simpler than V1's EditableDataTable but has same functionality

---

## File References

### V1 Key Locations
- Host page component: `/Users/jeff/dev/gallformers/v1/pages/admin/host.tsx:1-485`
- useSpecies hook: `/Users/jeff/dev/gallformers/v1/hooks/useSpecies.tsx:117-257`
- useAdmin hook: `/Users/jeff/dev/gallformers/v1/hooks/useAdmin.tsx:89-391`
- Host DB layer: `/Users/jeff/dev/gallformers/v1/libs/db/host.ts:1-435`
- Alias table: `/Users/jeff/dev/gallformers/v1/components/aliastable.tsx:1-81`

### V2 Key Locations
- Host list: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/host_live/index.ex:1-169`
- Host form: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/host_live/form.ex:1-1017`
- Hosts context: `/Users/jeff/dev/gallformers/lib/gallformers/hosts.ex:1-846`
- Form helpers: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/form_helpers.ex:1-515`
- DeferredChanges: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/deferred_changes.ex:1-247`
- Form components: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/form_components.ex:1-157`
