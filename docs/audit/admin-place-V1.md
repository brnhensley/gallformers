# Admin Place: V1 vs V2 Comparison

## Overview

| Aspect | V1 (Next.js) | V2 (Phoenix LiveView) |
|--------|--------------|----------------------|
| **Route** | `/admin/place` | `/admin/places` (list), `/admin/places/new`, `/admin/places/:id` (form) |
| **Main File** | `v1/pages/admin/place.tsx` | `lib/gallformers_web/live/admin/place_live/index.ex`, `lib/gallformers_web/live/admin/place_live/form.ex` |
| **Context** | `v1/libs/db/place.ts` | `lib/gallformers/places.ex` |
| **Schema** | `v1/libs/api/apitypes.ts` (PlaceNoTreeApi) | `lib/gallformers/places/place.ex` |
| **API Routes** | 4 files in `v1/pages/api/place/` | N/A (LiveView handles all) |

---

## UI Layer Comparison

### V1 Implementation (`v1/pages/admin/place.tsx:59-148`)

**Architecture:**
- Single page component handling both list and form
- Uses `useAdmin` hook (`v1/hooks/useAdmin.tsx`) for generic admin CRUD patterns
- Uses `Admin` wrapper component (`v1/libs/pages/admin.tsx`) for layout/auth
- React Bootstrap for UI components
- `AsyncTypeahead` for place name search/selection (lines 104, 191-213)
- `react-hook-form` for form state management

**UI Elements:**
- Typeahead input for selecting existing places or creating new ones (line 104)
- Rename button appears when a place is selected (lines 105-115)
- Code input field (text, required) (lines 119-129)
- Type dropdown (select, required) - only shows `['state', 'province']` (lines 130-144)
- Save and Delete buttons via `useAdmin` hook
- Alert banner explaining limited functionality (lines 90-97)

**Form Fields:**
| Field | Type | Required | V1 Location |
|-------|------|----------|-------------|
| name | Typeahead (text) | Yes | line 104 |
| code | Text input | Yes | lines 122-127 |
| type | Select dropdown | Yes | lines 132-140 |

**Place Types in V1:** `['state', 'province']` (defined in `v1/libs/api/apitypes.ts:112`)

### V2 Implementation

**Index (`lib/gallformers_web/live/admin/place_live/index.ex`):**
- Separate list view with search functionality
- Search input with 300ms debounce (lines 85-93)
- Table display with Name, Code, Type columns (lines 102-159)
- Action buttons: Edit, View (external link), Delete (lines 130-151)
- Delete confirmation with warning about species range associations (line 149)
- "New Place" button navigates to form (lines 95-97)
- Real-time updates via PubSub subscription (line 13)

**Form (`lib/gallformers_web/live/admin/place_live/form.ex`):**
- Uses `FormHelpers` behaviour with `crud_helpers: true` (line 6)
- Implements standard callbacks for entity CRUD (lines 13-28)
- Shared form for both new and edit modes
- Tailwind CSS with custom `gf-` classes

**UI Elements:**
- Name input (text, required) (lines 83-89)
- Code input (text, required) with helper text (lines 94-101)
- Type select dropdown (lines 104-111)
- Delete button (edit mode only) with confirmation (lines 117-125)
- Form actions component for Save/Cancel (line 127)
- Discard confirmation modal for dirty form state (line 131)
- Help card explaining limited functionality (lines 134-142)

**Form Fields:**
| Field | Type | Required | V2 Location |
|-------|------|----------|-------------|
| name | Text input | Yes | form.ex:83-89 |
| code | Text input | Yes | form.ex:94-101 |
| type | Select dropdown | Yes | form.ex:104-111 |

**Place Types in V2:** `['state', 'province', 'country', 'region']` (defined in `lib/gallformers/places/place.ex:22`)

