# Glossary Page: V1 vs V2 Comparison

**Route**: `/glossary`

## V1 Implementation

### Files

| File | Purpose | Lines |
|------|---------|-------|
| `v1/pages/glossary.tsx` | Main page component | 1-125 |
| `v1/libs/db/glossary.ts` | Database access layer | 1-101 |
| `v1/libs/pages/glossary.ts` | Cross-linking logic (unused) | 1-150 |
| `v1/components/DataTable.tsx` | Table wrapper component | 1-12 |
| `v1/components/Edit.tsx` | Auth-gated edit button | 1-26 |
| `v1/libs/utils/DataTableConstants.ts` | Table styling | 1-28 |

### Admin Files

| File | Purpose | Lines |
|------|---------|-------|
| `v1/pages/admin/glossary.tsx` | Admin CRUD form | 1-167 |
| `v1/pages/api/glossary/index.ts` | List/search API | 1-18 |
| `v1/pages/api/glossary/[id].ts` | Delete API | 1-11 |
| `v1/pages/api/glossary/upsert.ts` | Create/update API | 1-7 |
| `v1/pages/api/glossary/word/[word].ts` | Lookup by word API | 1-25 |

## V2 Implementation

### Files

| File | Purpose | Lines |
|------|---------|-------|
| `lib/gallformers_web/live/glossary_live.ex` | LiveView page | 1-156 |
| `lib/gallformers/glossaries.ex` | Context module | 1-162 |
| `lib/gallformers/glossaries/glossary.ex` | Ecto schema | 1-42 |

### Admin Files

| File | Purpose | Lines |
|------|---------|-------|
| `lib/gallformers_web/live/admin/glossary_live/index.ex` | Admin list page | 1-173 |
| `lib/gallformers_web/live/admin/glossary_live/form.ex` | Admin edit form | 1-143 |
| `lib/gallformers_web/controllers/api/glossary_controller.ex` | REST API | 1-160 |

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **UI Framework** | React + react-data-table-component | Phoenix LiveView + Tailwind | Complete | V2 uses native HTML table |
| **Styling** | React Bootstrap + custom TABLE_CUSTOM_STYLES | Tailwind + `.gf-table` class | Complete | V2 consistent with site design |
| **Data Fetching** | `getStaticProps` with ISR (revalidate: 1s) | LiveView mount query | Complete | V2 is real-time, no caching |
| **Sorting: Word** | Yes (DataTable sortable column) | Yes (client-side, lines 38-51) | Complete | Both ascending/descending |
| **Sorting: Definition** | Yes (DataTable sortable column) | Yes (lines 38-51) | Complete | |
| **Sorting: Refs** | Yes (`sort: true` on column) | No | Missing | V2 lacks refs sorting |
| **Default Sort** | Word ascending (`defaultSortFieldId`) | Word ascending (line 27) | Complete | |
| **Search/Filter** | DataTable built-in filter | None on public page | Missing | V1 has search; V2 only admin has search |
| **Word Column** | Bold, with Edit button | Bold only | Partial | V2 missing edit button |
| **Definition Column** | Plain text (`.padded-table-cell`) | Gray text (`text-gray-600`) | Complete | |
| **Refs Column** | Numbered links (1, 2, 3...) | Numbered links | Complete | Same format |
| **Row Anchors** | `id={word.toLowerCase()}` | `id={String.downcase(word)}` | Complete | Both support hash navigation |
| **Edit Button** | Auth-gated (NextAuth session) | Not present on public page | Missing | V1 shows edit icon for logged-in users |
| **Empty State** | None shown | Gray box with message | Complete | V2 better UX |
| **Entry Count** | None shown | "Showing X entries" | Enhanced | V2 improvement |
| **Cross-linking** | Code exists but disabled (line 106) | Not implemented | Parity | Feature was disabled in V1 |
| **SEO/Meta** | `<Head>` with title + description | `page_title`, `page_description` | Complete | |

---

## UI Layer Comparison

### V1 Public Page (lines 55-111)
- Uses `react-data-table-component` wrapped in custom DataTable component
- Three columns: Word, Definition, Refs
- Word column includes `<Edit>` component for authenticated users
- Striped rows, no header, custom styling via `TABLE_CUSTOM_STYLES`
- Container layout with React Bootstrap grid

### V2 Public Page (lines 77-155)
- Native HTML table with Tailwind styling
- Same three columns: Word, Definition, Refs
- Sortable headers with click handlers and arrow indicators
- Clean card layout with shadow
- Entry count footer
- Empty state message

### V1 Admin Page (lines 62-154)
- Uses `useAdmin` hook with react-hook-form
- Typeahead for word selection from existing entries
- Textarea for definition and URLs
- Rename functionality via modal
- Delete and Save buttons
- Server-side props fetch all entries

### V2 Admin Page (Form: lines 67-142, Index: lines 78-161)
- FormHelpers behavior for CRUD operations
- Search/filter on admin list
- Dedicated edit form LiveView
- PubSub for real-time updates
- Confirm dialogs for delete
- Table actions with edit/view/delete buttons

---

## Business Logic Comparison

### Data Access

| Function | V1 Location | V2 Location | Notes |
|----------|-------------|-------------|-------|
| List all | `allGlossaryEntries()` (line 11-24) | `list_glossary()` (line 17-22) | V1 uses raw SQL for COLLATE NOCASE |
| Search | `searchGlossary(s)` (line 89-91) | `search_glossary(query)` (line 47-57) | V2 searches word AND definition |
| Get by word | `getEntryByWord(word)` (line 98-100) | `get_glossary_by_word(word)` (line 36-41) | |
| Delete | `deleteGlossaryEntry(id)` (line 26-45) | `delete_glossary(entry)` (line 133-136) | |
| Upsert | `upsertGlossary(entry)` (line 47-68) | `create_glossary/update_glossary` (line 110-127) | V2 separates create/update |
| By letter | None | `list_glossary_by_letter(letter)` (line 74-82) | V2 extra feature |
| Count | None | `count_glossary()` (line 63-68) | V2 extra feature |
| Letter counts | None | `get_letter_counts()` (line 88-95) | V2 extra feature for nav |

