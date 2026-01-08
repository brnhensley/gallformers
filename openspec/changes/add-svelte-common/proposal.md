# Change: Add Common Svelte Components

## Why

The `add-svelte-admin` and `add-svelte-public` proposals both define overlapping UI components. Without a shared component library:

- **Duplicate implementations** - Same components written twice with diverging behavior
- **Inconsistent UX** - Button variants, form styles, and interactions differ between admin and public
- **Maintenance burden** - Bug fixes and improvements must be applied in multiple places

Extracting common components into a shared library ensures consistency and reduces total code.

## What Changes

### Shared Component Library

Create a component library in `v2/web/src/lib/components/` with three categories:

**Form Components:**
| Component | Purpose |
|-----------|---------|
| `Input` | Text/number/email input with label, error, required indicator |
| `Textarea` | Multi-line text input with label, rows, error |
| `Select` | Single-select dropdown |
| `Checkbox` | Boolean toggle with label |
| `MultiSelect` | Multi-select for filter fields |
| `Typeahead` | Async search typeahead (wraps svelte-select) |
| `Button` | Action button with variants: primary, secondary, danger, ghost |

**Layout Components:**
| Component | Purpose |
|-----------|---------|
| `Modal` | Base modal with title and content slot |
| `ConfirmModal` | Destructive action confirmation (danger variant, Cancel focused) |
| `Card` | Section container with optional title |
| `Toast` / `ToastContainer` | Notification system (success, error, info) |
| `Alert` | Inline alert/warning display |
| `Spinner` | Loading indicator |

**Data Components:**
| Component | Purpose |
|-----------|---------|
| `Table` | Sortable, paginated data table |
| `RangeMap` | SVG geographic range map (d3-geo + TopoJSON) |

### What Stays Separate

These components have different requirements between admin and public:

| Component | Admin | Public |
|-----------|-------|--------|
| `Breadcrumb` | Generic path-based | `TaxonomyBreadcrumb` - species hierarchy |
| `ImageGallery` | TBD (deferred to add-image-processing) | Carousel + lightbox |
| `SourceList` | Editable | View-only with selection |

## Impact

- **Depends on**: `define-v2-foundation` (v2 directory structure exists)
- **Blocks**: `add-svelte-admin`, `add-svelte-public` (both depend on these components)
- **Related**: All Svelte UI work

### Dependency Reordering

This proposal should be applied **before** both `add-svelte-admin` and `add-svelte-public`. Those proposals will be updated to reference the common components rather than defining their own.

## Success Criteria

1. All listed components implemented with TypeScript and Svelte 5 runes
2. Components use Tailwind CSS with Gallformers brand colors
3. Basic accessibility: semantic HTML, keyboard navigation, focus management
4. Each component has co-located unit test
5. Admin and public specs reference common components (no duplication)

## Dependencies

- `define-v2-foundation` must be applied (v2/ structure exists)

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Typeahead library | `svelte-select` with wrapper | Feature-complete, wrapper isolates library choice |
| Mapping library | d3-geo + TopoJSON | Lightweight, existing TopoJSON file, Svelte handles reactivity |
| Styling | Tailwind utilities via props | Consistent with v2 stack, composable |
| State pattern | Svelte 5 runes (`$state`, `$derived`, `$bindable`, `$props`) | Modern Svelte, better DX |

See `design.md` for component implementation details.
