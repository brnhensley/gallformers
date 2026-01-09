# Design: Common Svelte Components

## Context

The v2 Svelte applications (admin and public) share many UI components. This document defines the shared component library that both applications will use.

## Framework Versions

- **Svelte 5** - Uses runes (`$state`, `$derived`, `$effect`, `$props`, `$bindable`)
- **SvelteKit 2** - Latest routing and build system
- **Tailwind CSS** - Utility-first styling

All code examples use Svelte 5 runes syntax.

---

## Directory Structure

```
v2/web/src/lib/components/
├── forms/
│   ├── Input.svelte
│   ├── Input.test.ts
│   ├── Textarea.svelte
│   ├── Textarea.test.ts
│   ├── Select.svelte
│   ├── Select.test.ts
│   ├── Checkbox.svelte
│   ├── Checkbox.test.ts
│   ├── MultiSelect.svelte
│   ├── MultiSelect.test.ts
│   ├── Typeahead.svelte
│   ├── Typeahead.test.ts
│   ├── Button.svelte
│   └── Button.test.ts
├── layout/
│   ├── Modal.svelte
│   ├── Modal.test.ts
│   ├── ConfirmModal.svelte
│   ├── ConfirmModal.test.ts
│   ├── Card.svelte
│   ├── Card.test.ts
│   ├── Alert.svelte
│   ├── Alert.test.ts
│   └── Spinner.svelte
├── data/
│   ├── Table.svelte
│   ├── Table.test.ts
│   ├── RangeMap.svelte
│   └── RangeMap.test.ts
├── feedback/
│   ├── Toast.svelte
│   ├── ToastContainer.svelte
│   └── toast.ts          # Toast store
└── index.ts              # Barrel export
```

---

## Design Principles

1. **Composition over configuration** - Simple props, compose for complex cases
2. **Svelte-native** - Use two-way binding (`bind:value`), not React patterns
3. **Tailwind utilities** - Style via props that map to Tailwind classes
4. **Basic accessibility** - Semantic HTML, keyboard nav, focus management

---

## Accessibility Requirements

Target: Basic accessibility through good practices, not formal WCAG compliance.

**Required for all components:**
- Semantic HTML elements (`<button>`, `<label>`, `<nav>`, `<main>`, etc.)
- All form inputs have associated `<label>` elements (use wrapping label pattern)
- Keyboard navigation works (Tab, Enter, Escape)
- Focus visible on interactive elements (`:focus-visible` styles)
- Modal focus management via native `<dialog>` element (browser-native focus trapping)

**Implementation checklist:**
```svelte
<!-- DO: Semantic HTML with labels -->
<label for="name">Species Name</label>
<input id="name" type="text" bind:value={name} />

<!-- DO: Button for actions, not div -->
<button type="button" onclick={save}>Save</button>

<!-- DO: Escape closes modals -->
<svelte:window onkeydown={(e) => e.key === 'Escape' && (open = false)} />

<!-- DO: Autofocus Cancel on destructive modals -->
<button bind:this={cancelBtn} use:focusOnMount>Cancel</button>
```

---

## Form Components

### Input

```svelte
<!-- Usage -->
<Input
  bind:value={name}
  label="Species Name"
  required
  error={errors.name}
/>

<!-- Implementation sketch (Svelte 5) -->
<script lang="ts">
  let {
    value = $bindable(''),
    label,
    type = 'text',
    required = false,
    disabled = false,
    error = undefined
  }: {
    value?: string;
    label: string;
    type?: 'text' | 'number' | 'email';
    required?: boolean;
    disabled?: boolean;
    error?: string;
  } = $props();
</script>

<label class="block">
  <span class="block text-sm font-medium text-gray-700">
    {label}{#if required}<span class="text-red-500">*</span>{/if}
  </span>
  <input
    {type}
    bind:value
    {required}
    {disabled}
    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm
           focus:border-gf-maroon focus:ring-gf-maroon
           {error ? 'border-red-500' : ''}"
  />
  {#if error}
    <p class="mt-1 text-sm text-red-500">{error}</p>
  {/if}
</label>
```

