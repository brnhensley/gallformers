# Design: Svelte Admin Interface

## Context

The v1 admin interface has 16 pages totaling 5000+ LOC. The complexity stems from:
- React Hook Form boilerplate with Controllers
- fp-ts Option/Either patterns for null handling
- No shared component library (each page re-implements patterns)
- Next.js SSR data fetching mixed with client-side state

Svelte's two-way binding and simpler reactivity model should significantly reduce code complexity.

## Framework Versions

- **Svelte 5** - Uses runes (`$state`, `$derived`, `$effect`, `$props`)
- **SvelteKit 2** - Latest routing and build system

All code examples in this document use Svelte 5 runes syntax.

---

## Architecture Overview

```
v2/web/src/
├── routes/
│   └── admin/
│       ├── +layout.svelte       # Auth guard, admin nav
│       ├── +page.svelte         # Dashboard
│       ├── gall/
│       │   └── +page.svelte     # Gall CRUD
│       ├── host/
│       │   └── +page.svelte     # Host CRUD
│       ├── browse/
│       │   ├── galls/+page.svelte
│       │   ├── hosts/+page.svelte
│       │   └── sources/+page.svelte
│       └── ...
├── lib/
│   ├── components/
│   │   ├── forms/               # Form components
│   │   ├── layout/              # Modal, Card, etc
│   │   └── data/                # Table, etc
│   ├── stores/                  # Global state (auth, toasts)
│   └── api/                     # Generated API client
└── app.css                      # Tailwind + custom styles
```

---

## Component Library

The admin interface uses the **shared component library** from `add-svelte-common`. See that proposal's `design.md` for full component implementations.

### Common Components (from add-svelte-common)

Import shared components from `$lib/components`:

```typescript
import {
  // Forms
  Input, Select, Checkbox, MultiSelect, Typeahead, Button,
  // Layout
  Modal, ConfirmModal, Card, Alert, Spinner,
  // Data
  Table, RangeMap,
  // Feedback
  ToastContainer, toast
} from '$lib/components';
```

### Admin-Specific Components

These components are unique to the admin interface and live in `routes/admin/components/`:

#### Breadcrumb

