# Change: Convert V2 Frontend to Pure SPA Architecture

## Why

The V2 frontend currently uses SvelteKit with `adapter-static` and `prerender = true`, creating a Static Site Generation (SSG) architecture. This causes several problems:

1. **Admin frustration**: When admins edit data, they must wait for cache expiration or rebuilds to see changes
2. **Build complexity**: SSG requires database access at build time, creating stale data issues
3. **V1 pain repeated**: The V1 Next.js SSR approach caused significant maintenance headaches that we're inadvertently recreating
4. **Misaligned with primary use cases**: The ID tool (primary) and admin interface (secondary) are interactive applications, not static content

After extensive discussion, the decision is to adopt a **pure SPA (Single Page Application)** architecture where:
- Go serves static HTML/JS/CSS files
- All data is fetched at runtime via API calls
- No prerendering, no SSG, no build-time data baking

## What Changes

### Architecture Changes

- **Remove SSG/prerendering** from SvelteKit configuration
- **Convert all pages** to fetch data client-side (in `onMount` or with `ssr: false`)
- **Simplify build process** - no database access needed at build time
- **Go serves SPA** - single `index.html` with client-side routing fallback

### Code Changes

- Delete `export const prerender = true/false` from all route files
- Convert `+page.js` load functions to client-side only (`ssr: false`) or move to `onMount`
- Update `svelte.config.js` for SPA mode
- Update Go's static file server for SPA fallback routing

### Infrastructure Changes (TBD)

- Evaluate CDN options for traffic spike protection
- Configure appropriate caching headers on Go API responses

## Impact

- **Affected specs**: `v2-infrastructure`
- **Affected code**:
  - `v2/web/svelte.config.js`
  - `v2/web/src/routes/+layout.js`
  - All `v2/web/src/routes/**/+page.js` files
  - `v2/api/cmd/server/main.go` (SPA fallback routing)
- **Build process**: Simplified - no longer needs database at build time
- **SEO**: Reduced (acceptable tradeoff, can add prerendering service later if needed)

## Open Questions

### 1. CDN Provider

**Context**: Pure SPA means every page load triggers API calls. A traffic spike (e.g., link from Washington Post) could overwhelm the Go API + SQLite backend. A CDN in front caches responses and absorbs spikes.

**Options**:

| Provider | Pros | Cons |
|----------|------|------|
| **Cloudflare** | Free tier generous, easy setup, good DDoS protection | Has had controversy (privacy, selective enforcement), "free" means you're the product |
| **Bunny CDN** | Privacy-focused, simple pricing (~$0.01/GB), no free tier lock-in | Costs money (though minimal), less name recognition |
| **Fastly** | Developer-friendly, great edge compute | More expensive, overkill for our scale |
| **Fly.io built-in** | Already using Fly, no additional vendor | Less sophisticated caching, limited edge locations |
| **No CDN initially** | Simplest, fewer moving parts | Risk if traffic spikes occur |

**Decision**: No CDN for now. Add reactively if traffic becomes a concern. Keeps architecture simple.

### 2. Scope of Rework

**Question**: How much existing code needs to change?

**Current state**:
- 11 route files with `+page.js` (some already have `prerender = false`)
- Root `+layout.js` sets `prerender = true`
- `svelte.config.js` uses `adapter-static` with prerender config
- Some pages use `load` functions that expect SSR context

**Scope options**:

| Scope | Description | Effort |
|-------|-------------|--------|
| **Minimal** | Just remove prerendering, keep load functions but mark as client-only | Small - config changes + `ssr: false` annotations |
| **Standard** | Convert load functions to `onMount` pattern for clarity | Medium - refactor data fetching in all routes |
| **Full** | Standardize all data fetching patterns, add loading states, error boundaries | Larger - but cleaner long-term |

**Decision**: Full scope. Standardize all data fetching patterns, add consistent loading states and error boundaries. Do it right the first time.

### 3. Code Simplification Assessment

**What gets simpler**:

| Area | Before (SSG) | After (SPA) | Simplification |
|------|--------------|-------------|----------------|
| Build process | Needs DB access, prerender crawl, generate static HTML | Just bundles JS/CSS | **Significant** |
| Route files | Mix of `prerender = true/false`, load functions with server/client split | Uniform client-side fetching | **Moderate** |
| Go server | Serves prerendered HTML per-route | Serves single `index.html` for all routes | **Moderate** |
| Mental model | "Which pages prerender? When does cache expire?" | "All data is fresh from API" | **Significant** |
| Deployment | Build must complete before deploy, stale DB = stale pages | Deploy anytime, data always live | **Significant** |

**What gets more complex**:

| Area | Impact |
|------|--------|
| Initial page load | Slightly slower (JS must load, then fetch data) |
| SEO | Worse without additional tooling |
| Loading states | Must handle "loading..." in every page |

**Net assessment**: Significant simplification in build/deploy/mental model. Minor increase in client-side loading state management.

### 4. Additional Considerations

**Database at build time**: Current build process uses a DB copy that may be stale. With pure SPA, this problem disappears - build doesn't need DB at all.

**Admin instant updates**: With SPA, admin saves data via API, refetches, sees change immediately. No cache invalidation, no rebuild triggers.

**Future offline support**: SPA architecture is prerequisite for service worker + offline support. Not implementing now, but this keeps the door open.

**SEO fallback options** (if needed later):
- Prerender.io (~$15/month) - crawler-specific rendering
- Self-hosted Rendertron - free but more ops work
- SvelteKit SSR hybrid - add SSR back for specific routes only
