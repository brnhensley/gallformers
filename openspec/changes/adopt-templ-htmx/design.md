# Design: Go + Templ + HTMX Architecture

## Context

V2 is being built as a Go API + SvelteKit frontend. The current approach uses SSG (Static Site Generation), which causes stale data after admin edits. After evaluating alternatives (pure SPA, ISR, Phoenix LiveView), the decision is to replace SvelteKit with server-side rendering using Go + Templ + HTMX.

**Stakeholders**:
- Site admins (need instant feedback on changes)
- End users (need fast, reliable access to data)
- Developer (needs simple, maintainable, LLM-friendly architecture)

**Constraints**:
- Single Go binary deployment (no Node.js runtime)
- Low traffic most of the time, occasionally bursty
- Primary use case is ID tool (interactive)
- SEO is nice-to-have, not critical
- No budget for expensive infrastructure

## Goals / Non-Goals

**Goals**:
- Admin changes visible immediately without rebuild
- Server renders full HTML (good SEO, no JS required for content)
- Simple, explicit code patterns (LLM-friendly)
- Single Go binary deployment
- Minimal client-side JavaScript
- Type-safe templates (compile-time errors, not runtime)

**Non-Goals**:
- Rich client-side interactivity everywhere (only where needed)
- Offline support
- Sub-100ms page loads (acceptable if under 500ms)

## Decisions

### Decision 1: Use Templ for templates

