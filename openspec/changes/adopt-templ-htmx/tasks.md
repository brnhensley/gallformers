# Tasks: Adopt Go + Templ + HTMX Architecture

## Decisions
- **Framework**: Go + Templ + HTMX (replacing SvelteKit)
- **Client-side state**: Alpine.js for admin features
- **Complex interactivity**: JS islands (range map, image upload)
- **Caching**: In-memory page cache with invalidation
- **Markdown**: goldmark with glossary extension

## 0. Preparation

- [ ] 0.1 Create `pre-templ` git tag before starting any work (rollback safety)
- [ ] 0.2 Document current SvelteKit routes and their data dependencies

## 1. Foundation Setup

### 1.1 Templ Configuration
- [ ] 1.1.1 Add Templ dependency to `go.mod`
- [ ] 1.1.2 Configure `templ generate` in Makefile
- [ ] 1.1.3 Add `.templ` file handling to `.gitignore` (generated `_templ.go` files)
- [ ] 1.1.4 Set up IDE/editor Templ support instructions in CLAUDE.md
- [ ] 1.1.5 Add `air` for Go live reload, configure `.air.toml`
- [ ] 1.1.6 Create `make dev` target running `air` and `templ generate --watch` in parallel

### 1.2 Directory Structure
- [ ] 1.2.1 Create `v2/templates/` directory structure (layouts, components, pages, partials, admin)
- [ ] 1.2.2 Create `v2/static/` directory structure (css, js, islands)
- [ ] 1.2.3 Create `v2/islands/` for island source code
- [ ] 1.2.4 Create `v2/internal/handlers/pages/` for page handlers
- [ ] 1.2.5 Create `v2/internal/handlers/partials/` for HTMX handlers
- [ ] 1.2.6 Create `v2/internal/cache/` for page cache

### 1.3 Static Assets
- [ ] 1.3.1 Add HTMX library to `v2/static/js/htmx.min.js`
- [ ] 1.3.2 Add Alpine.js to `v2/static/js/alpine.min.js`
- [ ] 1.3.3 Copy `v2/web/src/app.css` to `v2/static/css/app.css`
- [ ] 1.3.4 Add `make build-css` target using Tailwind CLI
- [ ] 1.3.5 Copy League Spartan font files to `v2/static/branding/`
- [ ] 1.3.6 Configure static file serving in Go server with 1-year cache headers
- [ ] 1.3.7 Implement build hash generation for cache busting (git commit or timestamp)
- [ ] 1.3.8 Add BuildHash variable to templates for static asset URLs

### 1.4 Base Templates
- [ ] 1.4.1 Create `templates/layouts/base.templ` - HTML skeleton with HTMX/Alpine
- [ ] 1.4.2 Create `templates/layouts/public.templ` - Public site layout
- [ ] 1.4.3 Create `templates/layouts/admin.templ` - Admin layout
- [ ] 1.4.4 Create `templates/components/header.templ`
- [ ] 1.4.5 Create `templates/components/footer.templ`
- [ ] 1.4.6 Create `templates/components/nav.templ`

## 2. Page Cache

- [ ] 2.1 Add `github.com/hashicorp/golang-lru/v2` dependency
- [ ] 2.2 Implement `internal/cache/cache.go` wrapping LRU with TTL expiry
- [ ] 2.3 Add singleflight for stampede protection
- [ ] 2.4 Add cache stats endpoint for monitoring (`/debug/cache`)

## 3. Markdown & Glossary

- [ ] 3.1 Add goldmark dependency
- [ ] 3.2 Implement `internal/markdown/markdown.go` with GFM extensions
- [ ] 3.3 Implement `internal/markdown/glossary.go` for term auto-linking
- [ ] 3.4 Create glossary linker that builds regex from DB terms
- [ ] 3.5 Add glossary refresh mechanism (rebuild linker on glossary edit)

## 4. Routing Setup

- [ ] 4.1 Create `internal/server/routes.go` with route definitions
- [ ] 4.2 Add page routes (/, /gall/{id}, /host/{id}, etc.)
- [ ] 4.3 Add partial routes (/partials/gall/{id}, /partials/search, etc.)
- [ ] 4.4 Add admin routes with auth middleware
- [ ] 4.5 Configure 404 handler
- [ ] 4.6 Add middleware for Cache-Control headers (pages: no-cache, partials: no-store)

## 5. Shared Components

### 5.1 UI Components
- [ ] 5.1.1 Create `templates/components/loading.templ` - Loading spinner
- [ ] 5.1.2 Create `templates/components/error.templ` - Error message
- [ ] 5.1.3 Create `templates/components/pagination.templ` - Page navigation
- [ ] 5.1.4 Create `templates/components/card.templ` - Content card
- [ ] 5.1.5 Create `templates/components/alert.templ` - Alert messages

### 5.2 Form Components
- [ ] 5.2.1 Create `templates/components/input.templ` - Text input
- [ ] 5.2.2 Create `templates/components/textarea.templ` - Multi-line input
- [ ] 5.2.3 Create `templates/components/select.templ` - Dropdown
- [ ] 5.2.4 Create `templates/components/checkbox.templ` - Boolean toggle
- [ ] 5.2.5 Create `templates/components/button.templ` - Button variants

