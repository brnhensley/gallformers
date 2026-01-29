# Admin Glossary Page Comparison: V1 vs V2

**V1 Route**: `/admin/glossary`
**V2 Route**: `/admin/glossary` (list), `/admin/glossary/new`, `/admin/glossary/:id`

## Overview

The Admin Glossary page allows administrators to manage glossary entries (terms, definitions, and source URLs) that are used throughout the site to explain gall-related terminology.

---

## File Locations

### V1 Files

| Purpose | File | Lines |
|---------|------|-------|
| Page Component | `v1/pages/admin/glossary.tsx` | 1-167 |
| useAdmin Hook | `v1/hooks/useAdmin.tsx` | 1-394 |
| Admin Layout | `v1/libs/pages/admin.tsx` | 1-225 |
| DB Functions | `v1/libs/db/glossary.ts` | 1-101 |
| API - List/Search | `v1/pages/api/glossary/index.ts` | 1-18 |
| API - Delete | `v1/pages/api/glossary/[id].ts` | 1-11 |
| API - Upsert | `v1/pages/api/glossary/upsert.ts` | 1-6 |
| API - Word Lookup | `v1/pages/api/glossary/word/[word].ts` | 1-24 |
| Types | `v1/libs/api/apitypes.ts` | 548-553, 692-697 |

### V2 Files

| Purpose | File | Lines |
|---------|------|-------|
| Index LiveView | `lib/gallformers_web/live/admin/glossary_live/index.ex` | 1-173 |
| Form LiveView | `lib/gallformers_web/live/admin/glossary_live/form.ex` | 1-143 |
| Context | `lib/gallformers/glossaries.ex` | 1-162 |
| Schema | `lib/gallformers/glossaries/glossary.ex` | 1-41 |
| Form Helpers | `lib/gallformers_web/live/admin/form_helpers.ex` | 1-514 |

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| **Architecture** | React + API routes | Phoenix LiveView | Complete | Full re-implementation |
| **List View** | Embedded in form page (Typeahead) | Separate dedicated page with table | Improved | V2 has better UX with searchable table |
| **Form View** | Single page with select-to-edit | Separate new/edit routes | Improved | V2 follows modern CRUD patterns |
| **Search** | Typeahead dropdown | Real-time text filter | Complete | Both search word field |
| **Create** | Typeahead "Add new" feature | Dedicated "New Entry" button + page | Complete | |
| **Edit** | Select from typeahead | Click row to navigate to form | Complete | |
| **Delete** | Inline delete button with confirmation | Delete button on edit form | Complete | |
| **Rename** | Dedicated rename modal | Edit word field directly | Different | V2 simplifies - no separate rename |
| **Validation** | react-hook-form client-side | Server-side via Ecto changeset | Complete | V2 validates on blur/submit |
| **Real-time** | None | PubSub for live updates | Enhanced | V2 auto-refreshes on changes |
| **Dirty State** | isDirty from react-hook-form | FormHelpers dirty tracking | Complete | V2 has discard confirmation modal |
| **URL State** | Query param `?id=123` | Route params `/glossary/123` | Complete | V2 uses proper RESTful routes |

---

## UI Layer Analysis

### V1 UI Components

**Page Structure** (`v1/pages/admin/glossary.tsx:62-154`):
- Uses generic `Admin` wrapper component for layout, nav, auth
- Typeahead for word selection (allows creating new entries)
- Definition textarea (4 rows)
- URLs textarea (3 rows)
- Save/Delete/Rename buttons

**Form Fields**:
```typescript
// v1/pages/admin/glossary.tsx:14
type FormFields = AdminFormFields<Entry> & Pick<Entry, 'definition' | 'urls'>;
```

**Key UI Elements**:
- Word: Typeahead with "Add new" capability (line 103)
- Rename button: Shows when entry selected (lines 104-116)
- Definition: Required textarea with validation message (lines 121-135)
- URLs: Required textarea, newline-separated (lines 136-150)

### V2 UI Components

**List View** (`lib/gallformers_web/live/admin/glossary_live/index.ex:78-162`):
- Search input with debounce (300ms)
- New Entry button linking to `/admin/glossary/new`
- Table with Word, Definition (truncated), Actions columns
- Row actions: Edit (pencil icon), View (external link), Delete (trash icon)
- Entry count display