### Select (Single)

```svelte
<!-- Usage -->
<Select
  bind:value={detachable}
  label="Detachable"
  options={detachableOptions}
  optionLabel="value"
  optionValue="id"
/>

<!-- Implementation sketch -->
<script lang="ts">
  let {
    value = $bindable(null),
    label,
    options,
    optionLabel = 'label',
    optionValue = 'value',
    required = false,
    disabled = false,
    error = undefined
  }: {
    value?: any;
    label: string;
    options: any[];
    optionLabel?: string;
    optionValue?: string;
    required?: boolean;
    disabled?: boolean;
    error?: string;
  } = $props();
</script>

<label class="block">
  <span class="block text-sm font-medium text-gray-700">
    {label}{#if required}<span class="text-red-500">*</span>{/if}
  </span>
  <select
    bind:value
    {required}
    {disabled}
    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm
           focus:border-gf-maroon focus:ring-gf-maroon
           {error ? 'border-red-500' : ''}"
  >
    <option value={null}>Select...</option>
    {#each options as opt}
      <option value={opt[optionValue]}>{opt[optionLabel]}</option>
    {/each}
  </select>
  {#if error}
    <p class="mt-1 text-sm text-red-500">{error}</p>
  {/if}
</label>
```

### Checkbox

```svelte
<!-- Usage -->
<Checkbox bind:checked={undescribed} label="Undescribed species?" />

<!-- Implementation sketch -->
<script lang="ts">
  let {
    checked = $bindable(false),
    label,
    disabled = false
  }: {
    checked?: boolean;
    label: string;
    disabled?: boolean;
  } = $props();
</script>

<label class="flex items-center space-x-2">
  <input
    type="checkbox"
    bind:checked
    {disabled}
    class="rounded border-gray-300 text-gf-maroon
           focus:ring-gf-maroon"
  />
  <span class="text-sm text-gray-700">{label}</span>
</label>
```

### Textarea

```svelte
<!-- Usage -->
<Textarea
  bind:value={description}
  label="Description"
  rows={4}
  required
  error={errors.description}
/>

<!-- Implementation sketch -->
<script lang="ts">
  let {
    value = $bindable(''),
    label,
    rows = 3,
    required = false,
    disabled = false,
    error = undefined
  }: {
    value?: string;
    label: string;
    rows?: number;
    required?: boolean;
    disabled?: boolean;
    error?: string;
  } = $props();
</script>

<label class="block">
  <span class="block text-sm font-medium text-gray-700">
    {label}{#if required}<span class="text-red-500">*</span>{/if}
  </span>
  <textarea
    bind:value
    {rows}
    {required}
    {disabled}
    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm
           focus:border-gf-maroon focus:ring-gf-maroon
           {error ? 'border-red-500' : ''}"
  />
  {#if error}
    <p class="mt-1 text-sm text-red-500">{error}</p>
  {/if}
</label>
```

### MultiSelect (Filter Fields)

For properties like colors, shapes, seasons that come from FilterField table:

```svelte
<!-- Usage -->
<MultiSelect
  bind:selected={colors}
  options={allColors}
  labelKey="field"
  label="Colors"
/>

<!-- Implementation sketch -->
<script lang="ts">
  let {
    selected = $bindable([]),
    options,
    labelKey = 'label',
    valueKey = 'id',
    label,
    required = false,
    error = undefined
  }: {
    selected?: any[];
    options: any[];
    labelKey?: string;
    valueKey?: string;
    label: string;
    required?: boolean;
    error?: string;
  } = $props();

  function toggle(opt: any) {
    const idx = selected.findIndex(s => s[valueKey] === opt[valueKey]);
    if (idx >= 0) {
      selected = selected.filter((_, i) => i !== idx);
    } else {
      selected = [...selected, opt];
    }
  }

  function isSelected(opt: any) {
    return selected.some(s => s[valueKey] === opt[valueKey]);
  }
</script>

<fieldset>
  <legend class="block text-sm font-medium text-gray-700">
    {label}{#if required}<span class="text-red-500">*</span>{/if}
  </legend>
  <div class="mt-2 flex flex-wrap gap-2">
    {#each options as opt}
      <button
        type="button"
        onclick={() => toggle(opt)}
        class="px-3 py-1 rounded-full text-sm border
               {isSelected(opt)
                 ? 'bg-gf-maroon text-white border-gf-maroon'
                 : 'bg-white text-gray-700 border-gray-300 hover:border-gf-maroon'}"
      >
        {opt[labelKey]}
      </button>
    {/each}
  </div>
</fieldset>
{#if error}
  <p class="mt-1 text-sm text-red-500">{error}</p>
{/if}
```