### Sorting

**V1**: Client-side via `react-data-table-component` (built-in)
- Columns marked `sortable: true`
- Default sort on "word" column

**V2**: Client-side in LiveView (lines 53-64)
- `sorted_entries/3` function sorts in memory
- Case-insensitive via `String.downcase/1`
- Toggle direction on same column click

### Search

**V1** (db/glossary.ts line 89-91):
```typescript
return getEntries({ word: { contains: s } });
```
- Searches word field only
- Case-sensitive (Prisma default)

**V2** (glossaries.ex lines 47-57):
```elixir
where:
  fragment("lower(?) LIKE ?", g.word, ^search_term) or
    fragment("lower(?) LIKE ?", g.definition, ^search_term)
```
- Searches word AND definition
- Case-insensitive

---

## Data Layer Comparison

### Schema

| Field | V1 Type (Prisma) | V2 Type (Ecto) | Required |
|-------|------------------|----------------|----------|
| id | Int (auto) | Integer (auto) | Yes |
| word | String | :string | Yes |
| definition | String | :string | Yes |
| urls | String | :string | Yes |

**V1**: `Entry` type in `v1/libs/api/apitypes.ts` (lines 692-697)
**V2**: Schema in `lib/gallformers/glossaries/glossary.ex` (lines 21-25)

### Validations

**V1** (admin form, lines 124-149):
- Word: required via react-hook-form
- Definition: required
- URLs: required

**V2** (schema changeset, lines 33-40):
- Word: required, length 1-100, unique constraint
- Definition: required, min length 1
- URLs: required

V2 has stronger server-side validation with length constraints.

---

## API Comparison

| Endpoint | V1 Route | V2 Route | Notes |
|----------|----------|----------|-------|
| List all | GET /api/glossary | GET /api/v2/glossary | |
| Search | GET /api/glossary?q=term | GET /api/v2/glossary?q=term | V2 adds pagination |
| Get by ID | N/A | GET /api/v2/glossary/:id | V2 new |
| Get by word | GET /api/glossary/word/:word | GET /api/v2/glossary/by-word/:word | |
| Delete | DELETE /api/glossary/:id | Admin only (no API) | V2 admin-only delete |
| Upsert | POST /api/glossary/upsert | Admin only (no API) | V2 admin-only create/update |

**V2 API Enhancements**:
- Pagination support (`limit`, `offset` params)
- OpenAPI/Swagger documentation
- Consistent JSON response structure with `data`, `total`, `limit`, `offset`

---

## Missing Features in V2

1. **Edit Button on Public Page**: V1 shows a pencil icon for authenticated users to quickly edit entries. V2 requires navigating to admin.

2. **Built-in Search/Filter**: V1's DataTable has built-in filtering. V2 public page has no search (only admin has search).

3. **Refs Column Sorting**: V1 allows sorting by refs column, V2 does not.

4. **Cross-linking** (both disabled): V1 has code for stemming and auto-linking glossary terms in definitions (using natural.js). This was disabled (`// for now turning this off`) but the infrastructure exists. V2 does not have this.

---

## V2 Enhancements Over V1

1. **Real-time Updates**: PubSub broadcasts changes to all connected clients.

2. **Better Empty State**: User-friendly message when no entries found.

3. **Entry Count Display**: Shows total number of entries.

4. **Enhanced Search**: V2 context searches both word AND definition (case-insensitive).

5. **Additional Query Functions**: `list_glossary_by_letter/1`, `count_glossary/0`, `get_letter_counts/0` for future alphabetical navigation.

6. **Stronger Validations**: Length constraints and unique word constraint in schema.

7. **Proper API Design**: RESTful endpoints with pagination, OpenAPI docs.

8. **Admin UX**: Dedicated list and form pages with search, better action buttons.

---

## Recommendations

### High Priority

1. **Add Search to Public Page**: Port the search functionality from admin to public glossary page. The context already has `search_glossary/1`.

2. **Add Edit Button for Auth Users**: The V1 pattern of showing an edit pencil for authenticated users is valuable for curators.

### Medium Priority

3. **Add Refs Sorting**: Allow sorting by reference count if useful.

4. **Alphabetical Navigation**: V2 context has `get_letter_counts/0` - could add A-Z quick links.

### Low Priority

5. **Cross-linking**: Consider reviving the auto-linking feature for glossary terms in definitions. This was disabled in V1 but could enhance educational value.

---

## File Reference Summary

**V1 Key Files**:
- Main page: `/Users/jeff/dev/gallformers/v1/pages/glossary.tsx`
- Database: `/Users/jeff/dev/gallformers/v1/libs/db/glossary.ts`
- Admin: `/Users/jeff/dev/gallformers/v1/pages/admin/glossary.tsx`

**V2 Key Files**:
- LiveView: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/glossary_live.ex`
- Context: `/Users/jeff/dev/gallformers/lib/gallformers/glossaries.ex`
- Schema: `/Users/jeff/dev/gallformers/lib/gallformers/glossaries/glossary.ex`
- Admin Index: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/glossary_live/index.ex`
- Admin Form: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/glossary_live/form.ex`
- API: `/Users/jeff/dev/gallformers/lib/gallformers_web/controllers/api/glossary_controller.ex`
