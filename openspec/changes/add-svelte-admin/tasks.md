# Tasks: Add Svelte Admin Interface

## Dependencies

- **Blocked by**: `define-v2-foundation` (v2/ directory must exist)
- **Partial dependency**: `add-go-api` (API endpoints needed for data operations)
- **Partial dependency**: `add-image-processing` (Images page only)

## Phase 1: Foundation (Parallelizable with add-go-api)

### 1.1 Tailwind Configuration
- [ ] Configure `tailwind.config.js` with brand colors from umbrella spec:
  - `gf-sky-blue`: #c1e0f3
  - `gf-autumn`: #bc6428
  - `gf-maroon`: #661419
  - `cadet-blue`: #96adc8
  - `canary`: #f8f991
- [ ] Add League Spartan font configuration
- [ ] Copy Font Awesome icons or configure Lucide
- [ ] Create `app.css` with base styles

**Validation**: Visual inspection - colors match v1 branding

### 1.2 Component Library: Forms
- [ ] Create `Input` component with label, error, required states
- [ ] Create `Select` component for single selection
- [ ] Create `Checkbox` component
- [ ] Create `Textarea` component
- [ ] Create `MultiSelect` component for filter fields
- [ ] Install `svelte-select` package and verify Svelte 5 compatibility (consult owner if issues)
- [ ] Create `Typeahead` wrapper component (see design.md for interface)
- [ ] Configure svelte-select CSS variables for brand colors

**Validation**: Storybook-style demo page showing all components with sync data. Async search validation deferred to Phase 2 when API exists.

### 1.3 Component Library: Layout
- [ ] Create `Modal` component (base)
- [ ] Create `ConfirmModal` variant with danger styling, Cancel focused
- [ ] Create `Card` component
- [ ] Create `Breadcrumb` component
- [ ] Create `Button` component with variants (primary, secondary, danger, ghost)

**Validation**: Demo page showing modal variants, confirm behavior

### 1.4 Component Library: Data
- [ ] Create `Table` component with sortable columns
- [ ] Add pagination to Table
- [ ] Create `EditableTable` component for inline add/remove rows (used for aliases)
- [ ] Create `Spinner` component (inline and full-page variants)
- [ ] Create `Alert` component for messages
- [ ] Create `RangeMap.svelte` - shared map component using d3-geo + TopoJSON (see add-svelte-public design.md)
- [ ] Create `EditableRangeMap.svelte` - admin wrapper with toggle logic, legend, Select All/Deselect All buttons

**Validation**: Demo page with sortable, paginated table; editable table supports add/remove rows; map toggles states on click

### 1.5 State Management Setup
- [ ] Create `toast` store for notifications
- [ ] Create `ToastContainer` component
- [ ] Create `auth` store with `initAuth()`, `login()`, `logout()` (see design.md)
- [ ] Create derived stores: `user`, `authLoading`, `isAdmin`, `isSuperAdmin`
- [ ] Create auth guard logic for admin layout

**Validation**: Toast notifications appear and auto-dismiss

### 1.6 Login Page
- [ ] Create `/login/+page.svelte` with "Log in with Auth0" button
- [ ] Handle `?redirect=` query param for post-login redirect
- [ ] Redirect to `/admin` if already logged in

**Validation**: Login button redirects to Auth0, returns to original page after auth

### 1.7 Admin Layout
- [ ] Create `routes/admin/+layout.svelte` with auth guard
- [ ] Create `AdminNav` component with page links
- [ ] Add Super Admin section to nav (conditionally visible)
- [ ] Add user menu (username display with dropdown containing Logout)
- [ ] Create responsive layout (sidebar on desktop, hamburger on mobile)

**Validation**: Navigate between admin routes, nav highlights current page, logout works

### 1.8 Error Handling
- [ ] Create `routes/admin/+error.svelte` for admin error fallback
- [ ] Create `routes/+error.svelte` for global error fallback
- [ ] Create `NotFound` component for "Entity not found" inline messages
- [ ] Establish page state pattern: loading / error / notFound / success

**Validation**: Invalid entity ID shows "not found" message; unexpected errors show error page

### 1.9 Testing Infrastructure
- [ ] Configure Vitest for unit/component tests
- [ ] Configure @testing-library/svelte
- [ ] Configure Playwright for E2E tests
- [ ] Create test helpers (mock API, mock auth)
- [ ] Add test scripts to package.json (`test`, `test:e2e`, `test:coverage`)
- [ ] Write unit tests for auth store (100% coverage)
- [ ] Write unit tests for toast store (100% coverage)
- [ ] Write component tests for each form component (Input, Select, Checkbox, etc.)
- [ ] Write component tests for layout components (Modal, ConfirmModal, Button, etc.)
- [ ] Write component tests for data components (Table, EditableTable, etc.)