Generic path-based breadcrumb for admin pages (different from public's `TaxonomyBreadcrumb`):

```svelte
<Breadcrumb items={[
  { label: 'Admin', href: '/admin' },
  { label: 'Galls', href: '/admin/gall' },
  { label: species?.name ?? 'New' }
]} />
```

#### EditableRangeMap

Wraps the shared `RangeMap` component with admin editing features:

```svelte
<!-- EditableRangeMap.svelte -->
<script lang="ts">
  import { RangeMap } from '$lib/components';

  let {
    inRange = $bindable(new Map()),
    excludedRange = $bindable(new Map())
  } = $props();

  function toggle(code: string) {
    // Three-state cycle: in-range → excluded → neither → in-range
    if (inRange.has(code)) {
      const place = inRange.get(code);
      inRange.delete(code);
      excludedRange.set(code, place);
    } else if (excludedRange.has(code)) {
      excludedRange.delete(code);
    } else {
      // Add to in-range (would need place data from lookup)
    }
    inRange = inRange;
    excludedRange = excludedRange;
  }

  function selectAll() { /* ... */ }
  function deselectAll() { /* ... */ }
</script>

<div class="flex gap-4">
  <div class="flex-1">
    <RangeMap
      inRange={new Set(inRange.keys())}
      excludedRange={new Set(excludedRange.keys())}
      editable
      onToggle={toggle}
    />
  </div>
  <div class="w-48 space-y-4">
    <div class="text-sm">
      <div class="flex items-center gap-2">
        <span class="w-4 h-4 bg-[#228B22]"></span> In Range
      </div>
      <div class="flex items-center gap-2">
        <span class="w-4 h-4 bg-[#F08080]"></span> Excluded
      </div>
      <div class="flex items-center gap-2">
        <span class="w-4 h-4 bg-white border"></span> Neither
      </div>
    </div>
    <Button variant="secondary" onclick={selectAll}>Select All</Button>
    <Button variant="secondary" onclick={deselectAll}>Deselect All</Button>
  </div>
</div>
```

#### AdminNav

Navigation component for admin pages (shows/hides Super Admin section based on role).

#### NotFound

Simple "entity not found" display for invalid IDs.

---

## Page Patterns

### Standard CRUD Page Structure

Each admin page follows this pattern (Svelte 5):

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { api } from '$lib/api';

  // State (Svelte 5 runes)
  let selected: GallApi | null = $state(null);
  let isLoading = $state(false);
  let errors: Record<string, string> = $state({});

  // Load if editing existing (Svelte 5 effect)
  $effect(() => {
    const id = $page.url.searchParams.get('id');
    if (id) {
      loadGall(id);
    }
  });

  async function loadGall(id: string) { ... }
  async function save() { ... }
  async function remove() { ... }

  // Update URL when selection changes
  function selectEntity(entity: GallApi | null) {
    selected = entity;
    if (entity) {
      goto(`?id=${entity.id}`, { replaceState: true, noScroll: true });
    } else {
      goto('', { replaceState: true, noScroll: true });
    }
  }
</script>
```

### URL and Deep Linking

Admin pages support deep linking via query parameters:

**Behavior:**
- URL updates when user selects an entity: `/admin/gall` → `/admin/gall?id=123`
- URL clears when user deselects: `/admin/gall?id=123` → `/admin/gall`
- Direct navigation to `/admin/gall?id=123` loads that entity
- Browser back/forward navigates between selections

**Implementation:**
```typescript
// On selection change
goto(`?id=${entity.id}`, { replaceState: true, noScroll: true });

// On deselection
goto('', { replaceState: true, noScroll: true });

// replaceState: true - don't add history entry for every selection
// noScroll: true - don't scroll to top on URL change
```

**Edge cases:**
- Invalid ID in URL → show "Entity not found" (see Page State Pattern)
- Entity deleted while viewing → clear URL, show success toast
- User navigates away with unsaved changes → see Unsaved Changes Warning

### Unsaved Changes Warning

Prevent accidental data loss when user navigates away from a modified form.

**When to warn:**
- User clicks a nav link while form has unsaved changes
- User clicks browser back/forward with unsaved changes
- User closes tab/window with unsaved changes
- User selects a different entity in typeahead with unsaved changes

**Implementation approach:**

```svelte
<script lang="ts">
  import { beforeNavigate } from '$app/navigation';
  import { onMount } from 'svelte';

  // Track dirty state at field level (more robust than JSON.stringify comparison)
  let dirtyFields = $state(new Set<string>());

  // Mark field as dirty when changed
  function markDirty(field: string) {
    dirtyFields.add(field);
  }

  // Check if any field is dirty
  let isDirty = $derived(dirtyFields.size > 0);

  // Reset dirty tracking after load or save
  function markClean() {
    dirtyFields = new Set();
  }

  // SvelteKit navigation guard
  beforeNavigate(({ cancel }) => {
    if (isDirty) {
      if (!confirm('You have unsaved changes. Leave anyway?')) {
        cancel();
      }
    }
  });

  // Browser close/refresh guard
  onMount(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (isDirty) {
        e.preventDefault();
        e.returnValue = ''; // Required for Chrome
      }
    };
    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  });
</script>
```

**Dirty state detection:**
- Use deep comparison of `formData` vs `initialData` (snapshot at load/save time)
- `JSON.stringify` comparison is simple and sufficient for our data shapes
- Reset `initialData` after successful save or when loading new entity

**UX considerations:**
- Use browser's native `confirm()` for navigation - matches user expectations
- `beforeunload` shows browser's standard dialog (cannot be customized)
- Don't warn if form is empty (no entity selected)
- Don't warn after successful delete (entity is gone)

**Why this works better than v1:**
- v1's `isDirty` relied on react-hook-form which had issues with typeahead components
- Field-level tracking avoids JSON.stringify edge cases (array ordering, nested objects)
- Explicit per-field tracking vs implicit form library tracking

<AdminLayout title="Gall">
  <Breadcrumb items={...} />

  <div class="space-y-6">
    <!-- Entity picker (typeahead) -->
    <Typeahead
      bind:selected
      searchFn={searchGalls}
      label="Search galls or create new"
      ...
    />

    {#if selected}
      <Card title="Details">
        <!-- Form fields -->
      </Card>

      <Card title="Properties">
        <!-- More fields -->
      </Card>

      <div class="flex justify-end space-x-4">
        <Button variant="danger" on:click={() => showDeleteConfirm = true}>
          Delete
        </Button>
        <Button variant="primary" on:click={save}>
          Save
        </Button>
      </div>
    {/if}
  </div>

  <ConfirmModal bind:open={showDeleteConfirm} ... />
</AdminLayout>
```

### Admin Layout

Shared layout wrapping all admin pages (Svelte 5):