**What**: Replace SvelteKit with [Templ](https://templ.guide) - a Go templating language that compiles to Go code.

**Why**:
- Type-safe: template errors caught at compile time
- Fast: compiles to Go, no runtime parsing
- Composable: components are just functions
- IDE support: LSP, syntax highlighting
- Stays in Go ecosystem

**Example**:
```go
// templates/pages/gall.templ
templ GallPage(data GallData) {
    @Base(data.Species.Name) {
        <h1>{ data.Species.Name }</h1>
        @GallDetails(data.Species, data.Gall)
        @HostList(data.Hosts)
    }
}
```

**Alternative considered**: Go `html/template`
- Rejected: Not type-safe, awkward syntax, no LSP support

**Development workflow**:
- Use `air` for Go live reload (rebuilds on `.go` file changes)
- Use `templ generate --watch` for template live reload (regenerates `_templ.go` on `.templ` changes)
- `make dev` runs both in parallel
- Browser refresh shows updated templates within ~1 second

### Decision 2: Use HTMX for interactivity

**What**: Use [HTMX](https://htmx.org) (14KB) for dynamic interactions instead of a JS framework.

**Why**:
- Server returns HTML fragments, not JSON
- No client-side state management
- No build step for JS
- Progressive enhancement - works without JS
- Simple mental model: request → render → swap

**Example**:
```html
<input type="search"
       hx-get="/partials/search"
       hx-target="#results"
       hx-trigger="input changed delay:300ms">
<div id="results"></div>
```

**Alternative considered**: Keep Svelte for interactivity
- Rejected: Requires Node build, larger bundle, more complexity

**URL state management**:
- Filter changes in ID tool and search use `hx-push-url="true"` to update browser URL
- URL query params reflect current filter state (e.g., `/id?host=oak&shape=spherical`)
- On page load, server reads URL params and renders with those filters applied
- Enables bookmarking and sharing of filtered views
- Back/forward navigation works via `htmx:historyRestore` event

**Error handling**:
```html
<!-- In base layout, after HTMX loads -->
<script>
  document.body.addEventListener('htmx:responseError', (e) => {
    const msg = e.detail.xhr?.status === 0
      ? 'Network error - please check your connection'
      : `Error: ${e.detail.xhr?.statusText || 'Something went wrong'}`;
    // Display via toast/alert component
    showAlert(msg, 'error');
  });
</script>
```

- Network errors (offline, timeout): Show user-friendly message
- Server errors (500): Show generic error, log details
- Validation errors (400): Handler returns HTML fragment with error messages, HTMX swaps into form

### Decision 3: Error page handling

**What**: Friendly error pages for 404, 500, and other errors.

**Templates**:
- `templates/pages/404.templ` - Not found (invalid ID, deleted entity)
- `templates/pages/500.templ` - Server error (DB failure, unexpected panic)

**Handler pattern**:
```go
func GallPage(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    data, err := db.GetGall(id)
    if errors.Is(err, db.ErrNotFound) {
        w.WriteHeader(404)
        templates.NotFound().Render(r.Context(), w)
        return
    }
    if err != nil {
        log.Error("gall page error", "id", id, "err", err)
        w.WriteHeader(500)
        templates.ServerError().Render(r.Context(), w)
        return
    }
    // ... render page
}
```

**Recovery middleware**:
- Catch panics, log stack trace, render 500 page
- Don't expose internal errors to users

### Decision 4: Page caching with invalidation

**What**: Cache rendered HTML in memory, invalidate on mutations.

**Implementation**:
```go
import lru "github.com/hashicorp/golang-lru/v2"

// Thread-safe LRU cache with expiring entries
cache, _ := lru.New[string, cacheEntry](10000)

type cacheEntry struct {
    html      []byte
    expiresAt time.Time
}

// On page request
if entry, ok := cache.Get("gall:" + id); ok && time.Now().Before(entry.expiresAt) {
    return entry.html
}
html := renderPage(id)
cache.Add("gall:" + id, cacheEntry{html: html, expiresAt: time.Now().Add(1 * time.Hour)})
return html

// On admin edit
cache.Remove("gall:" + id)
cache.Remove("host:" + affectedHostID)  // invalidate related
```

**Why hashicorp/golang-lru**:
- Thread-safe (no manual locking needed)
- Built-in LRU eviction
- Well-tested, widely used
- Simple API

**Cache policy**:
- TTL: 1 hour (automatic expiry)
- Invalidation: immediate on mutation
- Scope: per-entity pages
- Max entries: 10,000 (LRU eviction when exceeded)
- Estimated memory: ~200-400MB at full capacity (~8,000 pages currently)

**Stampede protection**:
- Use `golang.org/x/sync/singleflight` to coalesce concurrent requests for the same uncached page
- If page X is being rendered, other requests for X wait for that render instead of triggering parallel renders
- Prevents DB/CPU spikes after deployment or cache clear

**Deployment cache handling**:
- Cache is cleared on server startup (fresh deploy = fresh cache)
- Singleflight prevents stampede from concurrent cold-cache requests

**Why not Redis/external cache**:
- Single instance deployment (Fly.io)
- In-memory is simpler, fast enough
- Can upgrade later if needed

**Browser cache headers**:
- Static assets (`/static/*`): `Cache-Control: public, max-age=31536000, immutable` (1 year, hash-busted)
- Full pages: `Cache-Control: no-cache` (browser revalidates, server responds from cache)
- Partials: `Cache-Control: no-store` (never cache, always fresh)
- API responses: `Cache-Control: no-store`

### Decision 5: HTMX partials vs full pages

**What**: Two types of handlers - full pages and partials.

**Full pages** (`/gall/123`):
- Return complete HTML document
- Cached
- Used for initial page load, direct navigation

**Partials** (`/partials/gall/123`):
- Return HTML fragment only
- Not cached (always fresh)
- Used for HTMX updates, refresh actions

**Routing structure**:
```go
r.Get("/gall/{id}", pages.Gall)           // Full page
r.Get("/partials/gall/{id}", partials.Gall) // Fragment
r.Get("/api/species/{id}", api.GetSpecies)  // JSON API
```

### Decision 6: Alpine.js for client-side state

**What**: Use [Alpine.js](https://alpinejs.dev) (15KB) for admin UI features that need client-side state.

**Use cases**:
- Tag/alias editors (add/remove items locally before save)
- Form validation feedback
- Toggle/accordion UI

**Example**:
```html
<div x-data="{ tags: [], newTag: '' }">
    <input x-model="newTag" @keydown.enter="tags.push(newTag); newTag=''">
    <template x-for="tag in tags">
        <span x-text="tag"></span>
    </template>
</div>
```

**Why Alpine.js over vanilla JS**:
- Declarative, less boilerplate
- Works well with HTMX
- Small enough to include everywhere

### Decision 7: CSRF protection for admin forms

**What**: All admin form submissions must include CSRF tokens.

**Implementation**:
```html
<!-- In admin layout head -->
<meta name="csrf-token" content="{{ .CSRFToken }}">

<!-- In admin layout, after HTMX loads -->
<script>
  document.body.addEventListener('htmx:configRequest', (e) => {
    e.detail.headers['X-CSRF-Token'] =
      document.querySelector('meta[name="csrf-token"]').content
  })
</script>
```

**Server-side**:
- Generate token per session, store in cookie or session
- Middleware validates `X-CSRF-Token` header on POST/PUT/DELETE to `/admin/*`
- Reject requests with missing or invalid tokens (403)

**Why meta tag approach**:
- Works globally for all HTMX requests without per-form configuration
- Token is HttpOnly cookie + header, preventing both CSRF and XSS token theft

### Decision 8: JavaScript islands for complex features

**What**: Use standalone JS bundles for features that truly need rich client-side behavior.

**Islands**:
- Range map (MapLibre)
- Image upload/crop (admin)
- Rich text editor (admin, if needed)

**Pattern**:
```html
<!-- Server renders container with data -->
<div id="range-map" data-range='{"states": ["CA", "OR"]}'>
</div>
<script src="/static/islands/range-map.js" defer></script>
```

**Build process**:
1. `make build` runs `make build-islands` first, then `go build`
2. Vite builds each island to `v2/static/islands/` with content-hashed filenames
3. Vite generates `v2/static/islands/manifest.json` mapping logical names to hashed files
4. Go server reads manifest at startup to resolve island script URLs
5. Node.js required at build time only (CI/CD), not at runtime

```json
// v2/static/islands/manifest.json
{
  "range-map": "range-map.a1b2c3.js",
  "image-upload": "image-upload.d4e5f6.js"
}
```

### Decision 9: Markdown and glossary processing

**What**: Server-side markdown rendering with glossary auto-linking.

**Implementation**:
```go
var md = goldmark.New(
    goldmark.WithExtensions(extension.GFM),
)

func (p *Processor) Render(source string) string {
    html := md.Convert(source)
    return glossary.LinkTerms(html)
}
```

**When processed**: At render time (page handler), cached with page.

**Glossary updates**: Clear all page caches (glossary terms can appear anywhere).

**Security**: Raw HTML in markdown is disabled (goldmark default). This prevents XSS if admin-entered content contains malicious scripts. Do not enable `html.WithUnsafe()`.

### Decision 10: SEO implementation

**What**: Proper meta tags, structured data, and sitemap for search engine optimization.

**Meta tags** (all pages):
```html
<title>{ species.Name } - Gallformers</title>
<meta name="description" content={ species.Description[:160] }>
<link rel="canonical" href={ "https://gallformers.org/gall/" + species.ID }>

<!-- Open Graph -->
<meta property="og:title" content={ species.Name }>
<meta property="og:description" content={ species.Description[:160] }>
<meta property="og:image" content={ species.PrimaryImage }>
<meta property="og:url" content={ canonicalURL }>
<meta property="og:type" content="website">
```

**Structured data** (species pages):
```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Thing",
  "name": "{{ .Species.Name }}",
  "description": "{{ .Species.Description }}",
  "image": "{{ .Species.PrimaryImage }}",
  "url": "{{ .CanonicalURL }}"
}
</script>
```

**Sitemap**:
- Generate `/sitemap.xml` dynamically (or on build)
- Include all public pages: galls, hosts, families, genera, sources
- Update `lastmod` based on entity update timestamps
- Register with Google Search Console

**Robots.txt**:
- Allow all public pages
- Disallow `/admin/*` and `/partials/*`

### Decision 11: Static asset cache busting

**What**: Version static assets to prevent browsers serving stale CSS/JS after deployment.

**Implementation**:
- **Islands (Vite-built)**: Content-hashed filenames automatic (`range-map.a1b2c3.js`)
- **Core assets (HTMX, Alpine, styles.css)**: Query param with build hash

```go
// Generated at build time or read from file
var BuildHash = "a1b2c3"

// In templates
<link rel="stylesheet" href={ "/static/css/styles.css?v=" + BuildHash }>
<script src={ "/static/js/htmx.min.js?v=" + BuildHash } defer></script>
```

**Build integration**:
- `make build` generates hash from git commit or timestamp
- Hash is embedded in binary or read from `version.txt`
- Templates access hash via shared variable

### Decision 12: Styling approach

**What**: Port existing Tailwind CSS styling from SvelteKit to work with Templ templates.

**Current V2 stack**:
- Tailwind CSS v4 (configuration in CSS via `@theme`, not `tailwind.config.js`)
- PostCSS with autoprefixer
- Custom brand colors: `gf-sky-blue`, `gf-autumn`, `gf-maroon`
- League Spartan custom font
- Utility classes for cards, tables, jargon terms, markdown content

**Migration approach**:
1. **Copy `app.css`** from `v2/web/src/app.css` to `v2/static/css/`
2. **Build Tailwind** at build time using Tailwind CLI (not Node runtime)
3. **Preserve all custom classes** - jargon-term, markdown-content, card styles, etc.
4. **Same class names in Templ** - templates use identical Tailwind classes as Svelte components

**Build process**:
```bash
# In Makefile
build-css:
    npx @tailwindcss/cli -i static/css/app.css -o static/css/styles.css --minify
```

**Template usage** (identical to Svelte):
```go
templ PageTitle(title string) {
    <h1 class="text-2xl font-bold text-gf-maroon mb-4">{ title }</h1>
}

templ Card(title string) {
    <div class="bg-white rounded border border-gray-200 shadow-sm">
        <div class="px-4 py-3 border-b border-gray-200">
            <h2 class="text-xl font-semibold text-gf-maroon">{ title }</h2>
        </div>
        <div class="p-4">
            { children... }
        </div>
    </div>
}
```

**Why not rewrite styles**:
- Visual parity is a hard requirement
- Existing styles are tested and work
- Rewriting invites subtle differences and bugs

### Decision 13: Directory structure

```
v2/
├── cmd/server/main.go           # Entry point
├── internal/
│   ├── server/                  # HTTP server, routes, middleware
│   ├── handlers/
│   │   ├── pages/               # Full page handlers
│   │   ├── partials/            # HTMX fragment handlers
│   │   ├── api/                 # JSON API handlers
│   │   └── admin/               # Admin page handlers
│   ├── cache/                   # Page cache
│   ├── markdown/                # Markdown + glossary processing
│   └── db/                      # Database layer (existing)
├── templates/
│   ├── layouts/                 # Base, public, admin layouts
│   ├── components/              # Shared components
│   ├── pages/                   # Page templates
│   ├── partials/                # HTMX fragment templates
│   └── admin/                   # Admin templates
├── static/
│   ├── css/                     # Stylesheets
│   ├── js/                      # HTMX, Alpine.js
│   └── islands/                 # Built JS islands
├── islands/                     # Island source (Svelte/JS)
│   ├── range-map/
│   └── image-upload/
└── Makefile
```

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Templ learning curve | Low | Simple syntax, good docs, similar to JSX |
| HTMX limitations | Medium | Fall back to Alpine.js or JS islands |
| Cache memory usage | Low | Configurable TTL, LRU eviction if needed |
| Less "modern" DX | Low | Trade-off for simplicity and LLM-friendliness |
| Island build complexity | Low | Minimal islands, simple Vite config |
| Partials endpoint abuse | Low | Add rate limiting if abuse observed (not implemented initially) |

## Migration Plan

**Critical constraint**: Styling and layout MUST match current V2 SvelteKit site. Do NOT delete `v2/web/` until visual parity is verified.

**Parallel operation**: During migration, both systems can run simultaneously:
- SvelteKit continues serving at current routes
- Templ pages added incrementally at new routes or behind feature flag
- Compare side-by-side before switching each page
- Only remove SvelteKit after ALL pages achieve visual parity

### Phase 1: Foundation
- Add Templ dependency, configure build
- Create base layout templates
- Port CSS from SvelteKit (do NOT rewrite - copy and adapt)

### Phase 2: Core Pages
- Migrate public pages (gall, host, family, etc.)
- Implement page caching
- Add HTMX partials for refresh

### Phase 3: Interactive Features
- Migrate search to HTMX
- Migrate ID tool to HTMX
- Port range map as JS island

### Phase 4: Admin
- Migrate admin pages with HTMX forms
- Add cache invalidation on mutations
- Port complex admin features as islands

### Phase 5: Cleanup (only after visual parity verified)
- Verify all pages match SvelteKit visually (side-by-side comparison)
- Remove SvelteKit (`v2/web/`)
- Update Dockerfile, Makefile
- Update documentation

## Rollback Strategy

Before starting work, create `pre-templ` git tag. Rollback = deploy from that tag.

The migration can be done incrementally - both systems can coexist during transition if needed (Go serves some routes, SvelteKit serves others).