**Validation**: `yarn test` passes; component coverage >80%

---

## Phase 2: Core Pages (Requires add-go-api endpoints)

### 2.1 API Client Setup
- [ ] Generate TypeScript client from OpenAPI spec
- [ ] Create `api` module with configured clients
- [ ] Add auth header injection middleware
- [ ] Add error handling wrapper

**Validation**: Can fetch data from running Go API

### 2.2 Dashboard Page
- [ ] Create `/admin/+page.svelte`
- [ ] Add links to all admin pages (matching v1 structure)
- [ ] Show Super Admin section only for super admins
- [ ] Add help/support links

**Validation**: Dashboard matches v1 layout

### 2.3 Gall Page (Most Complex)

Read v1 `pages/admin/gall.tsx` before implementing.

- [ ] Create `/admin/gall/+page.svelte`
- [ ] Implement entity search/select typeahead
- [ ] Create `UndescribedModal.svelte` component (see design.md for workflow)
- [ ] Implement "Add Undescribed" button that opens modal
- [ ] Create `RenameModal.svelte` component (see design.md for workflow)
- [ ] Add Name field with rename button that opens modal
- [ ] Add Genus field (auto-filled from name)
- [ ] Add Family field (required, typeahead)
- [ ] Add Hosts field (required, async multi-select)
- [ ] Add Detachable field (single select)
- [ ] Add filter property fields: walls, cells, alignment, color, shape, season, form, location, texture
- [ ] Add Abundance field (single select)
- [ ] Add Aliases table (inline add/remove)
- [ ] Add "Data Complete" checkbox
- [ ] Add "Undescribed" checkbox
- [ ] Implement validation:
  - Name required
  - Family required
  - At least one host required
  - Warn if Unknown genus/family but not marked undescribed
- [ ] Implement unsaved changes warning (beforeNavigate + beforeunload)
- [ ] Implement save (create/update) with URL update
- [ ] Implement delete with confirmation modal

**Validation**:
- Can create new gall with all fields
- Can edit existing gall
- Can delete gall (confirmation appears)
- Validation errors display inline
- All Core Behavioral Expectations from umbrella preserved

### 2.4 Host Page

Read v1 `pages/admin/host.tsx` before implementing.

- [ ] Create `/admin/host/+page.svelte`
- [ ] Implement entity search/select
- [ ] Add Name, Genus, Family fields (similar to Gall)
- [ ] Add host-specific fields (Section, Abundance)
- [ ] Add Aliases table
- [ ] Add EditableRangeMap for geographic distribution
- [ ] Implement CRUD operations
- [ ] Implement validation

**Validation**: Feature parity with v1 Host page; range map toggles work

### 2.5 Browse Pages

Read v1 `pages/admin/browse/*.tsx` before implementing.

- [ ] Create `/admin/browse/galls/+page.svelte` with sortable table
- [ ] Create `/admin/browse/hosts/+page.svelte`
- [ ] Create `/admin/browse/sources/+page.svelte`
- [ ] Add links to edit pages from table rows

**Validation**: Tables display data, sorting works, links navigate correctly

### 2.6 E2E Tests for Core Pages

**Test data strategy**: E2E tests run against a copy of the production database. Prod data is mostly stable (changes are additive). If needed later, create SQL script for stable test fixtures.

- [ ] Write E2E test: login/logout flow
- [ ] Write E2E test: Gall CRUD (create, read, update, delete)
- [ ] Write E2E test: Host CRUD with range map interaction
- [ ] Write E2E test: delete confirmation modal behavior
- [ ] Write E2E test: form validation error display
- [ ] Write E2E test: Super Admin access control

**Validation**: `yarn test:e2e` passes

---

## Phase 3: Supporting Pages

### 3.1 Source Page

Read v1 `pages/admin/source.tsx` before implementing.

- [ ] Create `/admin/source/+page.svelte`
- [ ] Handle multiple source types (book, journal, website, etc.)
- [ ] Implement CRUD operations
- [ ] Add author/title/year/etc fields per source type

**Validation**: Can create/edit/delete sources of all types

### 3.2 Glossary Page

Read v1 `pages/admin/glossary.tsx` before implementing.

