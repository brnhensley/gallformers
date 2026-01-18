# Component Audit: Form Components Consolidation

**Date:** 2026-01-18
**Branch:** form-component-audit
**Bead:** gallformers-46n0

## Files Audited

1. `lib/gallformers_web/components/core_components.ex`
2. `lib/gallformers_web/components/form_components.ex`
3. `lib/gallformers_web/live/admin/form_components.ex`
4. `assets/css/app.css`

---

## Component Inventory

### core_components.ex (13 components/helpers)

| Component | Purpose | Label Font | Hidden Input | CSS Classes |
|-----------|---------|------------|--------------|-------------|
| `flash/1` | Flash notices | N/A | N/A | `gf-toast`, `gf-alert-*` ✅ |
| `button/1` | Nav-aware button | N/A | N/A | `gf-btn`, `gf-btn-primary`, `gf-btn-soft` ✅ |
| `input/1` | Multi-type form input | `text-base font-medium text-gray-700` | ✅ checkbox | `gf-input`, `gf-select`, `gf-textarea`, `gf-checkbox` ✅ |
| `error/1` (private) | Error display | N/A | N/A | Inline Tailwind |
| `header/1` | Page header | N/A | N/A | Inline Tailwind |
| `table/1` | Data tables | N/A | N/A | `gf-table`, `gf-table-compact`, `gf-table-zebra` ✅ |
| `list/1` | Data list | N/A | N/A | `gf-list`, `gf-list-row` ✅ |
| `icon/1` | Icons | N/A | N/A | `gf-*`, `ph-*` prefixes |
| `typeahead/1` | Single-select search | `text-base font-medium text-gray-700` | N/A | Inline Tailwind ❌ |
| `multi_select_typeahead/1` | Multi-select tags | `text-base font-medium text-gray-700` | N/A | Inline Tailwind ❌ |
| `data_complete_badge/1` | Status badge | N/A | N/A | Inline Tailwind ❌ |
| `show/2`, `hide/2` | JS animations | N/A | N/A | - |
| `translate_error/1,2` | Error translation | N/A | N/A | - |

### form_components.ex (10 components)

| Component | Purpose | Label Font | Hidden Input | CSS Classes |
|-----------|---------|------------|--------------|-------------|
| `btn/1` | Multi-variant button | N/A | N/A | Inline Tailwind ❌ |
| `multi_select/1` | Pill toggles | `text-base font-medium text-gray-700` | N/A | Inline Tailwind ❌ |
| `search_input/1` | Search with icon | N/A | N/A | Inline Tailwind ❌ |
| `field_wrapper/1` | Field container | `text-base font-medium text-gray-700` | N/A | Inline Tailwind ❌ |
| `toggle/1` | Toggle switch | `text-base font-medium text-gray-700` | ✅ | Inline Tailwind ❌ |
| `radio_group/1` | Radio buttons | `text-base font-medium text-gray-700` | N/A | Inline Tailwind ❌ |
| `file_dropzone/1` | File upload | N/A | N/A | Inline Tailwind ❌ |
| `submit_button/1` | Submit with loading | N/A | N/A | Inline Tailwind ❌ |
| `multi_select_dropdown/1` | Chips + dropdown | **`text-sm`** ⚠️ | N/A | Inline Tailwind ❌ |
| `rename_modal/1` | Rename species | N/A | ❌ checkbox | Inline Tailwind ❌ |

### admin/form_components.ex (3 components)

| Component | Purpose | Label Font | Hidden Input | CSS Classes |
|-----------|---------|------------|--------------|-------------|
| `form_actions/1` | Cancel/Save buttons | N/A | N/A | Inline Tailwind ❌ |
| `alias_editor/1` | Alias table | **`text-sm`** ⚠️ | N/A | Inline Tailwind ❌ |
| `rename_modal/1` | **DUPLICATE** | N/A | ❌ checkbox | Inline Tailwind ❌ |

---

## Issues Found

### Duplicates

**`rename_modal/1`** - Nearly identical implementation in two files:
- `form_components.ex:718-797`
- `admin/form_components.ex:204-283`

Only difference: `entity_type` default is `"Species"` in admin vs required in form_components.

### Inconsistencies

#### 1. Button Components Overlap

| Component | File | Variants | Sizes | CSS |
|-----------|------|----------|-------|-----|
| `button/1` | core_components | primary, soft | - | Semantic (`gf-btn-*`) |
| `btn/1` | form_components | primary, secondary, danger, warning, ghost | sm, md, lg | Inline Tailwind |
| `submit_button/1` | form_components | primary, danger | - | Inline Tailwind |
| `form_actions/1` | admin/form_components | - | - | Inline Tailwind |

#### 2. Label Font Sizes Inconsistent

| Pattern | Components |
|---------|------------|
| `text-base font-medium text-gray-700` | `input`, `typeahead`, `multi_select_typeahead`, `multi_select`, `field_wrapper`, `toggle`, `radio_group` |
| `text-sm font-medium text-gray-700` | `multi_select_dropdown`, `alias_editor` |
| `text-sm text-gray-700` | `radio_group` option labels (no font-medium) |

#### 3. Checkbox Hidden Input Handling

- `input/1` checkbox: ✅ Has hidden input with `value="false"`
- `toggle/1`: ✅ Has hidden input
- `rename_modal/1` checkbox: ❌ No hidden input (will not submit false value)