```svelte
<!-- routes/admin/+layout.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  import { user, authLoading } from '$lib/stores/auth';
  import { goto } from '$app/navigation';

  let { children } = $props();

  // Auth guard (Svelte 5 effect)
  $effect(() => {
    if (!$authLoading && !$user) {
      goto('/login?redirect=' + encodeURIComponent($page.url.pathname));
    }
  });
</script>

{#if $authLoading}
  <div class="min-h-screen flex items-center justify-center">
    <p>Loading...</p>
  </div>
{:else if $user}
  <div class="min-h-screen bg-gray-50">
    <AdminNav />
    <main class="max-w-7xl mx-auto px-4 py-8">
      {@render children()}
    </main>
  </div>
{/if}
```

### Super Admin Gating

Some pages require Super Admin role:

```svelte
<!-- routes/admin/taxonomy/+page.svelte -->
<script lang="ts">
  import { user, isSuperAdmin } from '$lib/stores/auth';
</script>

{#if $isSuperAdmin}
  <!-- taxonomy form -->
{:else}
  <Alert variant="warning">
    This page requires Super Admin access.
  </Alert>
{/if}
```

---

## State Management

### Auth Store

```typescript
// lib/stores/auth.ts
import { writable, derived } from 'svelte/store';

interface User {
  id: string;
  name: string;
  email: string;
  roles: string[];
}

export const user = writable<User | null>(null);
export const isSuperAdmin = derived(user, $u => $u?.roles.includes('super_admin') ?? false);

export async function initAuth() {
  // Fetch user from API or decode JWT
}

export async function logout() {
  // Clear token, redirect to login
}
```

### Page State Pattern

Each CRUD page handles four states explicitly (Svelte 5):

```svelte
<script lang="ts">
  type PageState = 'loading' | 'notFound' | 'error' | 'ready';
  let pageState: PageState = $state('loading');
  let errorMessage = $state('');

  async function loadEntity(id: string) {
    pageState = 'loading';
    try {
      const res = await api.galls.getGall(id);
      if (!res) {
        pageState = 'notFound';
      } else {
        selected = res;
        pageState = 'ready';
      }
    } catch (e) {
      errorMessage = e.message;
      pageState = 'error';
    }
  }
</script>

{#if pageState === 'loading'}
  <Spinner />
{:else if pageState === 'notFound'}
  <NotFound message="Gall not found" />
{:else if pageState === 'error'}
  <Alert variant="error">{errorMessage}</Alert>
{:else}
  <!-- form content -->
{/if}
```

### Undescribed Species Workflow

The Gall page has a special "Add Undescribed" flow for creating gall records when the species hasn't been formally described. This is a multi-step modal workflow.

**When to use:** When a user finds a gall that doesn't match any known species but wants to document it for future identification.

**Modal Steps:**

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: Genus Known?                                       │
│  ☐ Is this undescribed species part of a known Genus?       │
│                                                             │
│  If YES → Select Genus (typeahead) → Family auto-fills      │
│  If NO  → Select Family (typeahead) → Genus = "Unknown"     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Step 2: Type Host                                          │
│  Select the primary host plant (required, async typeahead)  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Step 3: Description                                        │
│  Enter 2-3 adjectives separated by dashes                   │
│  Example: "red-bead-gall"                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Step 4: Name (auto-generated, editable)                    │
│  Format: "{Genus} {host-abbrev}-{description}"              │
│  Example: "Unknown q-alba-red-bead-gall"                    │
│                                                             │
│  [Done] [Cancel]                                            │
│  Done disabled until all required fields filled             │
└─────────────────────────────────────────────────────────────┘
```

**Name generation logic:**
- Host abbreviation: first letter of genus (lowercase) + hyphen + species epithet
- Example: "Quercus alba" → "q-alba"
- Full name: `{Genus} {host-abbrev}-{description}`

**Validation before Done:**
- All fields required (genus, family, host, description, name)
- Check if name already exists in database → error if duplicate

**On completion:**
- Returns data to parent Gall page
- Parent creates new gall with:
  - `undescribed = true`
  - Selected genus, family, host
  - Generated name
- Form switches to edit mode for the new gall

**Additional validation on Gall save:**
- If genus or family is "Unknown" but `undescribed` checkbox is not checked, show warning confirmation

**Svelte 5 implementation sketch:**

```svelte
<!-- UndescribedModal.svelte -->
<script lang="ts">
  import { api } from '$lib/api';

  let { open = $bindable(false), genera, families, onComplete } = $props();

  let genusKnown = $state(false);
  let genus = $state(null);
  let family = $state(null);
  let host = $state(null);
  let description = $state('');
  let error = $state('');

  let name = $derived(() => {
    if (!genus || !host || !description) return '';
    const hostAbbrev = `${host.name[0].toLowerCase()}-${host.name.split(' ')[1]}`;
    return `${genus.name} ${hostAbbrev}-${description}`;
  });

  let canSubmit = $derived(!!genus && !!family && !!host && !!name);

  async function handleDone() {
    // Check for duplicate name
    const existing = await api.galls.search(name);
    if (existing.some(g => g.name === name)) {
      error = `Name "${name}" already exists. Choose a different description or cancel.`;
      return;
    }
    onComplete({ genus, family, host, name });
    open = false;
  }
