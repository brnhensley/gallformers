# Admin Filter Terms: V1 vs V2 Comparison

## Overview

The Admin Filter Terms page manages filter terms (alignment, cells, colors, forms, locations, shapes, textures, walls) used in the ID tool to help identify galls. These are morphological attributes that can be assigned to gall records.

| Attribute | V1 | V2 |
|-----------|----|----|
| **Route** | `/admin/filterterms` | `/admin/filter-terms` |
| **Access** | Super admin only | Super admin only |
| **Framework** | Next.js + React | Phoenix LiveView |

---

## Files Analyzed

### V1 Files
| File | Purpose |
|------|---------|
| `v1/pages/admin/filterterms.tsx` (lines 1-257) | Main page component |
| `v1/hooks/useAdmin.tsx` (lines 1-394) | Generic admin form hook |
| `v1/libs/pages/admin.tsx` (lines 1-225) | Admin page wrapper component |
| `v1/libs/db/filterfield.ts` (lines 1-519) | Database layer for filter fields |
| `v1/libs/api/apitypes.ts` (lines 432-476) | Type definitions |
| `v1/pages/api/filterfield/upsert.ts` (lines 1-7) | Upsert API endpoint |
| `v1/pages/api/filterfield/[fieldType]/[id].ts` (lines 1-57) | GET/DELETE by ID endpoint |
| `v1/pages/api/filterfield/[fieldType]/index.ts` (lines 1-63) | List/search by type endpoint |