**Form View** (`lib/gallformers_web/live/admin/glossary_live/form.ex:67-142`):
- Uses `Layouts.admin` and `Layouts.admin_edit_layout`
- Word input (text) with lowercase guidance
- Definition textarea (4 rows)
- URLs textarea (2 rows) with "one per line" instruction
- Delete button (edit mode only)
- Save/Cancel with dirty state tracking
- Discard confirmation modal

**Field Schema** (`lib/gallformers/glossaries/glossary.ex:12`):
```elixir
@required_fields [:word, :definition, :urls]
```

---

## Business Logic Analysis

### V1 Business Logic

**Form State Management** (`v1/hooks/useAdmin.tsx`):
- Generic `useAdmin` hook handles all admin forms
- Manages: data, selected, showRenameModal, error, deleteResults
- Form validation via react-hook-form
- URL state sync via router.replace

**Key Functions**:
- `renameEntry`: Creates new Entry with updated word (lines 21-25)
- `toUpsertFields`: Converts form fields to API format (lines 27-33)
- `updatedFormFields`: Populates form when selection changes (lines 35-51)
- `createNewEntry`: Factory for new entries (lines 53-58)

**API Operations**:
- List: GET `/api/glossary` (returns all or search results)
- Create/Update: POST `/api/glossary/upsert` (uses Prisma upsert)
- Delete: DELETE `/api/glossary/[id]`
- Check exists: GET `/api/glossary/word/[word]`

### V2 Business Logic

**Context Module** (`lib/gallformers/glossaries.ex`):
- `list_glossary/0`: All entries ordered by word
- `get_glossary/1`, `get_glossary!/1`: Fetch by ID
- `get_glossary_by_word/1`: Fetch by exact word match
- `search_glossary/1`: Case-insensitive search on word and definition
- `count_glossary/0`: Entry count
- `list_glossary_by_letter/1`: Filter by first letter
- `get_letter_counts/0`: Letter navigation counts
- `change_glossary/2`: Creates changeset
- `create_glossary/1`, `update_glossary/2`, `delete_glossary/1`: CRUD with PubSub broadcast
- `subscribe/0`: Subscribe to glossary changes

**FormHelpers Pattern** (`lib/gallformers_web/live/admin/form_helpers.ex`):
- V2 uses behavior callbacks for standardized CRUD
- Callbacks: `entity_key`, `entity_struct`, `list_path`, `form_key`, `load_entity`, `change_entity`, `create_entity`, `update_entity`, `delete_entity`
- Provides: `init_admin_form`, `apply_new_action`, `apply_edit_action`, `handle_validate`, `handle_save`, `handle_delete`
- Dirty state tracking with discard confirmation

**PubSub Events**:
```elixir
# lib/gallformers/glossaries.ex:154-160
defp broadcast({:ok, glossary}, event) do
  Phoenix.PubSub.broadcast(Gallformers.PubSub, "glossary", {event, glossary})
  {:ok, glossary}
end
```
Events: `:glossary_created`, `:glossary_updated`, `:glossary_deleted`

---

## Data Layer Analysis

### V1 Data Layer

**Prisma Schema** (implicit from usage):
```typescript
// v1/libs/api/apitypes.ts:692-697
export type Entry = {
    id: number;
    word: string;
    definition: string;
    urls: string; // newline separated
};
```

**Database Functions** (`v1/libs/db/glossary.ts`):
- `allGlossaryEntries`: Raw SQL for case-insensitive sort (`ORDER BY word COLLATE NOCASE ASC`)
- `deleteGlossaryEntry`: Prisma delete with result formatting
- `upsertGlossary`: Prisma upsert (create or update based on ID)
- `getEntries`: Generic where clause query
- `searchGlossary`: Word contains search
- `getEntryByWord`: Exact word match

**SQLite Handling**:
```typescript
// v1/libs/db/glossary.ts:12-18
// prisma does not handle sort order by collate NOCASE
db.$queryRaw<glossary[]>(Prisma.sql`
    SELECT * from glossary
    ORDER BY word COLLATE NOCASE ASC;
`)
```

### V2 Data Layer