### Typeahead (Async Search)

Most complex form component. Used for:
- Species selection (main entity picker)
- Host selection (multi-select)
- Taxonomy selection (genus, family)

```svelte
<!-- Usage -->
<Typeahead
  bind:selected={hosts}
  label="Hosts"
  searchFn={searchHosts}
  labelKey="name"
  multiple
  required
  error={errors.hosts}
/>
```

**Decision: Use `svelte-select` library with wrapper**

| Option | Pros | Cons |
|--------|------|------|
| svelte-select | Feature-complete, maintained | Bundle size, styling may need overrides |
| Custom | Exact control, smaller | Dev time, edge cases |

**Rationale**: Start with `svelte-select`, wrapper isolates library choice for future swap.

```svelte
<!-- lib/components/forms/Typeahead.svelte -->
<script lang="ts">
  import Select from 'svelte-select';

  let {
    selected = $bindable(null),
    label,
    searchFn,
    labelKey = 'name',
    multiple = false,
    creatable = false,
    required = false,
    error = undefined
  }: {
    selected?: any;
    label: string;
    searchFn: (query: string) => Promise<any[]>;
    labelKey?: string;
    multiple?: boolean;
    creatable?: boolean;
    required?: boolean;
    error?: string;
  } = $props();
</script>

<!-- Note: Can't use wrapping label with svelte-select, so use aria-labelledby -->
<div class="block">
  <span id="typeahead-label" class="block text-sm font-medium text-gray-700">
    {label}{#if required}<span class="text-red-500">*</span>{/if}
  </span>
  <Select
    bind:value={selected}
    loadOptions={searchFn}
    {multiple}
    {creatable}
    getOptionLabel={(opt) => opt[labelKey]}
    aria-labelledby="typeahead-label"
    --border-radius="0.375rem"
    --border-focused="2px solid var(--gf-maroon)"
  />
  {#if error}
    <p class="mt-1 text-sm text-red-500">{error}</p>
  {/if}
</div>
```

**Note**: Since svelte-select is a custom component, we can't wrap it in a `<label>`. Use `aria-labelledby` instead. The actual ID should be generated uniquely per instance during implementation.

### Button

```svelte
<!-- Usage -->
<Button variant="primary">Save</Button>
<Button variant="secondary">Cancel</Button>
<Button variant="danger">Delete</Button>
<Button variant="ghost">Add Another</Button>
<Button autofocus>Focused on mount</Button>

<!-- Implementation sketch -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    variant = 'primary',
    type = 'button',
    disabled = false,
    autofocus = false,
    onclick,
    children
  }: {
    variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
    type?: 'button' | 'submit' | 'reset';
    disabled?: boolean;
    autofocus?: boolean;
    onclick?: () => void;
    children: Snippet;
  } = $props();

  let buttonEl: HTMLButtonElement;

  // Focus on mount when autofocus is true
  $effect(() => {
    if (autofocus && buttonEl) {
      setTimeout(() => buttonEl.focus(), 0);
    }
  });

  const variantClasses = {
    primary: 'bg-gf-maroon text-white hover:bg-gf-maroon-dark',
    secondary: 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50',
    danger: 'bg-red-600 text-white hover:bg-red-700',
    ghost: 'text-gf-maroon hover:bg-gf-maroon/10'
  };
</script>

<button
  bind:this={buttonEl}
  {type}
  {disabled}
  {onclick}
  class="px-4 py-2 rounded-md font-medium transition-colors
         focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon
         disabled:opacity-50 disabled:cursor-not-allowed
         {variantClasses[variant]}"
>
  {@render children()}
</button>
```