### 5.3 Data Components
- [ ] 5.3.1 Create `templates/components/image_gallery.templ` - Image display with lazy loading
- [ ] 5.3.2 Create `templates/components/species_card.templ` - Species summary
- [ ] 5.3.3 Create `templates/components/host_list.templ` - Host list
- [ ] 5.3.4 Create `templates/components/source_citation.templ` - Reference citation

## 6. Public Pages

### 6.1 Entity Pages
- [ ] 6.1.1 Create `templates/pages/gall.templ` and handler
- [ ] 6.1.2 Create `templates/pages/host.templ` and handler
- [ ] 6.1.3 Create `templates/pages/family.templ` and handler
- [ ] 6.1.4 Create `templates/pages/genus.templ` and handler
- [ ] 6.1.5 Create `templates/pages/source.templ` and handler
- [ ] 6.1.6 Create `templates/pages/section.templ` and handler
- [ ] 6.1.7 Create `templates/pages/place.templ` and handler

### 6.2 HTMX Partials for Entity Pages
- [ ] 6.2.1 Create `templates/partials/gall_details.templ` and handler
- [ ] 6.2.2 Create `templates/partials/host_details.templ` and handler
- [ ] 6.2.3 Create `templates/partials/taxonomy_info.templ` and handler

### 6.3 Static/Content Pages
- [ ] 6.3.1 Create `templates/pages/home.templ` and handler
- [ ] 6.3.2 Create `templates/pages/about.templ` and handler
- [ ] 6.3.3 Create `templates/pages/filterguide.templ` and handler
- [ ] 6.3.4 Create `templates/pages/resources.templ` and handler
- [ ] 6.3.5 Create `templates/pages/glossary.templ` and handler
- [ ] 6.3.6 Create `templates/pages/refindex.templ` and handler
- [ ] 6.3.7 Create `templates/pages/404.templ` (not found page)
- [ ] 6.3.8 Create `templates/pages/500.templ` (server error page)
- [ ] 6.3.9 Add recovery middleware to catch panics and render 500 page

## 7. Search (HTMX)

- [ ] 7.1 Create `templates/pages/search.templ` with HTMX search input
- [ ] 7.2 Create `templates/partials/search_results.templ` for results fragment
- [ ] 7.3 Create search partial handler with debounced query support
- [ ] 7.4 Add keyboard navigation for search results

## 8. ID Tool (HTMX)

- [ ] 8.1 Create `templates/pages/id.templ` with filter form
- [ ] 8.2 Create `templates/partials/id_results.templ` for results grid
- [ ] 8.3 Create `templates/partials/id_filters.templ` for filter sections
- [ ] 8.4 Implement filter change triggers (hx-trigger="change")
- [ ] 8.5 Add URL query parameter sync with hx-push-url for shareable filter state
- [ ] 8.6 Handle htmx:historyRestore for back/forward navigation
- [ ] 8.7 Port genus picker as Alpine.js component
- [ ] 8.8 Port host picker as Alpine.js component

## 9. Explore Page (HTMX)

- [ ] 9.1 Create `templates/pages/explore.templ`
- [ ] 9.2 Create `templates/partials/explore_results.templ`
- [ ] 9.3 Implement browse-by-family, browse-by-host features

## 10. Range Map Island

- [ ] 10.1 Set up Vite config for islands with manifest generation
- [ ] 10.2 Add `make build-islands` target and integrate into `make build`
- [ ] 10.3 Create Go helper to read island manifest and resolve script URLs
- [ ] 10.4 Create `islands/range-map/` Svelte component
- [ ] 10.5 Configure Vite build for range-map island
- [ ] 10.6 Create `templates/components/range_map.templ` mount point
- [ ] 10.7 Embed GeoJSON data from server
- [ ] 10.8 Test view-only and editable modes

## 11. Admin Pages

### 11.1 Admin Foundation
- [ ] 11.1.1 Create admin authentication middleware
- [ ] 11.1.2 Create CSRF middleware and token generation
- [ ] 11.1.3 Add CSRF meta tag to admin layout with htmx:configRequest handler
- [ ] 11.1.4 Create `templates/admin/dashboard.templ`
- [ ] 11.1.5 Create admin navigation component

### 11.2 Species Admin
- [ ] 11.2.1 Create `templates/admin/species_list.templ` with pagination
- [ ] 11.2.2 Create `templates/admin/species_form.templ` with HTMX validation
- [ ] 11.2.3 Implement save handler with cache invalidation
- [ ] 11.2.4 Create alias editor (Alpine.js tag input)
- [ ] 11.2.5 Create host association editor

### 11.3 Host Admin
- [ ] 11.3.1 Create `templates/admin/host_list.templ`
- [ ] 11.3.2 Create `templates/admin/host_form.templ`
- [ ] 11.3.3 Implement save handler with cache invalidation

