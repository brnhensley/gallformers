# Change: Adopt Go + Templ + HTMX Architecture

## Why

The V2 frontend uses SvelteKit with Static Site Generation (SSG). This causes a fundamental problem:

**When admins edit data, public pages show stale content until rebuild.**

This is not a bug - it's inherent to SSG. The HTML is baked at build time. No amount of cache headers fixes it.

We explored several solutions:
1. **Pure SPA** (convert-v2-to-spa proposal) - Solves freshness but fights SvelteKit's SSR-first design, requires bot detection for SEO, adds complexity
2. **ISR (Incremental Static Regeneration)** - The right solution, but SvelteKit doesn't have it. Next.js does, but is increasingly Vercel-locked.
3. **Phoenix LiveView** - Elegant solution but requires learning Elixir

The chosen approach: **Go + Templ + HTMX**

This architecture:
- Renders HTML server-side with Go templates
- Caches rendered pages in memory
- Invalidates cache on edit - next request gets fresh data
- Uses HTMX for interactivity without a JS framework
- Keeps everything in Go - single binary, simple deployment

## What Changes

### Architecture Changes

- **Remove SvelteKit entirely** - No more `v2/web/` directory
- **Go renders all HTML** - Using Templ (type-safe Go templates)
- **HTMX for interactivity** - Search, ID tool, forms use HTMX instead of client-side JS
- **Server-side caching** - Rendered pages cached, invalidated on mutation
- **Svelte islands for complex UI** - Range maps, admin features that truly need JS

### Code Changes

- Delete `v2/web/` (SvelteKit)
- Add `v2/templates/` (Templ templates)
- Add `v2/static/` (CSS, JS islands, HTMX)
- Modify `v2/api/` to render pages, not just serve JSON
- Add page cache with invalidation

### What Stays the Same

- SQLite database
- S3 image storage (public URLs, no signing required)
- Auth0 authentication
- Fly.io deployment
- Go API endpoints (still available for external use)
- Domain/DNS

## Impact

- **Affected specs**: `v2-infrastructure`, `common-components`
- **Supersedes**: `convert-v2-to-spa` proposal (this is an alternative approach)
- **Affected code**: All of `v2/web/` replaced, `v2/api/` expanded
- **Build process**: Simpler - just `go build`, no Node.js needed
- **SEO**: Better - server renders full HTML, no bot detection needed

## Resolved Questions

### 1. Why not keep SvelteKit?

SvelteKit's SSG bakes data at build time. SvelteKit's SSR requires Node.js runtime. Neither fits our constraint (Go binary, fresh data on edit). We'd be fighting the framework.

### 2. What about admin complexity?

Admin forms use a layered approach:
- Simple forms: HTMX (server validates, returns updated HTML)
- Medium complexity (tag editors): Alpine.js (15KB, client-side state)
- Complex features (drag-drop, uploads): Svelte islands

### 3. What about range maps?

JavaScript island. Server embeds GeoJSON data, small JS module initializes MapLibre. Same pattern as current, just mounted differently.

### 4. What about markdown/glossary linking?

Server-side text processing with goldmark (Go markdown library). Glossary terms auto-linked during render. Cached with page.

### 5. Performance impact?

- Cold cache: DB query + template render (~5-20ms)
- Warm cache: serve cached bytes (~0.1ms)
- After warmup, equivalent to serving static files

### 6. LLM-friendliness?

Go + Templ + HTMX is highly LLM-friendly:
- Explicit code, no framework magic
- Simple request/response model
- Well-represented patterns in training data
- Type-safe templates catch errors at compile time

## Open Questions

None currently. Ready for implementation.