</script>
```

### Rename Species Workflow

The Gall and Host pages have a rename flow that handles more than just changing the name - it can also reassign the species to a different genus.

**Trigger:** User clicks "Rename" button next to the name field.

**Modal contents:**
```
┌─────────────────────────────────────────────────────────────┐
│  Edit Gall Name                                        [?]  │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Andricus quercuscalifornicus                          │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ☐ Add Alias for old name?                                  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ If you want to reassign the species to a different  │    │
│  │ genus simply enter the new name with the new genus. │    │
│  │ If the genus does not exist it will be created.     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│                              [Cancel] [Save Changes]        │
└─────────────────────────────────────────────────────────────┘
```

**[?] Help popover** explains valid species name formats:
- Standard: `Genus epithet` (e.g., "Andricus quercuscalifornicus")
- Hybrid: `Genus x epithet` (e.g., "Quercus x leana")
- With variant: `Genus epithet (variant)` (e.g., "Neuroterus quercusbatatus (agamic)")
- With host form: `Genus epithet (variant) (host)` (e.g., "Neuroterus sp (agamic) (q-bicolor)")
- Undescribed: `Unknown host-epithet-description` (e.g., "Unknown p-integrifolium-erineum-blisters")

**Validation on Save:**
1. Name must not be empty
2. Name must match valid species name pattern
3. Check if name already exists → error toast if duplicate

**Genus change detection:**
If the genus part of the name changes (e.g., "Andricus foo" → "Callirhytis foo"):
1. Check if new genus exists in database
2. If **not exists**: Show confirmation dialog
   - "Renaming the genus to {newGenus} will create a new genus under the current family {familyName}. Do you want to continue?"
   - On confirm: Create new genus under current family
3. If **exists**: Species reassigned to existing genus (no confirmation needed)

**Limitation**: New genera are created under the current family. To move a species to a genus in a different family, first create the genus via the Taxonomy page (Super Admin), then rename. Add help text to modal explaining this.

**Add Alias option:**
If "Add Alias for old name?" is checked:
- Old name added to aliases array with:
  - `type: "scientific name"`
  - `description: "Previous name"`
- Preserves searchability by old name

**Data returned:**
```typescript
interface RenameEvent {
  old: string;      // Original name
  new: string;      // New name
  addAlias: boolean; // Whether to add old name as alias
}
```

**Svelte 5 implementation sketch:**

```svelte
<!-- RenameModal.svelte -->
<script lang="ts">
  import { api } from '$lib/api';

  let {
    open = $bindable(false),
    currentName,
    entityType,  // 'Gall' | 'Host'
    onRename
  } = $props();

  let newName = $state(currentName);
  let addAlias = $state(false);
  let error = $state('');

  const isValidSpeciesName = (name: string) => {
    // Genus epithet, with optional (variant) and (host)
    return /^[A-Z][a-z-]+ (x )?[a-z-]+( \([^)]+\))*$/.test(name);
  };

  async function handleSave() {
    error = '';

    if (!newName.trim()) {
      error = 'Name must not be empty';
      return;
    }

    if (!isValidSpeciesName(newName)) {
      error = 'Name must be a valid species name format';
      return;
    }

    // Check for duplicate
    const exists = await api.checkNameExists(newName);
    if (exists) {
      error = 'That name is already in use';
      return;
    }

    onRename({ old: currentName, new: newName, addAlias });
    open = false;
  }
</script>
```

### Form State Pattern

Keep form state local to each page. No global form stores. (Svelte 5):

```svelte
<script lang="ts">
  // Local state using $state rune
  let formData = $state({
    name: '',
    genus: null,
    family: null,
    hosts: [],
    // ...
  });

  // Reset when selection changes
  $effect(() => {
    if (selected) {
      formData = { ...selected };
    }
  });
