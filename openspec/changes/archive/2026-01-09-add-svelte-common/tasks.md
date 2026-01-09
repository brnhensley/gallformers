# Tasks: Add Common Svelte Components

## Phase 1: Project Setup

### 1.1 Configure component directory structure
- [x] Create `v2/web/src/lib/components/` directory structure
- [x] Create subdirectories: `forms/`, `layout/`, `data/`, `feedback/`
- [x] Add barrel export file `index.ts`
- **Verify**: Directory structure matches design.md

### 1.2 Configure Tailwind with brand colors
- [x] Add `gf-maroon` color palette to `tailwind.config.js`
- [x] Add CSS custom property `--gf-maroon` for svelte-select
- **Verify**: `yarn build` succeeds, colors available in Tailwind classes

### 1.3 Install dependencies
- [x] Add `svelte-select` for Typeahead component
- [x] Add `d3-geo` and `topojson-client` for RangeMap
- [x] Copy `usa-can-topo.json` to `$lib/data/`
- **Verify**: Imports resolve, no build errors

### 1.4 Configure testing infrastructure
- [x] Verify Vitest config includes `src/lib/components/**/*.test.ts`
- [x] Add `@testing-library/svelte` if not present
- [x] Add test script to package.json if needed
- **Verify**: `yarn test` runs (even with no tests yet)

---

## Phase 2: Form Components

### 2.1 Input component
- [x] Implement `Input.svelte` with props: value, label, type, required, disabled, error
- [x] Add two-way binding via `$bindable`
- [x] Style with Tailwind, error state styling
- [x] Write `Input.test.ts` with tests for: label rendering, error display, required indicator, value binding
- **Verify**: Tests pass, component renders correctly

### 2.2 Textarea component
- [x] Implement `Textarea.svelte` with props: value, label, rows, required, disabled, error
- [x] Multi-line text input with configurable rows
- [x] Write `Textarea.test.ts`
- **Verify**: Tests pass, textarea renders correctly

### 2.3 Select component
- [x] Implement `Select.svelte` with props: value, label, options, optionLabel, optionValue, required, disabled, error
- [x] Support object options with configurable label/value keys
- [x] Write `Select.test.ts`
- **Verify**: Tests pass, options render correctly

### 2.4 Checkbox component
- [x] Implement `Checkbox.svelte` with props: checked, label, disabled
- [x] Write `Checkbox.test.ts`
- **Verify**: Tests pass, checked state toggles

### 2.5 MultiSelect component
- [x] Implement `MultiSelect.svelte` with props: selected, options, labelKey, valueKey, label, required, error
- [x] Pill/chip toggle UI for selection
- [x] Write `MultiSelect.test.ts`
- **Verify**: Tests pass, multiple selections work

### 2.6 Button component
- [x] Implement `Button.svelte` with props: variant, type, disabled, autofocus, onclick, children
- [x] Four variants: primary, secondary, danger, ghost
- [x] Focus ring styling
- [x] Autofocus prop focuses button on mount via $effect
- [x] Write `Button.test.ts`
- **Verify**: Tests pass, all variants render correctly, autofocus works

### 2.7 Typeahead component
- [x] Implement `Typeahead.svelte` wrapping svelte-select
- [x] Props: selected, label, searchFn, labelKey, multiple, creatable, required, error
- [x] Configure svelte-select styling via CSS variables
- [x] Write `Typeahead.test.ts` (mock searchFn)
- **Verify**: Tests pass, async search works

---

## Phase 3: Layout Components

### 3.1 Modal component
- [x] Implement `Modal.svelte` using native `<dialog>` element
- [x] Props: open, title, children
- [x] Escape key closes modal
- [x] Click outside closes modal
- [x] Write `Modal.test.ts`
- **Verify**: Tests pass, modal opens/closes correctly