---

## Layout Components

### Modal

Base modal component with accessibility features:

```svelte
<!-- Usage -->
<Modal title="Help" bind:open={showHelp}>
  <p>Content here...</p>
</Modal>

<!-- With actions slot -->
<Modal title="Rename Species" bind:open={showRename}>
  <form onsubmit={handleRename}>
    <Input bind:value={newName} label="New Name" />
    <div class="mt-4 flex justify-end space-x-3">
      <Button variant="secondary" onclick={() => showRename = false}>Cancel</Button>
      <Button type="submit">Rename</Button>
    </div>
  </form>
</Modal>
```

```svelte
<!-- Implementation sketch -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    open = $bindable(false),
    title,
    children
  }: {
    open?: boolean;
    title: string;
    children: Snippet;
  } = $props();

  let dialogEl: HTMLDialogElement;

  $effect(() => {
    if (open) {
      dialogEl?.showModal();
    } else {
      dialogEl?.close();
    }
  });

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      open = false;
    }
  }
</script>

<dialog
  bind:this={dialogEl}
  onkeydown={handleKeydown}
  onclick={(e) => e.target === dialogEl && (open = false)}
  class="rounded-lg shadow-xl max-w-lg w-full p-0 backdrop:bg-black/50"
>
  <div class="p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-4">{title}</h2>
    {@render children()}
  </div>
</dialog>
```

### ConfirmModal

Specialized modal for destructive actions with specific UX requirements:

```svelte
<!-- Usage -->
<ConfirmModal
  open={showDeleteConfirm}
  title="Delete Gall"
  message="Caution. All data associated with this Gall will be PERMANENTLY deleted."
  variant="danger"
  onConfirm={handleDelete}
  onCancel={() => showDeleteConfirm = false}
/>
```

**Requirements (from umbrella spec):**
- Cancel button is focused by default
- Cancel = secondary variant, Confirm = danger variant
- Message explains cascade effects

```svelte
<!-- Implementation sketch -->
<script lang="ts">
  let {
    open = $bindable(false),
    title,
    message,
    confirmLabel = 'Confirm',
    cancelLabel = 'Cancel',
    variant = 'danger',
    onConfirm,
    onCancel
  }: {
    open?: boolean;
    title: string;
    message: string;
    confirmLabel?: string;
    cancelLabel?: string;
    variant?: 'danger' | 'warning';
    onConfirm: () => void;
    onCancel: () => void;
  } = $props();
</script>

<Modal bind:open {title}>
  <p class="text-gray-600 mb-6">{message}</p>
  <div class="flex justify-end space-x-3">
    <Button
      variant="secondary"
      autofocus
      onclick={onCancel}
    >
      {cancelLabel}
    </Button>
    <Button
      variant={variant}
      onclick={onConfirm}
    >
      {confirmLabel}
    </Button>
  </div>
</Modal>
```

### Card

```svelte
<!-- Usage -->
<Card title="Gall Properties">
  <!-- form fields -->
</Card>

<!-- Without title -->
<Card>
  <p>Content here</p>
</Card>

<!-- Implementation sketch -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    title = undefined,
    children
  }: {
    title?: string;
    children: Snippet;
  } = $props();
</script>

<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
  {#if title}
    <h3 class="text-lg font-medium text-gray-900 mb-4">{title}</h3>
  {/if}
  {@render children()}
</div>
```

### Alert

```svelte
<!-- Usage -->
<Alert variant="error">{errorMessage}</Alert>
<Alert variant="warning">This page requires Super Admin access.</Alert>
<Alert variant="info">Tip: You can search by scientific or common name.</Alert>

<!-- Implementation sketch -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    variant = 'info',
    children
  }: {
    variant?: 'info' | 'warning' | 'error' | 'success';
    children: Snippet;
  } = $props();

  const variantClasses = {
    info: 'bg-blue-50 text-blue-800 border-blue-200',
    warning: 'bg-yellow-50 text-yellow-800 border-yellow-200',
    error: 'bg-red-50 text-red-800 border-red-200',
    success: 'bg-green-50 text-green-800 border-green-200'
  };
</script>

<div class="p-4 rounded-md border {variantClasses[variant]}">
  {@render children()}
</div>
```