---

## Existing Semantic CSS Classes (app.css)

### Well-defined (used by components)

**Form Inputs:**
- `.gf-input`, `.gf-input-error`
- `.gf-select`, `.gf-select-error`
- `.gf-textarea`, `.gf-textarea-error`
- `.gf-checkbox`

**Buttons:**
- `.gf-btn` (base)
- `.gf-btn-primary` (maroon)
- `.gf-btn-soft` (ghost)
- `.gf-btn-secondary` (white with border)

**Tables:**
- `.gf-table`, `.gf-table-dark`, `.gf-table-compact`, `.gf-table-zebra`

**Alerts/Toast:**
- `.gf-toast`, `.gf-alert`, `.gf-alert-info`, `.gf-alert-error`, `.gf-alert-icon`

**Lists:**
- `.gf-list`, `.gf-list-row`, `.gf-list-col-grow`

**Typography:**
- `.text-body`, `.text-body-sm`
- `.text-label`
- `.text-page-title`, `.text-section-title`, `.text-card-title`

### Missing (should be added)

- `.gf-label` / `.gf-label-sm` - Form labels
- `.gf-modal` / `.gf-modal-backdrop` / `.gf-modal-header` / `.gf-modal-body` / `.gf-modal-footer`
- `.gf-card` / `.gf-card-header`
- `.gf-badge` / `.gf-badge-success` / `.gf-badge-warning` / `.gf-badge-info`
- `.gf-chip` / `.gf-chip-remove`

---

## Gaps - Missing Components

1. **`modal/1`** - Generic modal wrapper (rename_modal is too specialized)
2. **`card/1`** - Card container with optional header
3. **`badge/1`** - Generic badge with variants
4. **`chip/1`** - Removable tag/chip for multi-selects
5. **`pagination/1`** - Page navigation
6. **`tabs/1`** - Tab navigation

---

## Proposed Canonical Structure

### core_components.ex (Phoenix defaults + base UI)

Keep:
- `flash/1` ✅
- `button/1` ← consolidate all button variants here
- `input/1` ✅
- `header/1` ✅
- `table/1` ✅
- `list/1` ✅
- `icon/1` ✅
- JS helpers ✅
- Error translation ✅

Add:
- `modal/1` - Generic modal
- `card/1` - Card container
- `badge/1` - Status badges
- `chip/1` - Removable chips

### form_components.ex (form-specific)

Move here from core:
- `typeahead/1`
- `multi_select_typeahead/1`

Keep:
- `multi_select/1` (pill toggles)
- `multi_select_dropdown/1`
- `search_input/1`
- `field_wrapper/1`
- `toggle/1`
- `radio_group/1`
- `file_dropzone/1`

Remove:
- `btn/1` ← consolidate into core button
- `submit_button/1` ← consolidate into core button
- `rename_modal/1` ← use generic modal + specific content

### admin/form_components.ex (admin-only)

Keep:
- `form_actions/1`
- `alias_editor/1`

Remove:
- `rename_modal/1` ← DELETE duplicate

---

## Recommended CSS Classes to Add

```css
/* Labels - centralize label styling */
.gf-label {
  display: block;
  font-size: 1rem;      /* text-base */
  font-weight: 500;     /* font-medium */
  color: #374151;       /* text-gray-700 */
  margin-bottom: 0.25rem;
}

.gf-label-sm {
  font-size: 0.875rem;  /* text-sm */
  font-weight: 500;
  color: #374151;
  margin-bottom: 0.25rem;
}

/* Modal */
.gf-modal-backdrop {
  position: fixed;
  inset: 0;
  background-color: rgba(0, 0, 0, 0.5);
  z-index: 40;
}

.gf-modal {
  position: relative;
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  width: 100%;
  max-width: 42rem;
}

.gf-modal-header {
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.gf-modal-body {
  padding: 1.5rem;
}

.gf-modal-footer {
  padding: 1rem 1.5rem;
  border-top: 1px solid #e5e7eb;
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
}

/* Chips */
.gf-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.5rem;
  background-color: #dbeafe;  /* blue-100 */
  color: #1e40af;             /* blue-800 */
  border-radius: 0.25rem;
  font-size: 0.875rem;
}

.gf-chip-sm {
  padding: 0.125rem 0.375rem;
  font-size: 0.75rem;
}

.gf-chip-remove {
  color: #2563eb;
  cursor: pointer;
}

.gf-chip-remove:hover {
  color: #1e40af;
}

/* Badges */
.gf-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  font-weight: 500;
  border-radius: 9999px;
}

.gf-badge-success {
  background-color: #dcfce7;
  color: #166534;
}

.gf-badge-warning {
  background-color: #fef9c3;
  color: #854d0e;
}

.gf-badge-info {
  background-color: #dbeafe;
  color: #1e40af;
}
```

---

## Priority Actions

1. **High: Remove duplicate `rename_modal`** - Delete from `admin/form_components.ex`, keep in `form_components.ex`
2. **High: Fix checkbox hidden input** - Add hidden input to `rename_modal` checkbox
3. **Medium: Standardize label fonts** - Create `.gf-label` class and use consistently
4. **Medium: Consolidate button components** - Merge `btn`, `submit_button` into `button`
5. **Low: Add missing semantic CSS** - Modal, chip, badge classes
6. **Low: Create generic `modal/1`** - Extract pattern from `rename_modal`