### V2 Files
| File | Purpose |
|------|---------|
| `lib/gallformers_web/live/admin/filter_terms_live/index.ex` (lines 1-187) | List page LiveView |
| `lib/gallformers_web/live/admin/filter_terms_live/form.ex` (lines 1-225) | Form page LiveView |
| `lib/gallformers/filter_fields.ex` (lines 1-188) | Context module with CRUD operations |
| `lib/gallformers/filter_fields/alignment.ex` (lines 1-32) | Alignment schema |
| `lib/gallformers/filter_fields/color.ex` (lines 1-30) | Color schema (no description) |
| `lib/gallformers_web/live/admin/form_helpers.ex` (lines 1-514) | Shared form helpers |
| `lib/gallformers_web/live/admin/form_components.ex` (lines 1-157) | Shared form components |

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Page Architecture** | Single page with type selector | List page + separate form page | IMPROVED | V2 follows REST-like URL patterns |
| **Filter Type Selection** | Dropdown on same page, changes data inline | Dropdown on list, URL param for type | IMPROVED | V2 preserves type in URL for bookmarking |
| **Filter Types Supported** | 9 types (incl. seasons) | 8 types (excl. seasons) | EQUIVALENT | Both note seasons are fixed |
| **List View** | Typeahead search dropdown | Full table with all items | IMPROVED | V2 shows all items with counts |
| **Type Counts** | Not shown | Shows count per type in dropdown | IMPROVED | Better at-a-glance info |
| **Create New** | Type in typeahead field | Separate /new route | IMPROVED | Clearer UX flow |
| **Edit Existing** | Select from typeahead | Click row or navigate to /:id | EQUIVALENT | Both work well |
| **Form Fields** | Word + Description textarea | Term input + Description textarea | EQUIVALENT | Same fields |
| **Description Conditional** | Always shows (but notes color doesn't save) | Only shows if type has description | IMPROVED | Cleaner UX |
| **Rename Flow** | Separate rename modal with confirmation | Inline edit in form | IMPROVED | Simpler flow |
| **Delete** | Confirmation dialog, super admin check | Confirmation, delete button on form | EQUIVALENT | Both require confirmation |
| **Validation** | react-hook-form, description required always | Ecto changeset, field-specific | IMPROVED | V2 validates correctly per type |
| **Error Handling** | Toast + alert panel | Flash messages | EQUIVALENT | Both provide feedback |
| **Real-time Updates** | Client-side state only | No PubSub (single-user admin) | EQUIVALENT | Neither needs real-time |
| **Dirty Form Tracking** | useAdmin hook isDirty | FormHelpers form_dirty | EQUIVALENT | Both track changes |
| **Discard Confirmation** | No explicit handling | Modal on cancel with unsaved changes | IMPROVED | V2 prevents accidental data loss |
| **API Architecture** | REST endpoints with fp-ts TaskEither | Direct context calls, no API layer | SIMPLIFIED | V2 LiveView eliminates API |
| **Type Safety** | TypeScript with FilterFieldType enum | Atom whitelist with guards | EQUIVALENT | Both type-safe |
| **Database Layer** | Prisma with per-type upsert functions | Ecto with polymorphic context | IMPROVED | V2 is more DRY |

---

## UI Layer Analysis

### V1 UI (`v1/pages/admin/filterterms.tsx`)

**Component Structure**:
```
Admin (wrapper)
  ├── Field Type Selector (dropdown)
  ├── mainField (Typeahead for selecting/creating)
  ├── Rename button (shows when item selected)
  ├── Description textarea
  ├── Save button
  └── Delete button (super admin only)
```

**Key UI Elements**:
- **Type Selector** (lines 164-184): `<select>` with onChange that resets selection and reloads data
- **Word Field** (lines 185-209): Typeahead from react-bootstrap-typeahead, allows creating new
- **Rename Button** (lines 192-202): Conditional button that opens EditName modal
- **Description** (lines 211-236): Required textarea, notes it won't save for color type
- **Form Buttons**: Save and Delete rendered via useAdmin hook

**Notable V1 Behaviors**:
- Seasons filtered out of type selector (line 177-179)
- Description marked "required" even for colors, with confusing note (lines 232-234)
- All data for all types fetched at SSR time (lines 243-255)
- Selection changes URL via `router.replace` with shallow routing

### V2 UI

**Index Page** (`lib/gallformers_web/live/admin/filter_terms_live/index.ex`):
```
Layouts.admin
  ├── Type selector (dropdown with counts)
  ├── New button (navigates to /new)
  └── Table
      ├── Term column
      ├── Description column (conditional)
      └── Actions (Edit, Delete)
```

**Form Page** (`lib/gallformers_web/live/admin/filter_terms_live/form.ex`):
```
Layouts.admin
  └── admin_edit_layout
      ├── Back link
      ├── Title (contextual)
      ├── Intro text
      ├── Form
      │   ├── Term input (required)
      │   ├── Description textarea (conditional)
      │   ├── Delete button (edit mode only)
      │   └── form_actions (Cancel/Save)
      └── discard_confirm_modal
```

**Key V2 UI Elements**:
- **Type Selector** (lines 100-112): `.input type="select"` with counts shown in labels
- **Table** (lines 123-178): Standard gf-table with conditional description column
- **Term Input** (lines 175-182): Standard text input, field name varies by type
- **Description** (lines 185-198): Conditional via `FilterFields.has_description?/1`
- **Delete** (lines 202-210): Button with data-confirm attribute

---

## Business Logic Analysis

### V1 Business Logic

**Data Flow**:
1. SSR fetches all 8 filter types via Prisma (getServerSideProps, lines 243-255)
2. Type selection updates local state and swaps data array
3. Typeahead selection sets `selected` state
4. Form changes tracked by react-hook-form
5. Save calls `/api/filterfield/upsert` with field + fieldType
6. Delete calls `/api/filterfield/{type}/{id}`

**Key Functions in `v1/libs/db/filterfield.ts`**:
- `getAlignments()`, `getCells()`, etc. (lines 21-194): Per-type fetch functions
- `adaptAlignments()`, etc.: Convert DB records to FilterField type
- `deleteFilterField()` (lines 196-241): Switch-based delete by type
- `upsertFilterField()` (lines 243-423): 250+ line switch statement for upserts
- `getFilterFieldByNameAndType()` (lines 491-514): Name-based lookup for uniqueness check

**Validation**:
- Description marked required in form register (line 223)
- Name existence check via API call (line 141)
- Form validation via react-hook-form mode: 'all' (useAdmin line 138)

### V2 Business Logic

**Data Flow**:
1. Mount loads items for default type (alignment) (lines 13-23)
2. URL params or change_type event sets filter_type
3. List reloads via `FilterFields.list_all/1`
4. Navigation to /new or /:id opens form page
5. Form validates via changeset on each change
6. Save calls `FilterFields.create/2` or `FilterFields.update/3`
7. Delete calls `FilterFields.delete/2`

**Key Functions in `lib/gallformers/filter_fields.ex`**:
- `filter_types/0` (line 39): Returns list of valid types as atoms
- `schema_for/1` (lines 45-52): Returns schema module for type
- `field_name_for/1` (lines 58-66): Returns field name atom for type
- `has_description?/1` (lines 72-73): Color returns false, others true
- `list_all/1` (lines 82-88): Generic list with dynamic order_by
- `create/2`, `update/3`, `delete/2` (lines 111-135): Generic CRUD
- `type_label/1`, `singular_label/1` (lines 148-169): Display labels

**Validation**:
- Per-schema changeset with `validate_required` (e.g., alignment.ex line 29)
- Unique constraint on field value (e.g., alignment.ex line 30)
- Type whitelist via module attribute guards (index.ex line 10)

---

## Data Layer Analysis

### V1 Data Layer

**Schema** (via Prisma, inferred from filterfield.ts):
- 8 separate tables: alignment, cells, color, form, location, shape, texture, walls
- Each has: id (int), {fieldname} (string), description (string nullable)
- Color and season lack description field

**Queries**:
- Each type has dedicated findMany with order_by
- Adapter functions normalize to FilterField type with Option<description>
- Upsert uses Prisma upsert with where: {id}

**Type Definitions** (`v1/libs/api/apitypes.ts`):
```typescript
export type FilterField = {
    id: number;
    field: string;
    description: Option<string>;
};

export enum FilterFieldTypeValue {
    ALIGNMENTS = 'alignments',
    CELLS = 'cells',
    COLORS = 'colors',
    // ... etc
}

export type FilterFieldWithType = FilterField & {
    fieldType: FilterFieldType;
};
```

### V2 Data Layer

**Schema** (via Ecto):
- Same 8 tables with same structure
- Each schema module defines:
  - `schema/1` macro with field definitions
  - `changeset/2` with cast, validate_required, unique_constraint
  - `@type t` spec

**Example Schema** (`lib/gallformers/filter_fields/alignment.ex`):
```elixir
schema "alignment" do
  field :alignment, :string
  field :description, :string
  many_to_many :galls, Gallformers.Species.Gall, join_through: "gallalignment"
end

def changeset(alignment, attrs) do
  alignment
  |> cast(attrs, [:alignment, :description])
  |> validate_required([:alignment])
  |> unique_constraint(:alignment)
end
```

**Queries**:
- Generic context uses `schema_for/1` to get module
- Dynamic field name via `field_name_for/1`
- Single `list_all/1`, `get!/2`, `create/2`, etc. for all types

---

## Differences Summary

### Improvements in V2

1. **Cleaner Architecture**: Separate list/form pages vs. single page with inline editing
2. **URL Preservation**: Type preserved in URL params for bookmarking/sharing
3. **Type Counts**: Dropdown shows count of items per type
4. **Conditional Description**: Only shown for types that support it
5. **Discard Confirmation**: Modal prevents losing unsaved changes
6. **DRY Code**: Polymorphic context vs. 250+ line switch statements
7. **Proper Validation**: Per-type changeset vs. universal required description

### Equivalent Features

1. **Authentication**: Both super admin only
2. **CRUD Operations**: Full create/read/update/delete
3. **Form Dirty Tracking**: Both track unsaved changes
4. **Delete Confirmation**: Both require user confirmation
5. **Error Feedback**: Both show errors to user

### V1 Features Not in V2

1. **Rename Modal**: V1 has separate rename flow; V2 just edits inline
2. **Typeahead Search**: V1 uses typeahead; V2 shows full table
3. **Client-side Caching**: V1 caches typeahead results; V2 loads fresh

---

## Recommendations

1. **No Critical Gaps**: V2 implementation is complete and improved
2. **Consider**: Adding inline edit capability on list page for quick edits
3. **Consider**: Adding search/filter on list page if term counts grow large
4. **Documentation**: V2 correctly excludes seasons from UI (they're fixed values)

---

## Status: COMPLETE

V2 implementation is feature-complete with several UX improvements over V1.