### Spinner

```svelte
<!-- Usage -->
<Spinner />
<Spinner size="sm" />
<Spinner size="lg" />

<!-- Implementation sketch -->
<script lang="ts">
  let {
    size = 'md'
  }: {
    size?: 'sm' | 'md' | 'lg';
  } = $props();

  const sizeClasses = {
    sm: 'h-4 w-4',
    md: 'h-8 w-8',
    lg: 'h-12 w-12'
  };
</script>

<svg
  class="animate-spin text-gf-maroon {sizeClasses[size]}"
  xmlns="http://www.w3.org/2000/svg"
  fill="none"
  viewBox="0 0 24 24"
>
  <circle
    class="opacity-25"
    cx="12"
    cy="12"
    r="10"
    stroke="currentColor"
    stroke-width="4"
  />
  <path
    class="opacity-75"
    fill="currentColor"
    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
  />
</svg>
```

---

## Data Components

### Table

Sortable, paginated table for browse pages:

```svelte
<!-- Usage -->
<Table
  data={galls}
  columns={[
    { key: 'name', label: 'Name', sortable: true },
    { key: 'hosts', label: 'Hosts', render: (row) => row.hosts.map(h => h.name).join(', ') },
    { key: 'actions', label: '', render: (row) => /* edit/delete buttons */ }
  ]}
  sortBy={sortColumn}
  sortDir={sortDirection}
  onsort={handleSort}
  page={currentPage}
  pageSize={25}
  totalCount={totalGalls}
  onpagechange={handlePageChange}
/>
```

```svelte
<!-- Implementation sketch -->
<script lang="ts">
  import type { Snippet } from 'svelte';
  import { Button } from '$lib/components';

  interface Column<T> {
    key: string;
    label: string;
    sortable?: boolean;
    render?: (row: T) => Snippet | string;
  }

  let {
    data,
    columns,
    sortBy = $bindable(null),
    sortDir = $bindable('asc'),
    onsort,
    // Pagination props
    page = 1,
    pageSize = 25,
    totalCount = 0,
    onpagechange
  }: {
    data: any[];
    columns: Column<any>[];
    sortBy?: string | null;
    sortDir?: 'asc' | 'desc';
    onsort?: (key: string) => void;
    page?: number;
    pageSize?: number;
    totalCount?: number;
    onpagechange?: (page: number) => void;
  } = $props();

  // Pagination calculations
  let totalPages = $derived(Math.ceil(totalCount / pageSize));
  let showPagination = $derived(totalCount > pageSize);
  let startItem = $derived((page - 1) * pageSize + 1);
  let endItem = $derived(Math.min(page * pageSize, totalCount));

  function handleSort(key: string) {
    if (!onsort) return;
    if (sortBy === key) {
      sortDir = sortDir === 'asc' ? 'desc' : 'asc';
    } else {
      sortBy = key;
      sortDir = 'asc';
    }
    onsort(key);
  }

  function getValue(row: any, col: Column<any>) {
    if (col.render) {
      return col.render(row);
    }
    return row[col.key];
  }

  function goToPage(newPage: number) {
    if (onpagechange && newPage >= 1 && newPage <= totalPages) {
      onpagechange(newPage);
    }
  }
</script>

<div class="overflow-x-auto">
  <table class="min-w-full divide-y divide-gray-200">
    <thead class="bg-gray-50">
      <tr>
        {#each columns as col}
          <th
            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider
                   {col.sortable ? 'cursor-pointer hover:bg-gray-100' : ''}"
            onclick={() => col.sortable && handleSort(col.key)}
          >
            {col.label}
            {#if col.sortable && sortBy === col.key}
              <span class="ml-1">{sortDir === 'asc' ? '↑' : '↓'}</span>
            {/if}
          </th>
        {/each}
      </tr>
    </thead>
    <tbody class="bg-white divide-y divide-gray-200">
      {#each data as row}
        <tr class="hover:bg-gray-50">
          {#each columns as col}
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
              {getValue(row, col)}
            </td>
          {/each}
        </tr>
      {/each}
    </tbody>
  </table>
</div>

{#if showPagination}
  <div class="flex items-center justify-between px-4 py-3 bg-white border-t border-gray-200">
    <div class="text-sm text-gray-700">
      Showing {startItem} to {endItem} of {totalCount} results
    </div>
    <div class="flex gap-2">
      <Button
        variant="secondary"
        disabled={page === 1}
        onclick={() => goToPage(page - 1)}
      >
        Previous
      </Button>
      <span class="flex items-center px-3 text-sm text-gray-700">
        Page {page} of {totalPages}
      </span>
      <Button
        variant="secondary"
        disabled={page === totalPages}
        onclick={() => goToPage(page + 1)}
      >
        Next
      </Button>
    </div>
  </div>
{/if}
```