### 3.2 ConfirmModal component
- [x] Implement `ConfirmModal.svelte` extending Modal
- [x] Props: open, title, message, confirmLabel, cancelLabel, variant, onConfirm, onCancel
- [x] Cancel button focused by default
- [x] Danger variant styling for confirm button
- [x] Write `ConfirmModal.test.ts`
- **Verify**: Tests pass, Cancel is focused on open

### 3.3 Card component
- [x] Implement `Card.svelte` with props: title, children
- [x] Optional title rendering
- [x] Write `Card.test.ts`
- **Verify**: Tests pass

### 3.4 Alert component
- [x] Implement `Alert.svelte` with props: variant, children
- [x] Four variants: info, warning, error, success
- [x] Write `Alert.test.ts`
- **Verify**: Tests pass, all variants render correctly

### 3.5 Spinner component
- [x] Implement `Spinner.svelte` with props: size
- [x] Three sizes: sm, md, lg
- [x] Animate with Tailwind `animate-spin`
- [x] (No test needed - purely visual)
- **Verify**: Renders at all sizes

---

## Phase 4: Data Components

### 4.1 Table component
- [x] Implement `Table.svelte` with props: data, columns, sortBy, sortDir, onsort, page, pageSize, totalCount, onpagechange
- [x] Column config: key, label, sortable, render
- [x] Sort indicator arrows
- [x] Hover state on rows
- [x] Pagination UI: Previous/Next buttons, "Showing X to Y of Z" text
- [x] Hide pagination when totalCount <= pageSize
- [x] Disable Previous on first page, Next on last page
- [x] Write `Table.test.ts` (sorting and pagination)
- **Verify**: Tests pass, sorting and pagination work

### 4.2 RangeMap component
- [x] Implement `RangeMap.svelte` with props: inRange, excludedRange, editable, onToggle
- [x] Use d3-geo `geoAlbers()` projection configured for North America (USA + Canada)
- [x] Fine-tune projection parameters (center, rotate, parallels, scale, translate) for proper display
- [x] Load TopoJSON features (US states + Canadian provinces)
- [x] Three-state fill logic (in-range, excluded, neither)
- [x] Click handler for editable mode
- [x] Write `RangeMap.test.ts` (test fill logic)
- **Verify**: Tests pass, map renders US states and Canadian provinces correctly

---

## Phase 5: Feedback Components

### 5.1 Toast store
- [x] Implement `toast.ts` Svelte store
- [x] Functions: toast.success(), toast.error(), toast.info(), toast.dismiss()
- [x] Auto-dismiss after 5 seconds
- [x] Write `toast.test.ts`
- **Verify**: Tests pass

### 5.2 ToastContainer component
- [x] Implement `ToastContainer.svelte`
- [x] Fixed position bottom-right
- [x] Render toasts from store
- [x] Variant styling (success=green, error=red, info=blue)
- [x] Close button on each toast for manual dismiss
- [x] Write `ToastContainer.test.ts`
- **Verify**: Tests pass, toasts appear, auto-dismiss, and can be manually dismissed

---

## Phase 6: Integration & Documentation

### 6.1 Update barrel export
- [x] Ensure all components exported from `index.ts`
- [x] Verify imports work: `import { Button, Input, Modal } from '$lib/components'`
- **Verify**: No import errors

### 6.2 Final validation
- [x] Run full test suite: `yarn test` (114/114 tests pass)
- [x] Run type check: `yarn check` (added svelte-check; external package type issues only)
- [x] Run build: `yarn build` (succeeds)
- **Verify**: All pass with no errors

---

## Parallelization Notes

- **Phase 2 tasks (2.1-2.6)** can run in parallel
- **Phase 3 tasks (3.1-3.5)** can run in parallel
- **Phase 4 tasks (4.1-4.2)** can run in parallel
- **Phase 5 tasks (5.1-5.2)** should run sequentially (5.2 depends on 5.1)
- **Phase 6** depends on all previous phases

## Dependencies

- `define-v2-foundation` must be applied first (creates v2/ structure)
- No external API dependencies (components are UI-only)