</script>
```

### Toast Store

Uses the shared toast store from `add-svelte-common`. See that spec for implementation.

```typescript
// Usage in admin pages
import { toast } from '$lib/components';

toast.success('Gall saved successfully');
toast.error('Failed to save: ' + error.message);
```

---

## API Integration

### Generated Client

Use OpenAPI-generated TypeScript client from `add-go-api`:

```typescript
// lib/api/index.ts
import { Configuration, GallsApi, HostsApi, ... } from './generated';

const config = new Configuration({
  basePath: import.meta.env.VITE_API_URL || '/api',
  // Auth header injection handled by middleware
});

export const api = {
  galls: new GallsApi(config),
  hosts: new HostsApi(config),
  taxonomy: new TaxonomyApi(config),
  // ...
};
```

### Error Handling

```typescript
async function save() {
  isLoading = true;
  errors = {};

  try {
    if (selected.id) {
      await api.galls.updateGall(selected.id, formData);
    } else {
      const created = await api.galls.createGall(formData);
      selected = created;
    }
    toast.success('Saved successfully');
  } catch (e) {
    if (e instanceof ApiError && e.status === 422) {
      // Validation errors - display inline
      errors = e.body.errors;
    } else {
      toast.error('Failed to save: ' + e.message);
    }
  } finally {
    isLoading = false;
  }
}
```

---

## Page Inventory with Complexity

| Page | v1 LOC | Complexity | Notes |
|------|--------|------------|-------|
| gall.tsx | 654 | High | Most fields, typeaheads, validation |
| host.tsx | 450 | High | Similar to gall |
| taxonomy.tsx | 380 | Medium | Tree structure, self-referential |
| source.tsx | 320 | Medium | Multiple source types |
| images.tsx | 400 | High | Upload, preview, assignment |
| glossary.tsx | 180 | Low | Simple CRUD |
| place.tsx | 150 | Low | Simple CRUD |
| section.tsx | 140 | Low | Simple CRUD |
| filterterms.tsx | 250 | Medium | Multiple field types |
| gallhost.tsx | 200 | Medium | Relationship mapping |
| speciessource.tsx | 280 | Medium | Relationship mapping + description |
| [id]/index.tsx | 300 | Medium | Direct species edit |
| browse/*.tsx | 150 each | Low | Read-only tables |
| index.tsx | 100 | Low | Dashboard links |

**Total v1**: ~4000 LOC (admin pages only, excluding hooks/utils)

**Target v2**: <2000 LOC (50% reduction goal)

---

## Implementation Order

Based on user preference for Gall + Host first:

### Phase 1: Foundation (can start before API)
1. Component library scaffolding
2. Tailwind config with brand colors
3. Admin layout + nav
4. Auth store skeleton

### Phase 2: Core Pages (needs API)
1. **Gall page** - validates all complex patterns
2. **Host page** - similar complexity, shares patterns
3. **Browse pages** - validates Table component

### Phase 3: Supporting Pages
1. Source, Glossary, Section, Place - simpler CRUD
2. Taxonomy - tree structure
3. FilterTerms - multi-field types

### Phase 4: Relationship Pages
1. Gallhost - mapping relationships
2. Speciessource - mapping + description
3. Species direct edit ([id])

### Phase 5: Images (needs add-image-processing)
1. Images page - upload, preview, assignment

---

## Testing Strategy

Goal: Establish strong testing foundation that v1 lacks.

### Testing Stack

| Tool | Purpose |
|------|---------|
| **Vitest** | Unit tests for stores, utils, pure functions |
| **@testing-library/svelte** | Component tests in isolation |
| **Playwright** | E2E tests for critical user flows |

### Unit Tests (Vitest)

Test all non-UI code:

```typescript
// lib/stores/auth.test.ts
import { describe, it, expect, vi } from 'vitest';
import { user, isAdmin, isSuperAdmin } from './auth';
import { get } from 'svelte/store';

describe('auth store', () => {
  it('isAdmin returns false when user is null', () => {
    user.set(null);
    expect(get(isAdmin)).toBe(false);
  });

  it('isSuperAdmin returns true when user has super_admin role', () => {
    user.set({ id: '1', name: 'test', email: 'test@test.com', roles: ['admin', 'super_admin'] });
    expect(get(isSuperAdmin)).toBe(true);
  });
});
```

**Coverage targets:**
- Stores: 100% (auth, toast)
- Utility functions: 100%
- API client wrappers: 80%+

### Component Tests (@testing-library/svelte)

Test components in isolation with mocked dependencies:

```typescript
// lib/components/forms/Input.test.ts
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import Input from './Input.svelte';