**Note**: The Table component expects pre-paginated data. The caller is responsible for fetching the correct page of data based on `page` and `pageSize`. The `totalCount` prop is needed to calculate total pages.

### RangeMap

Geographic distribution map using d3-geo + TopoJSON:

```svelte
<!-- Usage (view-only) -->
<RangeMap inRange={speciesRange} />

<!-- Usage (editable - admin) -->
<RangeMap
  inRange={inRangeSet}
  excludedRange={excludedSet}
  editable
  onToggle={handleToggle}
/>
```

**Decision: One shared component with `editable` prop**

Both public (view-only) and admin (editable) use the same component:
- Public: Two states (in-range / not)
- Admin: Three states (in-range / excluded / neither)

```svelte
<!-- Implementation sketch -->
<script lang="ts">
  import { geoPath, geoAlbers } from 'd3-geo';
  import { feature } from 'topojson-client';
  import topology from '$lib/data/usa-can-topo.json';

  let {
    inRange,
    excludedRange = new Set(),
    editable = false,
    onToggle = () => {}
  }: {
    inRange: Set<string>;
    excludedRange?: Set<string>;
    editable?: boolean;
    onToggle?: (code: string) => void;
  } = $props();

  // Albers projection configured for North America (USA + Canada)
  const projection = geoAlbers()
    .center([0, 55])        // Center latitude for NA
    .rotate([96, 0])        // Rotate to center on NA longitude
    .parallels([20, 60])    // Standard parallels for NA
    .scale(800)
    .translate([487, 350]); // Center in viewBox

  const path = geoPath(projection);

  // Extract features from TopoJSON (includes US states + Canadian provinces)
  const features = feature(topology, topology.objects.regions).features;

  function getFill(code: string) {
    if (excludedRange.has(code)) return '#F08080';  // LightCoral - excluded
    if (inRange.has(code)) return '#228B22';         // ForestGreen - in range
    return '#FFFFFF';                                 // White - neither
  }

  function handleClick(code: string) {
    if (editable) {
      onToggle(code);
    }
  }
</script>

<svg viewBox="0 0 975 700" class="w-full h-auto">
  {#each features as feature}
    <path
      d={path(feature)}
      fill={getFill(feature.properties.postal)}
      stroke="#2F4F4F"
      stroke-width="0.5"
      onclick={() => handleClick(feature.properties.postal)}
      class={editable ? 'cursor-pointer hover:opacity-80' : ''}
    />
  {/each}
</svg>
```

**Note**: The projection parameters (scale, translate, parallels) may need fine-tuning based on the actual TopoJSON bounds. The `topology.objects.regions` key should contain both US states and Canadian provinces.

**Admin wrapper for editable behavior:**

The admin interface wraps this with `EditableRangeMap.svelte` that adds:
- Three-state toggle logic (in-range → excluded → neither → in-range)
- Legend with color coding
- Select All / Deselect All buttons

