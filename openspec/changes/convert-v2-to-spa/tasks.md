# Tasks: Convert V2 to Pure SPA

## Decisions
- **CDN**: No CDN for now. Add reactively if traffic requires.
- **Scope**: Full - standardize patterns, loading states, error boundaries.

## 1. Configuration Changes

- [ ] 1.1 Update `v2/web/svelte.config.js`:
  - Set `fallback: 'index.html'` for SPA mode
  - Set `strict: false` to allow non-prerendered routes
  - Remove or simplify prerender config
- [ ] 1.2 Remove `export const prerender = true` from `v2/web/src/routes/+layout.js`
- [ ] 1.3 Remove `export const prerender = false` from individual route files (no longer needed)
- [ ] 1.4 Verify build completes without database access

## 2. Create Shared Patterns

### 2.1 Loading Components
- [ ] 2.1.1 Create `$lib/components/ui/LoadingSpinner.svelte` - generic spinner
- [ ] 2.1.2 Create `$lib/components/ui/LoadingSkeleton.svelte` - skeleton placeholder
- [ ] 2.1.3 Create `$lib/components/ui/PageLoading.svelte` - full page loading state

### 2.2 Error Components
- [ ] 2.2.1 Create `$lib/components/ui/ErrorMessage.svelte` - generic error display
- [ ] 2.2.2 Create `$lib/components/ui/ErrorBoundary.svelte` - catch and display errors
- [ ] 2.2.3 Create `$lib/components/ui/NotFound.svelte` - 404 state for bad IDs

### 2.3 Data Fetching Pattern
- [ ] 2.3.1 Create `$lib/stores/asyncData.js` - reactive store for async data (loading/error/data states)
- [ ] 2.3.2 Document the standard pattern in code comments
- [ ] 2.3.3 Create example usage in one route as reference

## 3. Route Refactoring (Full Scope)

Convert each route to use standardized pattern with loading/error states:

### Public Pages
- [ ] 3.1 `gall/[id]/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.2 `host/[id]/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.3 `family/[id]/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.4 `genus/[id]/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.5 `source/[id]/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.6 `section/[id]/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.7 `place/[id]/+page.svelte` - refactor to onMount + loading/error states

### Interactive Pages
- [ ] 3.8 `id/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.9 `globalsearch/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.10 `glossary/+page.svelte` - refactor to onMount + loading/error states
- [ ] 3.11 `explore/+page.svelte` - refactor to onMount + loading/error states

### Cleanup
- [ ] 3.12 Delete all `+page.js` files (load functions no longer needed)
- [ ] 3.13 Verify no orphaned imports or dead code

## 4. Go Server Verification

- [ ] 4.1 Verify `spaFileServer` in `v2/api/cmd/server/main.go` correctly falls back to index.html
- [ ] 4.2 Test deep links work (e.g., direct navigation to `/gall/123`)
- [ ] 4.3 Test 404 handling for truly non-existent API routes vs SPA routes

## 5. API Caching Headers

- [ ] 5.1 Add `Cache-Control: public, max-age=300, stale-while-revalidate=3600` to public GET endpoints
- [ ] 5.2 Document cache bypass pattern for admin UI (use `Cache-Control: no-cache` header after mutations)
- [ ] 5.3 Verify caching works correctly in browser dev tools

## 6. Testing

- [ ] 6.1 Local testing: verify all routes load correctly with loading states
- [ ] 6.2 Local testing: verify error states display correctly (test with bad IDs)
- [ ] 6.3 Local testing: verify navigation between routes works
- [ ] 6.4 Local testing: verify browser back/forward works
- [ ] 6.5 Build test: `make build` succeeds without DB
- [ ] 6.6 Docker test: verify production build works
- [ ] 6.7 Deep link test: direct URL navigation works

## 7. Documentation

- [ ] 7.1 Update `v2/CLAUDE.md` to document:
  - SPA architecture decision and rationale
  - Standard data fetching pattern
  - Loading/error component usage
- [ ] 7.2 Add inline comments explaining the pattern in key files
- [ ] 7.3 Remove any comments/docs referencing SSG/prerendering

## 8. Deployment

- [ ] 8.1 Deploy to Fly.io
- [ ] 8.2 Verify all routes work in production
- [ ] 8.3 Test deep links in production
- [ ] 8.4 Monitor for errors

## Future Work (Explicitly Deferred)

- CDN setup (add when traffic warrants)
- SEO improvements (prerendering service if needed)
- Offline support exploration
- Admin cache bypass implementation (when admin UI is built)