### UI Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| List/Form separation | Combined single page | Separate list + form pages | Enhanced | V2 cleaner separation of concerns |
| Place search | AsyncTypeahead inline | Separate search on list page | Changed | V2 uses simpler search input |
| Name input | Typeahead with create | Plain text input | Simplified | V2 doesn't support inline creation |
| Rename functionality | Dedicated modal + button | Edit form | Simplified | V2 just edits name directly |
| Place types | 2 types (state, province) | 4 types (+ country, region) | Enhanced | V2 more flexible |
| Delete confirmation | Modal dialog | Browser confirm | Different | Both functional |
| Real-time updates | None | PubSub subscription | Enhanced | V2 reflects changes from other users |
| Dirty form tracking | Via react-hook-form | Custom FormHelpers | Enhanced | V2 has discard confirmation |
| Limited functionality alert | Yellow alert | Help card | Same | Both explain limitations |
| Responsive design | Bootstrap grid | Tailwind flex/grid | Same | Both responsive |

---

## Business Logic Comparison

### V1 Business Logic

**Location:** `v1/libs/db/place.ts`

**Functions:**
- `searchPlaces(s: string)` - Search by name contains (line 66-68)
- `getPlaceByName(name: string)` - Exact name lookup (line 70-72)
- `deletePlace(id: number)` - Raw SQL delete (lines 110-128)
- `upsertPlace(place: PlaceNoTreeUpsertFields)` - Prisma upsert (lines 130-155)
- `getPlaces(whereClause)` - Generic fetch with tree relationships (lines 30-64)
- `placeById(id: number)` - Get with hosts (lines 74-108)

**Patterns:**
- Uses `fp-ts` TaskEither for error handling
- Prisma ORM for database operations
- Complex adaptor functions for tree relationships (lines 48-61, 90-105)

### V2 Business Logic

**Location:** `lib/gallformers/places.ex`

**Functions:**
- `list_places()` - Returns states/provinces only (lines 16-22)
- `list_all_places()` - Returns all places (lines 88-94)
- `search_places(query, limit)` - Case-insensitive search (lines 74-83)
- `get_place(id)` - Get by ID (lines 38-41)
- `get_place!(id)` - Get by ID, raises (lines 46-48)
- `get_place_by_code(code)` - Get by code (lines 27-33)
- `get_parent_place(place_id)` - Get parent via join table (lines 54-68)
- `change_place(place, attrs)` - Changeset (lines 101-104)
- `create_place(attrs)` - Insert with broadcast (lines 109-115)
- `update_place(place, attrs)` - Update with broadcast (lines 120-126)
- `delete_place(place)` - Delete with broadcast (lines 131-135)
- `subscribe()` - PubSub subscription (lines 140-142)

**Patterns:**
- Ecto for database operations
- Phoenix PubSub for real-time updates
- SQLite-compatible lowercase search (line 78)
- Simple return types (no monads)

### Business Logic Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Error handling | fp-ts TaskEither | Pattern matching/raises | Different | V2 simpler, Elixir-idiomatic |
| ORM | Prisma | Ecto | Different | Both mature ORMs |
| Search | `contains` (case-sensitive) | `fragment("lower(?)...")` | Different | V2 explicitly case-insensitive |
| Real-time | None | PubSub broadcast | Enhanced | V2 supports multi-user |
| Tree relationships | Complex adaptors | many_to_many schema | Different | V2 cleaner with Ecto |
| Validation | API-level | Changeset | Enhanced | V2 centralized validation |

---

## Data Layer Comparison

### V1 Schema (`v1/libs/api/apitypes.ts:126-138`)

```typescript
export type PlaceNoTreeApi = {
    id: number;
    name: string;
    code: string;
    type: string;
};

export type PlaceNoTreeUpsertFields = PlaceNoTreeApi & Deletable;

export type PlaceApi = PlaceNoTreeApi & {
    parent: PlaceApi[];
    children: PlaceApi[];
};
```

**Prisma Schema:** Uses `place`, `placeplace` (join table) tables

### V2 Schema (`lib/gallformers/places/place.ex`)

```elixir
@required_fields [:name, :code, :type]
@place_types ~w(state province country region)

schema "place" do
  field :name, :string
  field :code, :string
  field :type, :string

  many_to_many :children, __MODULE__,
    join_through: "placeplace",
    join_keys: [parent_id: :id, place_id: :id]

  many_to_many :parents, __MODULE__,
    join_through: "placeplace",
    join_keys: [place_id: :id, parent_id: :id]

  many_to_many :species, Gallformers.Species.Species,
    join_through: "speciesplace",
    join_keys: [place_id: :id, species_id: :id]
end
```