This wrapper lives in `add-svelte-admin`, not the common library.

---

## Feedback Components

### Toast Store

```typescript
// lib/components/feedback/toast.ts
import { writable } from 'svelte/store';

interface Toast {
  id: string;
  type: 'success' | 'error' | 'info';
  message: string;
}

const { subscribe, update } = writable<Toast[]>([]);

export const toasts = { subscribe };

export const toast = {
  success: (message: string) => addToast('success', message),
  error: (message: string) => addToast('error', message),
  info: (message: string) => addToast('info', message),
  dismiss: (id: string) => removeToast(id),
};

function addToast(type: Toast['type'], message: string) {
  const id = crypto.randomUUID();
  update(t => [...t, { id, type, message }]);
  setTimeout(() => removeToast(id), 5000);
}

function removeToast(id: string) {
  update(t => t.filter(toast => toast.id !== id));
}
```

### ToastContainer

```svelte
<!-- Usage: Place once in root layout -->
<ToastContainer />

<!-- Implementation sketch -->
<script lang="ts">
  import { toasts, toast } from './toast';

  const typeClasses = {
    success: 'bg-green-500',
    error: 'bg-red-500',
    info: 'bg-blue-500'
  };
</script>

<div class="fixed bottom-4 right-4 z-50 space-y-2">
  {#each $toasts as t (t.id)}
    <div
      class="flex items-center gap-2 pl-4 pr-2 py-3 rounded-md text-white shadow-lg {typeClasses[t.type]}"
      role="alert"
    >
      <span class="flex-1">{t.message}</span>
      <button
        type="button"
        onclick={() => toast.dismiss(t.id)}
        class="p-1 rounded hover:bg-white/20 focus:outline-none focus:ring-2 focus:ring-white/50"
        aria-label="Dismiss"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  {/each}
</div>
```

---

## Testing Strategy

### Unit Tests (Vitest + @testing-library/svelte)

Each component has a co-located test file:

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

  it('updates value on input', async () => {
    const user = userEvent.setup();
    const { component } = render(Input, { props: { label: 'Name', value: '' } });

    const input = screen.getByLabelText('Name');
    await user.type(input, 'Test');

    expect(component.value).toBe('Test');
  });
});
```

**Coverage targets:**
- Form components: 90%+
- Layout components: 80%+
- Data components: 80%+

---

## Tailwind Configuration

Brand colors for Gallformers:

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        'gf-maroon': {
          DEFAULT: '#800000',
          dark: '#660000',
          light: '#a64d4d'
        }
      }
    }
  }
}
```

---

## Barrel Export

```typescript
// lib/components/index.ts

// Forms
export { default as Input } from './forms/Input.svelte';
export { default as Textarea } from './forms/Textarea.svelte';
export { default as Select } from './forms/Select.svelte';
export { default as Checkbox } from './forms/Checkbox.svelte';
export { default as MultiSelect } from './forms/MultiSelect.svelte';
export { default as Typeahead } from './forms/Typeahead.svelte';
export { default as Button } from './forms/Button.svelte';

// Layout
export { default as Modal } from './layout/Modal.svelte';
export { default as ConfirmModal } from './layout/ConfirmModal.svelte';
export { default as Card } from './layout/Card.svelte';
export { default as Alert } from './layout/Alert.svelte';
export { default as Spinner } from './layout/Spinner.svelte';

// Data
export { default as Table } from './data/Table.svelte';
export { default as RangeMap } from './data/RangeMap.svelte';

// Feedback
export { default as ToastContainer } from './feedback/ToastContainer.svelte';
export { toast, toasts } from './feedback/toast';
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| svelte-select Svelte 5 compatibility | Verify compatibility early; fallback to svelte-multiselect or custom |
| d3-geo bundle size | Only import needed functions (geoPath, geoAlbers) |
| Modal focus trapping varies by browser | Relies on native `<dialog>` element behavior; acceptable for admin tool. Add focus-trap library later if user complaints arise. |
| Component props API changes | Start with minimal props, extend as needed |