describe('Input', () => {
  it('renders label and input', () => {
    render(Input, { props: { label: 'Name', value: '' } });
    expect(screen.getByLabelText('Name')).toBeInTheDocument();
  });

  it('displays error message when error prop set', () => {
    render(Input, { props: { label: 'Name', value: '', error: 'Required' } });
    expect(screen.getByText('Required')).toBeInTheDocument();
  });

  it('shows required indicator', () => {
    render(Input, { props: { label: 'Name', value: '', required: true } });
    expect(screen.getByText('*')).toBeInTheDocument();
  });
});
```

**Coverage targets:**
- Form components: 90%+ (Input, Select, Checkbox, Typeahead, etc.)
- Layout components: 80%+ (Modal, Card, Button, etc.)
- Data components: 80%+ (Table, EditableTable, etc.)

### E2E Tests (Playwright)

Test critical user flows against running app:

```typescript
// e2e/admin-gall.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Gall Admin', () => {
  test.beforeEach(async ({ page }) => {
    // Login helper
    await loginAsAdmin(page);
  });

  test('can create a new gall', async ({ page }) => {
    await page.goto('/admin/gall');
    await page.getByPlaceholder('Search galls').fill('Test Gall');
    await page.getByText('Add a new Gall: Test Gall').click();

    // Fill required fields
    await page.getByLabel('Family').fill('Cynipidae');
    await page.getByLabel('Hosts').fill('Quercus');

    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByText('Saved successfully')).toBeVisible();
  });

  test('delete shows confirmation modal', async ({ page }) => {
    await page.goto('/admin/gall?id=1');
    await page.getByRole('button', { name: 'Delete' }).click();

    await expect(page.getByRole('dialog')).toBeVisible();
    await expect(page.getByText('PERMANENTLY deleted')).toBeVisible();
    // Cancel is focused by default
    await expect(page.getByRole('button', { name: 'Cancel' })).toBeFocused();
  });

  test('non-super-admin cannot access taxonomy', async ({ page }) => {
    await page.goto('/admin/taxonomy');
    await expect(page.getByText('requires Super Admin')).toBeVisible();
  });
});
```

**E2E coverage:**
- Login/logout flow
- CRUD operations for Gall and Host (core pages)
- Super Admin access control
- Delete confirmation behavior
- Form validation errors
- Error states (invalid ID, API error)

### Test Organization

```
v2/web/
├── src/
│   └── lib/
│       ├── stores/
│       │   ├── auth.ts
│       │   └── auth.test.ts        # Co-located unit tests
│       └── components/
│           └── forms/
│               ├── Input.svelte
│               └── Input.test.ts   # Co-located component tests
├── e2e/
│   ├── admin-auth.spec.ts          # Login/logout/access control
│   ├── admin-gall.spec.ts          # Gall CRUD
│   ├── admin-host.spec.ts          # Host CRUD
│   └── helpers/
│       └── auth.ts                 # Login helpers
├── vitest.config.ts
└── playwright.config.ts
```

### CI Integration

Tests run on every PR:
1. `vitest run` - Unit + component tests
2. `playwright test` - E2E tests (requires API running)

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Typeahead complexity | Start with svelte-select, customize if needed |
| svelte-select Svelte 5 compatibility | Verify compatibility early; fallback to svelte-multiselect or custom |
| Auth integration unclear | Match v1 NextAuth pattern with session endpoint |
| Image upload blocked | Images page deferred until add-image-processing |
| LOC reduction not achieved | Focus on composition, avoid over-abstraction |
| Test infrastructure time | Start with component tests during Phase 1; add E2E when API ready |

---

## Decision Analysis

### Decision 1: Typeahead Component

#### Current Pain Points (react-bootstrap-typeahead)

The v1 admin uses `react-bootstrap-typeahead` with these documented issues:

1. **Controller wrapper boilerplate** - Every typeahead needs `<Controller control={form.control} render={() => ...}>`
2. **Dual state management** - Must sync both react-hook-form state AND local component state in `onChange`
3. **Broken isDirty detection** - Comment in useAdmin.tsx:287: "removing the isDirty check for now since it is not working as expected"
4. **Quirky API** - New items have `customOption` property, async requires `filterBy={() => true}` workaround
5. **Type gymnastics** - `Option as TypeaheadOption` imports, casting in handlers

Example of current complexity (gall.tsx):
```tsx
<Controller
    control={adminForm.form.control}
    name="hosts"
    render={() => (
        <AsyncTypeahead
            id="hosts"
            options={hosts}
            labelKey="name"
            multiple
            onChange={(h) => {
                if (selected) {
                    selected.hosts = h as HostSimple[];
                    adminForm.setSelected({ ...selected });  // Manual sync!
                }
            }}
            selected={selected ? selected.hosts : []}
            isLoading={isLoading}
            onSearch={handleSearch}
            filterBy={() => true}  // Workaround!
        />
    )}