### 11.4 Taxonomy Admin
- [ ] 11.4.1 Create `templates/admin/taxonomy_list.templ`
- [ ] 11.4.2 Create `templates/admin/taxonomy_form.templ`
- [ ] 11.4.3 Implement save handler with cache invalidation

### 11.5 Other Admin Pages
- [ ] 11.5.1 Create source admin pages
- [ ] 11.5.2 Create glossary admin pages
- [ ] 11.5.3 Create place admin pages

### 11.6 Image Management Island
- [ ] 11.6.1 Create `islands/image-upload/` for drag-drop upload
- [ ] 11.6.2 Create image reordering functionality
- [ ] 11.6.3 Integrate with S3 upload flow

## 12. Cache Invalidation

- [ ] 12.1 Add cache invalidation to species save handler
- [ ] 12.2 Add cache invalidation to host save handler
- [ ] 12.3 Add cache invalidation to taxonomy save handler
- [ ] 12.4 Add cascade invalidation for related pages (e.g., host pages when gall changes)
- [ ] 12.5 Add glossary change → full cache clear

## 13. Testing

### 13.1 Unit Tests
- [ ] 13.1.1 Test page cache (Get/Set/Delete/Expiry)
- [ ] 13.1.2 Test markdown rendering
- [ ] 13.1.3 Test glossary linking
- [ ] 13.1.4 Test route parameter extraction

### 13.2 Integration Tests
- [ ] 13.2.1 Test full page render flow
- [ ] 13.2.2 Test HTMX partial responses
- [ ] 13.2.3 Test cache invalidation on edit
- [ ] 13.2.4 Test auth middleware

### 13.3 Accessibility Testing
- [ ] 13.3.1 Add axe-core or pa11y for automated a11y checks
- [ ] 13.3.2 Add a11y tests for key pages (home, gall, host, ID tool, admin form)
- [ ] 13.3.3 Integrate a11y checks into CI pipeline

### 13.4 Manual Testing
- [ ] 13.4.1 Test all public pages load correctly
- [ ] 13.4.2 Test search functionality
- [ ] 13.4.3 Test ID tool filters
- [ ] 13.4.4 Test admin edit → public page freshness
- [ ] 13.4.5 Test range map on species pages

## 14. Visual Parity Verification

- [ ] 14.1 Compare home page side-by-side with SvelteKit version
- [ ] 14.2 Compare gall/species pages side-by-side
- [ ] 14.3 Compare host pages side-by-side
- [ ] 14.4 Compare family/genus pages side-by-side
- [ ] 14.5 Compare search results side-by-side
- [ ] 14.6 Compare ID tool side-by-side
- [ ] 14.7 Compare admin pages side-by-side
- [ ] 14.8 Test responsive layout at mobile/tablet/desktop breakpoints
- [ ] 14.9 Sign-off: all pages achieve visual parity

## 15. Cleanup & Migration (only after 14.9 complete)

- [ ] 15.1 Remove `v2/web/` directory (SvelteKit)
- [ ] 15.2 Update Dockerfile (remove Node.js build stage)
- [ ] 15.3 Update Makefile (remove npm/pnpm commands)
- [ ] 15.4 Update `v2/CLAUDE.md` with new architecture docs
- [ ] 15.5 Archive or close `convert-v2-to-spa` proposal

## 16. SEO

- [ ] 16.1 Create `templates/components/meta_tags.templ` for title, description, canonical
- [ ] 16.2 Create `templates/components/og_tags.templ` for Open Graph tags
- [ ] 16.3 Add JSON-LD structured data to species pages
- [ ] 16.4 Create `/sitemap.xml` handler with all public pages
- [ ] 16.5 Create `/robots.txt` handler (allow public, disallow admin/partials)
- [ ] 16.6 Register sitemap with Google Search Console

## 17. Documentation

- [ ] 17.1 Document Templ component patterns in CLAUDE.md
- [ ] 17.2 Document HTMX partial patterns
- [ ] 17.3 Document cache invalidation strategy
- [ ] 17.4 Document island build process
- [ ] 17.5 Update architecture diagrams

## 18. Deployment

- [ ] 18.1 Test Docker build
- [ ] 18.2 Deploy to Fly.io staging
- [ ] 18.3 Verify all routes work
- [ ] 18.4 Performance test (page load times)
- [ ] 18.5 Deploy to production

## Dependencies

```
Phase 1 (Foundation) - no dependencies
Phase 2 (Cache, Markdown) - depends on Phase 1
Phase 3 (Routing) - depends on Phase 1
Phase 4 (Components) - depends on Phase 1
Phase 5 (Public Pages) - depends on Phases 2, 3, 4
Phase 6 (Search, ID Tool) - depends on Phase 5
Phase 7 (Admin) - depends on Phase 5
Phase 8 (Islands) - can parallel with Phases 5-7
Phase 9 (Testing) - depends on Phases 5-7
Phase 10 (Cleanup) - depends on all above
```

## Parallelizable Work

These can be done in parallel after Phase 1 foundation:
- Page cache implementation
- Markdown/glossary processing
- Shared components
- Static CSS porting
- Island builds

These can be done in parallel after Phase 5:
- Individual public pages
- Search and ID tool
- Admin pages
