# Change: Adopt Phoenix + LiveView Architecture

## Why

The V2 frontend uses SvelteKit with Static Site Generation (SSG). This causes a fundamental problem:

**When admins edit data, public pages show stale content until rebuild.**

This is not a bug - it's inherent to SSG. The HTML is baked at build time. No amount of cache headers fixes it.

We explored several solutions:
1. **Pure SPA** (convert-v2-to-spa proposal) - Solves freshness but fights SvelteKit's SSR-first design
2. **Go + Templ + HTMX** (adopt-templ-htmx proposal) - Solid approach but requires learning templ, less mature ecosystem
3. **Phoenix LiveView** - Full-stack solution with best-in-class real-time UI

The chosen approach: **Phoenix + LiveView**

This architecture:
- Renders HTML server-side with HEEx templates
- LiveView maintains persistent WebSocket connection
- UI updates push automatically - no manual cache invalidation
- Admin edits are immediately visible everywhere
- Single Elixir codebase - no JSON API contract, no client-side state

## What Changes

### Architecture Changes

- **Remove SvelteKit entirely** - No more `v2/web/` directory
- **Remove Go API** - Replaced by Phoenix
- **Phoenix renders all HTML** - Using HEEx templates and LiveView
- **LiveView for interactivity** - Search, ID tool, forms use LiveView
- **PubSub for real-time updates** - Admin edits broadcast to all connected clients
- **JS hooks for complex UI** - Range maps, image upload that truly need JS

### Code Changes

- Move `v2/` to `v2_old/` (Go + SvelteKit preserved as reference)
- Create new Phoenix application in `v2/`
- Ecto schemas mapping to existing SQLite database
- LiveView modules for each page
- HEEx templates with Tailwind styling
- Use `v2_old/` as the spec for porting (the code IS the documentation)
- Remove `v2_old/` after migration complete and visual parity verified

### What Stays the Same

- SQLite database (same schema, accessed via Ecto)
- S3 image storage (public URLs)
- Auth0 authentication (via ueberauth)
- Fly.io deployment (excellent Phoenix support)
- Domain/DNS
- Visual design (same Tailwind classes)

## Impact

- **Affected specs**: `v2-infrastructure`
- **Supersedes**: `convert-v2-to-spa` proposal
- **Affected code**: All of `v2/` replaced
- **Build process**: Mix (no Node.js needed except for Tailwind)
- **SEO**: Excellent - server renders full HTML

## Resolved Questions

### 1. Why Phoenix over Go + HTMX?

Both are excellent choices. Phoenix was selected because:
- LiveView provides HTMX-like simplicity with more power (real-time, form handling)
- Ecto changesets handle validation elegantly
- Maintainer has strong FP background (Scala, fp-ts, Akka) - Elixir is natural fit
- Single language for entire stack
- Built-in real-time (PubSub) without additional setup

### 2. What about the existing Go code?

The Go API logic transfers to Elixir - same concepts, different syntax:
- sqlc queries → Ecto queries
- Chi handlers → Phoenix controllers/LiveView
- Go structs → Elixir schemas

### 3. What about admin complexity?

LiveView handles all admin use cases:
- Simple forms: LiveView with changesets
- Tag editors: LiveView with list state
- Complex features (drag-drop uploads): JS hooks

### 4. What about range maps?

JavaScript hook. LiveView embeds GeoJSON data, JS hook initializes MapLibre. Clean boundary between server state and JS visualization.

### 5. What about markdown/glossary linking?

Server-side with earmark or mdex. Glossary terms auto-linked during render.

### 6. Performance?

- Initial page load: Full HTML rendered server-side (~5-20ms)
- Subsequent interactions: WebSocket diffs (~1-5ms perceived latency)
- No cold cache concerns - LiveView state is always current

### 7. LLM-friendliness?

Phoenix + Elixir is moderately LLM-friendly:
- Consistent patterns (Phoenix conventions)
- Well-documented
- Smaller training corpus than JS/Go but high quality
- Maintainer can review and correct Elixir idioms

## Open Questions

None currently. Tracer bullet (glossary page) validated the approach. Ready for implementation.