/>
```

#### Svelte Options Comparison

| Criteria | svelte-select | svelte-multiselect | Custom |
|----------|---------------|-------------------|--------|
| **Bundle size** | 25KB min | 12KB min | ~5KB |
| **Async search** | Yes (built-in) | Yes | Must build |
| **Multi-select** | Yes | Yes (primary focus) | Must build |
| **Create new items** | Yes (`creatable`) | Yes | Must build |
| **Keyboard nav** | Full | Full | Must build |
| **Accessibility** | Good | Good | Manual |
| **Tailwind styling** | CSS vars, customizable | Class props | Full control |
| **Maintenance** | Active, 2.6K stars | Active, 800 stars | Us |
| **TypeScript** | Full | Full | Full |

#### Option A: svelte-select

**Pros:**
- Most feature-complete option
- Built-in async with debounce
- `creatable` mode for "add new" functionality
- Good docs and examples
- Slots for custom rendering

**Cons:**
- Largest bundle (25KB)
- CSS customization via CSS variables (not classes)
- May need wrapper to match our design system

**Usage example:**
```svelte
<script>
  import Select from 'svelte-select';
  let hosts = [];

  async function searchHosts(filterText) {
    const res = await fetch(`/api/hosts?q=${filterText}`);
    return res.json();
  }
</script>

<Select
  bind:value={hosts}
  loadOptions={searchHosts}
  multiple
  creatable
  placeholder="Search hosts..."
/>
```

#### Option B: svelte-multiselect

**Pros:**
- Smaller bundle (12KB)
- Class-based styling (better Tailwind integration)
- Simpler API focused on multi-select use case
- `allowUserOptions` for creating new items

**Cons:**
- Async search less polished (manual implementation)
- Fewer customization options
- Smaller community

**Usage example:**
```svelte
<script>
  import MultiSelect from 'svelte-multiselect';
  let hosts = [];
  let options = [];

  async function handleInput(e) {
    const res = await fetch(`/api/hosts?q=${e.target.value}`);
    options = await res.json();
  }
</script>

<MultiSelect
  bind:selected={hosts}
  {options}
  on:input={handleInput}
  allowUserOptions
  placeholder="Search hosts..."
/>
```

#### Option C: Custom Implementation

**Pros:**
- Exact behavior we need, nothing extra
- Smallest bundle
- Full control over UX
- No external dependency updates to track

**Cons:**
- Significant dev time (estimate: 2-3 days for full-featured)
- Must handle edge cases: keyboard nav, screen readers, focus management
- Must build async debouncing, loading states, error handling
- Ongoing maintenance burden

#### Decision

**Use svelte-select** with a thin wrapper component:

```svelte
<!-- lib/components/forms/Typeahead.svelte -->
<script lang="ts">
  import Select from 'svelte-select';

  export let value: any;
  export let label: string;
  export let searchFn: (query: string) => Promise<any[]>;
  export let labelKey = 'name';
  export let multiple = false;
  export let creatable = false;
  export let required = false;
  export let error: string | undefined = undefined;
</script>

