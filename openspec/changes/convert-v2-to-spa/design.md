# Design: Pure SPA Architecture

## Context

V2 is being built as a SvelteKit frontend + Go API backend. The current implementation uses Static Site Generation (SSG) via `adapter-static` with prerendering enabled. This mirrors the V1 Next.js approach that caused significant operational pain.

**Stakeholders**:
- Site admins (need instant feedback on changes)
- End users (need fast, reliable access to data)
- Developer (needs simple, maintainable architecture)

**Constraints**:
- Low traffic most of the time, occasionally bursty
- Primary use case is ID tool (interactive)
- Secondary use case is admin interface
- SEO is nice-to-have, not critical
- No budget for expensive infrastructure

## Goals / Non-Goals

**Goals**:
- Admin changes visible immediately without rebuild/cache invalidation
- Simplified build process (no DB at build time)
- Reduced operational complexity
- Maintain good user experience for primary use cases
- Keep infrastructure costs minimal

**Non-Goals**:
- Maximum SEO optimization (acceptable tradeoff)
- Offline support (future consideration, not this change)
- Sub-100ms page loads (acceptable if within reason)

## Decisions

### Decision 1: Pure SPA with adapter-static

**What**: Use SvelteKit's `adapter-static` in SPA mode - builds a single-page app that handles all routing client-side.

**Why**:
- Keeps current build tooling (SvelteKit, Vite)
- Go embeds static files as today
- Minimal changes to deployment pipeline
- Well-supported configuration

**Configuration**:
```javascript
// svelte.config.js
import adapter from '@sveltejs/adapter-static';

const config = {
  kit: {
    adapter: adapter({
      pages: 'build',
      assets: 'build',
      fallback: 'index.html',  // KEY: SPA fallback
      precompress: false,
      strict: false  // Allow non-prerendered routes
    })
  }
};
```

**Alternative considered**: Switch to a different framework (vanilla Svelte, etc.)
- Rejected: SvelteKit provides good routing, would be significant rework

### Decision 2: Client-side data fetching pattern

**What**: All data fetching happens in the browser via API calls.

**Pattern**:
```svelte
<script>
  import { onMount } from 'svelte';
  import { api } from '$lib/api';

  let data = null;
  let loading = true;
  let error = null;

  onMount(async () => {
    try {
      data = await api.getSpecies(id);
    } catch (e) {
      error = e;
    } finally {
      loading = false;
    }
  });
</script>

{#if loading}
  <LoadingSpinner />
{:else if error}
  <ErrorMessage {error} />
{:else}
  <SpeciesDetail {data} />
{/if}
```

**Alternative considered**: Keep SvelteKit load functions with `ssr: false`
- Could work, but mixing patterns is confusing
- `onMount` is more explicit about client-side behavior

### Decision 3: Go SPA fallback routing

**What**: Go serves `index.html` for any route that doesn't match a static file or API endpoint.

**Implementation**:
```go
// Simplified - actual implementation in main.go
func spaFileServer(fs http.FileSystem) http.Handler {
    fileServer := http.FileServer(fs)
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        path := r.URL.Path

        // Try to serve static file
        if _, err := fs.Open(path); err == nil {
            fileServer.ServeHTTP(w, r)
            return
        }

        // Fallback to index.html for SPA routing
        r.URL.Path = "/"
        fileServer.ServeHTTP(w, r)
    })
}
```

This already exists in `v2/api/cmd/server/main.go` - just needs verification it works correctly.

### Decision 4: No CDN

**What**: Launch without CDN.

**Why**:
- Current traffic is low
- Adds complexity and potential cost
- Can be added non-disruptively later if needed
- Fly.io provides some edge caching built-in

**Trigger for revisiting**: Sustained traffic > 10k requests/day or any viral traffic event.

### Decision 5: API caching headers

**What**: Go API sets cache headers to enable browser caching.

**Headers for public data**:
```
Cache-Control: public, max-age=300, stale-while-revalidate=3600
```
- Fresh for 5 minutes
- Serve stale up to 1 hour while revalidating
- Browsers and intermediate caches can store

**Headers for admin-modified data**:
- Admin UI sends `Cache-Control: no-cache` on requests after mutations
- Ensures admin sees fresh data immediately

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| SEO degradation | Medium - less search traffic | Google executes JS; can add prerendering later if needed |
| Slower initial page load | Low - noticeable but acceptable | Loading states, optimize bundle size |
| Traffic spike overwhelms API | Medium - site goes down | Monitor; add CDN reactively if needed |
| Social media preview cards blank | Medium - poor sharing experience | Can add server-side meta tag injection later |

## Migration Plan

### Phase 1: Configuration
1. Update `svelte.config.js` for SPA mode
2. Remove `prerender` exports from all route files

### Phase 2: Shared Patterns
1. Create loading components (spinner, skeleton, page loading)
2. Create error components (error message, error boundary, not found)
3. Create async data store pattern

### Phase 3: Route Refactoring
1. Refactor each route to use onMount + standardized patterns
2. Add consistent loading states to all pages
3. Add error handling to all pages
4. Delete +page.js load functions

### Phase 4: Testing & Documentation
1. Test all routes locally
2. Update documentation
3. Deploy and verify

### Rollback
If issues discovered:
1. Revert `svelte.config.js` changes
2. Restore `prerender` exports
3. Rebuild and deploy

Rollback is low-risk since it's configuration changes, not data migration.

## Open Questions

1. **CDN provider preference** - If we do add CDN, which provider? (See proposal.md for options)

2. **Loading state design** - What should loading states look like? Spinner? Skeleton? Current page structure with placeholders?

3. **Error handling strategy** - How to handle API failures gracefully? Retry logic? User-friendly error messages?

4. **Bundle size monitoring** - Should we add bundle size tracking to CI? SPA performance depends on JS bundle size.