**Validations (lines 48-56):**
- `validate_required([:name, :code, :type])`
- `validate_inclusion(:type, @place_types)`
- `validate_length(:name, min: 1, max: 100)`
- `validate_length(:code, min: 1, max: 10)`
- `unique_constraint(:name)`
- `unique_constraint(:code)`

### Data Layer Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Required fields | Runtime check | Schema-defined + changeset | Enhanced | V2 single source of truth |
| Type validation | Frontend only | Changeset inclusion | Enhanced | V2 enforces at data layer |
| Length validation | None | name: 1-100, code: 1-10 | Enhanced | V2 has length constraints |
| Unique constraints | Database-level | Explicit in changeset | Same | Both enforce uniqueness |
| Place types | 2 (state, province) | 4 (+ country, region) | Enhanced | V2 more flexible |
| Tree relationships | Complex adaptor | Ecto many_to_many | Different | V2 cleaner association |
| Species association | Via separate queries | many_to_many defined | Enhanced | V2 explicit relationship |
| SchemaFields behavior | N/A | Implemented | Enhanced | V2 supports field metadata |

---

## API Routes (V1 Only)

V1 uses separate API routes; V2 handles all via LiveView.

| Endpoint | File | Purpose |
|----------|------|---------|
| `GET /api/place/?q=` | `v1/pages/api/place/index.ts` | Search places |
| `DELETE /api/place/[id]` | `v1/pages/api/place/[id].ts` | Delete place |
| `GET /api/place/name/[name]` | `v1/pages/api/place/name/[name].ts` | Check name exists |
| `POST /api/place/upsert` | `v1/pages/api/place/upsert.ts` | Create/update place |

---

## Authentication & Authorization

| Aspect | V1 | V2 | Notes |
|--------|----|----|-------|
| Admin check | `Auth` component wrapper | Route-level plug | Both require admin |
| Super admin | `isSuperAdmin` check in useAdmin | Not implemented | V1 requires super admin for Place/FilterTerms nav |
| Nav visibility | Conditional in Admin component | Always visible | V2 shows place admin to all admins |

---

## Summary

### Parity Status: **Feature Complete with Enhancements**

The V2 implementation achieves functional parity with V1 and includes several improvements:

**What V2 Has:**
- Full CRUD operations for places
- Search functionality
- Form validation with error display
- Delete confirmation
- Dirty form tracking with discard confirmation
- Real-time updates via PubSub
- Cleaner separation (list vs form pages)
- More place types (country, region)
- Stronger validation (length constraints)

**What V2 Changed:**
- No inline creation via typeahead (simpler UX)
- No dedicated rename modal (just edit the name field)
- No super-admin restriction (all admins can access)

**Recommendations:**
1. **Consider adding country/region support** - V2 schema supports it but UI may not fully utilize it
2. **Tree/hierarchy management** - Both versions acknowledge this is a "stub page" - full hierarchy support not implemented
3. **Super-admin restriction** - V2 may want to add this if Place management should be restricted

---

## File References

### V1 Files
- **Page**: `v1/pages/admin/place.tsx` (159 lines)
- **Admin Hook**: `v1/hooks/useAdmin.tsx` (394 lines)
- **Admin Component**: `v1/libs/pages/admin.tsx` (225 lines)
- **DB Layer**: `v1/libs/db/place.ts` (156 lines)
- **Types**: `v1/libs/api/apitypes.ts` (PlaceNoTreeApi at lines 126-131)
- **API - Search**: `v1/pages/api/place/index.ts` (7 lines)
- **API - Delete**: `v1/pages/api/place/[id].ts` (6 lines)
- **API - Name Check**: `v1/pages/api/place/name/[name].ts` (25 lines)
- **API - Upsert**: `v1/pages/api/place/upsert.ts` (7 lines)

### V2 Files
- **List View**: `lib/gallformers_web/live/admin/place_live/index.ex` (171 lines)
- **Form View**: `lib/gallformers_web/live/admin/place_live/form.ex` (148 lines)
- **Context**: `lib/gallformers/places.ex` (153 lines)
- **Schema**: `lib/gallformers/places/place.ex` (63 lines)
- **Form Helpers**: `lib/gallformers_web/live/admin/form_helpers.ex` (514 lines, shared)