<label class="block text-sm font-medium text-gray-700">
  {label}{#if required}<span class="text-red-500">*</span>{/if}
</label>
<Select
  bind:value
  loadOptions={searchFn}
  {multiple}
  {creatable}
  getOptionLabel={(opt) => opt[labelKey]}
  --border-radius="0.375rem"
  --border-focused="2px solid var(--gf-maroon)"
/>
{#if error}
  <p class="mt-1 text-sm text-red-500">{error}</p>
{/if}
```

**Rationale:**
1. Wrapper isolates library choice - can swap later if needed
2. Consistent styling enforced via wrapper props
3. Avoids premature optimization of building custom component
4. Most feature-complete option for async search + create new

**Svelte 5 compatibility:** Validate svelte-select works with Svelte 5 runes early in Phase 1. If issues arise, consult owner for decision on fallback approach.

**Fallback plan:** If svelte-select causes issues:
1. Evaluate svelte-multiselect as simpler alternative
2. If both libraries problematic, build custom using wrapper interface as spec

---

### Decision 2: Auth State Delivery

#### Context

The Go API (from `add-go-api`) will handle authentication via Auth0. The frontend needs to know:
1. Is the user authenticated?
2. What is their role (Admin vs Super Admin)?
3. User display info (name, email)

v1 uses NextAuth with Auth0, which follows a session-based pattern. We should match this security model.

#### v1 Pattern (NextAuth)

1. **Session token** stored in httpOnly cookie (XSS-safe)
2. **`useSession()` hook** calls `/api/auth/session` under the hood
3. **Server validates** cookie and returns user data
4. **API routes** use `getServerSession()` to check auth server-side

The client never decodes a JWT directly - it asks the server "who am I?"

#### Decision

**httpOnly Session Cookie + Session Endpoint** (matches v1 security):

```
┌─────────────────────────────────────────────────────────┐
│  Login Flow                                             │
│  1. User clicks login → redirects to Auth0              │
│  2. Auth0 callback → Go API validates + creates session │
│  3. Go API sets httpOnly cookie                         │
│  4. Go API returns user JSON in response body           │
│  5. Frontend stores user in Svelte store                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Page Load / Refresh                                    │
│  1. Frontend calls GET /api/auth/session                │
│  2. Go API validates httpOnly cookie                    │
│  3. Returns user JSON (or 401 if invalid/expired)       │
│  4. Frontend populates Svelte store                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  API Calls                                              │
│  1. Browser automatically sends httpOnly cookie         │
│  2. Go API validates cookie on each request             │
│  3. Returns 401 if invalid                              │
└─────────────────────────────────────────────────────────┘
```

**Frontend implementation:**

```typescript
// lib/stores/auth.ts
import { writable, derived } from 'svelte/store';

interface User {
  id: string;
  name: string;
  email: string;
  roles: string[];
}

export const user = writable<User | null>(null);
export const authLoading = writable(true);

export const isAdmin = derived(user, ($user) =>
  $user?.roles.includes('admin') ?? false
);

export const isSuperAdmin = derived(user, ($user) =>
  $user?.roles.includes('super_admin') ?? false
);

// Call on app init (root layout)
export async function initAuth(): Promise<void> {
  try {
    const res = await fetch('/api/auth/session', { credentials: 'include' });
    if (res.ok) {
      user.set(await res.json());
    } else {
      user.set(null);
    }
  } catch {
    user.set(null);
  } finally {
    authLoading.set(false);
  }
}

export function login(): void {
  window.location.href = '/api/auth/login';
}

export async function logout(): Promise<void> {
  await fetch('/api/auth/logout', { method: 'POST', credentials: 'include' });
  user.set(null);
  window.location.href = '/';
}
```

**Auth guard in layout (Svelte 5):**

```svelte
<!-- routes/admin/+layout.svelte -->
<script lang="ts">
  import { user, authLoading, initAuth } from '$lib/stores/auth';
  import { page } from '$app/stores';

  let { children } = $props();

  // Initialize auth on mount
  $effect(() => {
    initAuth();
  });
</script>

{#if $authLoading}
  <p>Loading...</p>
{:else if !$user}
  <p>Please <a href="/login?redirect={encodeURIComponent($page.url.pathname)}">log in</a> to access admin.</p>
{:else}
  {@render children()}
{/if}
```

**Role format** (returned by `/api/auth/session`):
```json
{
  "id": "auth0|123",
  "name": "jeff",
  "email": "jeff@example.com",
  "roles": ["admin", "super_admin"]
}
```
- Super Admin has both roles
- Regular Admin has only `["admin"]`

**Coordination with add-go-api:**

The Go API must implement:
- `GET /api/auth/login` - Redirects to Auth0
- `GET /api/auth/callback` - Auth0 callback, sets httpOnly cookie, redirects to app
- `GET /api/auth/session` - Returns current user or 401
- `POST /api/auth/logout` - Clears cookie
- Middleware that validates cookie on all `/api/*` routes (except auth routes)

---

### Open Decisions (Deferred)

#### Form Validation Library

**Options**:
1. Manual validation in submit handler
2. `zod` + custom validation hook
3. `sveltekit-superforms` library

**Recommendation**: Start with manual validation (Svelte makes this simple). Add library if patterns become complex.

**Validation timing**: Validate on blur (when user leaves a field). This provides feedback without being too noisy during typing.

**Defer library decision until**: Gall page implementation reveals complexity level.