- [ ] Create `/admin/glossary/+page.svelte`
- [ ] Simple CRUD form (word, definition, urls)
- [ ] Implement search/filter

**Validation**: Feature parity with v1

### 3.3 Section Page

Read v1 `pages/admin/section.tsx` before implementing.

- [ ] Create `/admin/section/+page.svelte`
- [ ] Simple CRUD form

**Validation**: Feature parity with v1

### 3.4 Place Page (Super Admin)

Read v1 `pages/admin/place.tsx` before implementing.

- [ ] Create `/admin/place/+page.svelte`
- [ ] Add Super Admin gate
- [ ] Simple CRUD form (name, code, type)

**Validation**: Non-super-admin sees access denied

### 3.5 Taxonomy Page (Super Admin)

Read v1 `pages/admin/taxonomy.tsx` before implementing.

- [ ] Create `/admin/taxonomy/+page.svelte`
- [ ] Add Super Admin gate
- [ ] Handle tree structure (parent selection)
- [ ] Show taxonomy hierarchy
- [ ] Implement CRUD operations

**Validation**: Can create/edit taxonomy entries with parent relationships

### 3.6 FilterTerms Page (Super Admin)

Read v1 `pages/admin/filterterms.tsx` before implementing.

- [ ] Create `/admin/filterterms/+page.svelte`
- [ ] Add Super Admin gate
- [ ] Handle multiple field types (location, color, shape, etc.)
- [ ] Implement CRUD per field type

**Validation**: Can manage filter terms for all field types

---

## Phase 4: Relationship Pages

### 4.1 Gallhost Page

Read v1 `pages/admin/gallhost.tsx` before implementing.

- [ ] Create `/admin/gallhost/+page.svelte`
- [ ] Gall selection (typeahead)
- [ ] Genus-level host mapping interface
- [ ] Show existing mappings
- [ ] Add/remove mappings

**Validation**: Can map galls to hosts at genus level

### 4.2 Speciessource Page

Read v1 `pages/admin/speciessource.tsx` before implementing.

- [ ] Create `/admin/speciessource/+page.svelte`
- [ ] Species selection
- [ ] Source selection
- [ ] Description text field (from source)
- [ ] Implement CRUD for species-source links

**Validation**: Can link species to sources with descriptions

### 4.3 Species Direct Edit Page (Super Admin)

Read v1 `pages/admin/[id]/index.tsx` before implementing.

- [ ] Create `/admin/species/[id]/+page.svelte`
- [ ] Add Super Admin gate
- [ ] Load species by ID
- [ ] Allow direct field editing
- [ ] Save changes

**Validation**: Can edit species directly by ID

---

## Phase 5: Images Page (Requires add-image-processing)

### 5.1 Images Page

Read v1 `pages/admin/images.tsx` before implementing.

- [ ] Create `/admin/images/+page.svelte`
- [ ] Integrate with image processing API from `add-image-processing`
- [ ] Implement upload interface
- [ ] Show image preview
- [ ] Implement image assignment to species
- [ ] Implement delete with confirmation

**Validation**: Full image workflow functional

---

## Final Validation

### Code Quality
- [ ] Run TypeScript type checking - zero errors
- [ ] Run ESLint - zero errors
- [ ] Measure LOC - confirm 50%+ reduction vs v1

### Feature Parity
- [ ] All 16 admin routes functional
- [ ] All CRUD operations work
- [ ] All validation rules match v1
- [ ] Super Admin gating works correctly

### Core Behavioral Expectations
- [ ] Delete confirmations: danger variant, Cancel focused, explains cascade
- [ ] Two-tier auth: Admin vs Super Admin pages
- [ ] Form validation: inline field errors
- [ ] Error handling: toast for API errors, 404 for invalid IDs

### Cross-browser Testing
- [ ] Chrome - full functionality
- [ ] Firefox - full functionality
- [ ] Safari - full functionality
- [ ] Mobile responsive - admin nav works on small screens

---

## Notes

### Parallelization
- Phase 1 (Foundation) can run entirely in parallel with `add-go-api`
- Phase 2-4 pages can be stubbed with mock data before API is ready
- Use OpenAPI spec to generate types even before API implementation

### Implementation Order Rationale
1. **Gall first**: Most complex page, validates all component patterns
2. **Host second**: Similar complexity, confirms patterns are reusable
3. **Browse pages**: Validates Table component with real data
4. **Simple pages**: Quick wins once patterns established
5. **Images last**: Blocked by separate image processing work
