# Change: Add Svelte Admin Interface

## Why

The current React/Next.js admin interface (16 pages, 5000+ LOC) suffers from complexity that makes maintenance and feature development painful:

- **654-line gall.tsx** with fp-ts Option gymnastics and react-hook-form boilerplate
- **Duplicate patterns** across pages with inconsistent implementations
- **No component library** - each page re-implements forms, tables, modals
- **Tight coupling** to Next.js SSR patterns for what should be a simple CRUD interface

The v2 rewrite moves to Svelte with two-way binding, which should reduce form code by 50%+ while providing a better DX. This is Phase 2 of the `rewrite-gallformers-v2` umbrella.

## What Changes

### New Svelte Admin Application

Build a complete admin interface in `v2/web/` that replicates all current admin functionality:

| Current Route | New Route | Auth Level |
|---------------|-----------|------------|
| `/admin` | `/admin` | Admin |
| `/admin/gall` | `/admin/gall` | Admin |
| `/admin/host` | `/admin/host` | Admin |
| `/admin/taxonomy` | `/admin/taxonomy` | Super Admin |
| `/admin/source` | `/admin/source` | Admin |
| `/admin/glossary` | `/admin/glossary` | Admin |
| `/admin/images` | `/admin/images` | Admin |
| `/admin/place` | `/admin/place` | Super Admin |
| `/admin/section` | `/admin/section` | Admin |
| `/admin/filterterms` | `/admin/filterterms` | Super Admin |
| `/admin/gallhost` | `/admin/gallhost` | Admin |
| `/admin/speciessource` | `/admin/speciessource` | Admin |
| `/admin/[id]` | `/admin/species/[id]` | Super Admin |
| `/admin/browse/*` | `/admin/browse/*` | Admin |

### Component Library

Uses the shared component library from `add-svelte-common`:

- **Form components**: Input, Select, Typeahead, Checkbox, MultiSelect, Button
- **Layout components**: Modal, ConfirmModal, Card, Alert, Spinner
- **Data components**: Table (sortable, paginated), RangeMap
- **Feedback components**: Toast notifications

Admin-specific components (Breadcrumb, EditableRangeMap, AdminNav) are defined in this spec.

### Implementation Approach

1. **Parallel scaffolding**: Start component library while `add-go-api` is in progress
2. **Core pages first**: Gall and Host pages (most complex) validate all patterns
3. **Incremental delivery**: Each page is independently testable and deployable

## Impact

- **Depends on**: `define-v2-foundation` (v2 directory structure exists)
- **Depends on**: `add-svelte-common` (shared UI component library)
- **Depends on**: `add-go-api` (API endpoints for data operations)
- **Blocks**: `cutover-v2`
- **Related**: `add-image-processing` (Images page uses image upload API)

### Parallelization with add-go-api

| Can start immediately | Blocked by API endpoints |
|-----------------------|--------------------------|
| Component library | CRUD operations on all pages |
| Page layouts/structure | Data fetching |
| Form validation patterns | Auth integration |
| Routing setup | |

## Success Criteria

1. All 16 admin routes functional with feature parity
2. Component library documented with usage examples
3. Form code reduced by 50%+ compared to v1 (LOC metric)
4. All Core Behavioral Expectations from umbrella spec preserved:
   - Delete confirmations (danger variant, Cancel focused)
   - Two-tier auth (Admin / Super Admin)
   - Form validation with inline errors
5. TypeScript types shared between frontend and API (OpenAPI generated)

## Dependencies

- `define-v2-foundation` must be applied (v2/ structure exists)
- `add-svelte-common` provides shared UI components
- `add-go-api` provides endpoints (partial dependency - see parallelization above)
- `add-image-processing` provides upload API for Images page

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Typeahead | `svelte-select` with wrapper | Feature-complete, isolate via wrapper for future swap |
| Auth state | httpOnly cookie + `/api/auth/session` | Matches v1 NextAuth security model |
| Form validation | Manual (deferred) | Svelte's two-way binding makes this simple |

See `design.md` for full analysis of each decision.
