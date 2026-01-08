# Tasks: Add Common Svelte Components

## Phase 1: Project Setup

### 1.1 Configure component directory structure
- [ ] Create `v2/web/src/lib/components/` directory structure
- [ ] Create subdirectories: `forms/`, `layout/`, `data/`, `feedback/`
- [ ] Add barrel export file `index.ts`
- **Verify**: Directory structure matches design.md

### 1.2 Configure Tailwind with brand colors
- [ ] Add `gf-maroon` color palette to `tailwind.config.js`
- [ ] Add CSS custom property `--gf-maroon` for svelte-select
- **Verify**: `yarn build` succeeds, colors available in Tailwind classes

### 1.3 Install dependencies
- [ ] Add `svelte-select` for Typeahead component
- [ ] Add `d3-geo` and `topojson-client` for RangeMap
- [ ] Copy `usa-can-topo.json` to `$lib/data/`
- **Verify**: Imports resolve, no build errors

### 1.4 Configure testing infrastructure
- [ ] Verify Vitest config includes `src/lib/components/**/*.test.ts`
- [ ] Add `@testing-library/svelte` if not present
- [ ] Add test script to package.json if needed
- **Verify**: `yarn test` runs (even with no tests yet)

---

## Phase 2: Form Components

### 2.1 Input component
- [ ] Implement `Input.svelte` with props: value, label, type, required, disabled, error
- [ ] Add two-way binding via `$bindable`
- [ ] Style with Tailwind, error state styling
- [ ] Write `Input.test.ts` with tests for: label rendering, error display, required indicator, value binding
- **Verify**: Tests pass, component renders correctly

### 2.2 Textarea component
- [ ] Implement `Textarea.svelte` with props: value, label, rows, required, disabled, error
- [ ] Multi-line text input with configurable rows
- [ ] Write `Textarea.test.ts`
- **Verify**: Tests pass, textarea renders correctly

### 2.3 Select component
- [ ] Implement `Select.svelte` with props: value, label, options, optionLabel, optionValue, required, disabled, error
- [ ] Support object options with configurable label/value keys
- [ ] Write `Select.test.ts`
- **Verify**: Tests pass, options render correctly

### 2.4 Checkbox component
- [ ] Implement `Checkbox.svelte` with props: checked, label, disabled
- [ ] Write `Checkbox.test.ts`
- **Verify**: Tests pass, checked state toggles

### 2.5 MultiSelect component
- [ ] Implement `MultiSelect.svelte` with props: selected, options, labelKey, valueKey, label, required, error
- [ ] Pill/chip toggle UI for selection
- [ ] Write `MultiSelect.test.ts`
- **Verify**: Tests pass, multiple selections work

### 2.6 Button component
- [ ] Implement `Button.svelte` with props: variant, type, disabled, autofocus, onclick, children
- [ ] Four variants: primary, secondary, danger, ghost
- [ ] Focus ring styling
- [ ] Autofocus prop focuses button on mount via $effect
- [ ] Write `Button.test.ts`
- **Verify**: Tests pass, all variants render correctly, autofocus works

### 2.7 Typeahead component
- [ ] Implement `Typeahead.svelte` wrapping svelte-select
- [ ] Props: selected, label, searchFn, labelKey, multiple, creatable, required, error
- [ ] Configure svelte-select styling via CSS variables
- [ ] Write `Typeahead.test.ts` (mock searchFn)
- **Verify**: Tests pass, async search works

---

## Phase 3: Layout Components

### 3.1 Modal component
- [ ] Implement `Modal.svelte` using native `<dialog>` element
- [ ] Props: open, title, children
- [ ] Escape key closes modal
- [ ] Click outside closes modal
- [ ] Write `Modal.test.ts`
- **Verify**: Tests pass, modal opens/closes correctly

### 3.2 ConfirmModal component
- [ ] Implement `ConfirmModal.svelte` extending Modal
- [ ] Props: open, title, message, confirmLabel, cancelLabel, variant, onConfirm, onCancel
- [ ] Cancel button focused by default
- [ ] Danger variant styling for confirm button
- [ ] Write `ConfirmModal.test.ts`
- **Verify**: Tests pass, Cancel is focused on open

### 3.3 Card component
- [ ] Implement `Card.svelte` with props: title, children
- [ ] Optional title rendering
- [ ] Write `Card.test.ts`
- **Verify**: Tests pass

### 3.4 Alert component
- [ ] Implement `Alert.svelte` with props: variant, children
- [ ] Four variants: info, warning, error, success
- [ ] Write `Alert.test.ts`
- **Verify**: Tests pass, all variants render correctly

### 3.5 Spinner component
- [ ] Implement `Spinner.svelte` with props: size
- [ ] Three sizes: sm, md, lg
- [ ] Animate with Tailwind `animate-spin`
- [ ] (No test needed - purely visual)
- **Verify**: Renders at all sizes

---

## Phase 4: Data Components

### 4.1 Table component
- [ ] Implement `Table.svelte` with props: data, columns, sortBy, sortDir, onsort, page, pageSize, totalCount, onpagechange
- [ ] Column config: key, label, sortable, render
- [ ] Sort indicator arrows
- [ ] Hover state on rows
- [ ] Pagination UI: Previous/Next buttons, "Showing X to Y of Z" text
- [ ] Hide pagination when totalCount <= pageSize
- [ ] Disable Previous on first page, Next on last page
- [ ] Write `Table.test.ts` (sorting and pagination)
- **Verify**: Tests pass, sorting and pagination work

### 4.2 RangeMap component
- [ ] Implement `RangeMap.svelte` with props: inRange, excludedRange, editable, onToggle
- [ ] Use d3-geo `geoAlbers()` projection configured for North America (USA + Canada)
- [ ] Fine-tune projection parameters (center, rotate, parallels, scale, translate) for proper display
- [ ] Load TopoJSON features (US states + Canadian provinces)
- [ ] Three-state fill logic (in-range, excluded, neither)
- [ ] Click handler for editable mode
- [ ] Write `RangeMap.test.ts` (test fill logic)
- **Verify**: Tests pass, map renders US states and Canadian provinces correctly

---

## Phase 5: Feedback Components

### 5.1 Toast store
- [ ] Implement `toast.ts` Svelte store
- [ ] Functions: toast.success(), toast.error(), toast.info(), toast.dismiss()
- [ ] Auto-dismiss after 5 seconds
- [ ] Write `toast.test.ts`
- **Verify**: Tests pass

### 5.2 ToastContainer component
- [ ] Implement `ToastContainer.svelte`
- [ ] Fixed position bottom-right
- [ ] Render toasts from store
- [ ] Variant styling (success=green, error=red, info=blue)
- [ ] Close button on each toast for manual dismiss
- [ ] Write `ToastContainer.test.ts`
- **Verify**: Tests pass, toasts appear, auto-dismiss, and can be manually dismissed

---

## Phase 6: Integration & Documentation

### 6.1 Update barrel export
- [ ] Ensure all components exported from `index.ts`
- [ ] Verify imports work: `import { Button, Input, Modal } from '$lib/components'`
- **Verify**: No import errors

### 6.2 Final validation
- [ ] Run full test suite: `yarn test`
- [ ] Run type check: `yarn check-types`
- [ ] Run build: `yarn build`
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