**Ecto Schema** (`lib/gallformers/glossaries/glossary.ex`):
```elixir
schema "glossary" do
  field :word, :string
  field :definition, :string
  field :urls, :string
end
```

**Validation** (lines 33-40):
- Required: word, definition, urls
- Word length: 1-100 characters
- Definition length: min 1
- Unique constraint on word

**Query Functions** (`lib/gallformers/glossaries.ex`):
- Simple ordering: `order_by: g.word` (lines 18-21)
- Case-insensitive search: `fragment("lower(?) LIKE ?", ...)` (lines 50-56)
- Letter filtering: `fragment("lower(?) LIKE ?", g.word, ^pattern)` (lines 77-81)
- Letter counts: `fragment("upper(substr(word, 1, 1))")` (lines 90-94)

---

## Feature Differences

### V1-Only Features

1. **Rename Modal**: Dedicated modal for renaming word field with duplicate check
   - Location: `v1/pages/admin/glossary.tsx:104-116`, `v1/components/editname.tsx`
   - V2 approach: Direct edit of word field in form

2. **Async Typeahead Search**: Progressive search as you type
   - Location: `v1/hooks/useAdmin.tsx:169-181`
   - V2 approach: Table filter instead

3. **URL State Sync**: Maintains selection in URL query params
   - Location: `v1/hooks/useAdmin.tsx:149-167`
   - V2 approach: Uses route params which is more RESTful

### V2-Only Features

1. **Dedicated List View**: Separate page showing all entries in table format
   - Location: `lib/gallformers_web/live/admin/glossary_live/index.ex:100-154`
   - Better overview and navigation

2. **Real-time Updates via PubSub**: Live updates when data changes
   - Location: `lib/gallformers/glossaries.ex:147-161`
   - Auto-refreshes list when entry created/updated/deleted

3. **Discard Confirmation Modal**: Warns about unsaved changes
   - Location: `lib/gallformers_web/live/admin/form_helpers.ex:480-512`
   - Prevents accidental data loss

4. **Schema-driven Required Fields**: Required fields defined in schema
   - Location: `lib/gallformers/glossaries/glossary.ex:12`
   - Single source of truth for validation

5. **Additional Query Functions**:
   - `list_glossary_by_letter/1`: For alphabetical navigation
   - `get_letter_counts/0`: For showing letter distribution
   - `count_glossary/0`: Total entry count

---

## Validation Comparison

### V1 Validation

```typescript
// v1/pages/admin/glossary.tsx:124-127
{...adminForm.form.register('definition', {
    required: 'You must provide a definition',
    disabled: !adminForm.selected,
})}
```

- Client-side validation via react-hook-form
- Required fields: definition, urls (word via typeahead)
- No length validation
- Duplicate word check via API call

### V2 Validation

```elixir
# lib/gallformers/glossaries/glossary.ex:33-40
def changeset(glossary, attrs) do
  glossary
  |> cast(attrs, [:word, :definition, :urls])
  |> validate_required(@required_fields)
  |> validate_length(:word, min: 1, max: 100)
  |> validate_length(:definition, min: 1)
  |> unique_constraint(:word)
end
```

- Server-side validation via Ecto changeset
- Required: word, definition, urls
- Word: 1-100 characters
- Definition: min 1 character
- Unique constraint on word

---

## Recommendations

### Completed Well

1. **Separation of concerns**: V2 properly separates list and form into distinct LiveViews
2. **Real-time updates**: PubSub integration keeps multiple browser sessions in sync
3. **FormHelpers pattern**: Standardized CRUD reduces boilerplate across admin pages
4. **Schema-driven validation**: Single source of truth for required fields
5. **RESTful routing**: Clean URL structure with route params

### Potential Improvements

1. **Search enhancement**: V2 could add search on definition field (currently word-only in filter, but search_glossary searches both)
2. **Bulk operations**: Neither version supports bulk delete/export
3. **Preview**: Could show how term will appear in glossary popover
4. **URL validation**: Neither version validates URL format in urls field
5. **Sort options**: Table could support sorting by different columns

---

## Migration Notes

- Data model is identical: `id`, `word`, `definition`, `urls` (all strings, urls newline-separated)
- No data migration needed
- V2 drops the dedicated rename functionality in favor of direct field editing
- V2 adds letter-based filtering not used in admin but available for future use
