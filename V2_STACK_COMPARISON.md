# V2 Stack Comparison

This document compares three architectural approaches for the Gallformers V2 rewrite.

## The Three Options

| Option | Stack | Description |
|--------|-------|-------------|
| **A** | Svelte + SvelteKit + Go API | Current V2 approach. SPA frontend with JSON API. |
| **B** | HTMX + Alpine.js + Go + templ | Server-rendered HTML with minimal JS. |
| **C** | Phoenix + Elixir | Full-stack Elixir with LiveView for real-time UI. |

---

## Complexity

| Aspect | Svelte/Go | HTMX/Go | Phoenix |
|--------|-----------|---------|---------|
| Languages | 2 (JS + Go) | 1.5 (Go + HTML attributes) | 1 (Elixir) |
| Build systems | 2 (Vite + Go) | 1 (Go) | 1 (Mix) |
| Mental models | 2 (client + server state) | 1 (server state) | 1 (server state) |
| Data flow | JSON API contract, client transforms | Server renders HTML | Server renders HTML |
| Routing | SvelteKit + Go routes | Go routes only | Phoenix routes only |
| Real-time | Manual WebSocket setup | HTMX SSE/WebSocket | LiveView (built-in) |
| Learning curve | Moderate (if you know both) | Low | High initially, then low |

**Verdict:** HTMX/Go is simplest. Phoenix is simple once you know Elixir. Svelte/Go has the most moving parts.

---

## Estimated Lines of Code

Rough estimates for full V2 implementation:

| Component | Svelte/Go | HTMX/Go | Phoenix |
|-----------|-----------|---------|---------|
| Templates/Views | ~4,000 (Svelte) | ~3,000 (templ) | ~2,500 (HEEx) |
| API/Handlers | ~2,000 (JSON) | ~2,500 (HTML render) | ~2,000 (LiveView) |
| Client JS | ~1,500 | ~200 | ~100 |
| Shared/Utils | ~800 | ~500 | ~400 |
| Config/Build | ~400 | ~150 | ~200 |
| **Total** | **~8,700** | **~6,350** | **~5,200** |

**Why Phoenix is smallest:** LiveView eliminates client-side state management. Elixir is expressive. Strong conventions reduce boilerplate.

**Why HTMX/Go is smaller than Svelte/Go:** No API client code, no client-side data transformation, no type duplication.

---

## Third-Party Dependencies

### Svelte + SvelteKit + Go

```
Frontend (node_modules):
├── @sveltejs/kit, svelte, vite
├── tailwindcss, postcss, autoprefixer
├── ~50-100 transitive deps
└── Total: ~150-200 packages

Backend (go.mod):
├── chi, sqlc, sqlite driver
└── Total: ~10-15 packages
```

**Risk:** npm ecosystem churn, security advisories, version conflicts.

### HTMX + Alpine + Go + templ

```
Frontend:
├── htmx.min.js (14KB, vendored or CDN)
├── alpine.min.js (17KB, vendored or CDN)
└── tailwind CLI (standalone, no Node)

Backend (go.mod):
├── chi, sqlc, templ, sqlite driver
└── Total: ~12-18 packages
```

**Risk:** Low. All dependencies are stable and minimal.

### Phoenix + Elixir

```
mix.exs:
├── phoenix, phoenix_live_view, phoenix_html
├── ecto, ecto_sqlite3
├── tailwind (bundled)
└── Total: ~20-30 packages (Hex)
```

**Risk:** Low. Elixir ecosystem is curated, Phoenix team maintains core deps.

---

## Maintenance Overhead

| Factor | Svelte/Go | HTMX/Go | Phoenix |
|--------|-----------|---------|---------|
| Dependency updates | High (npm + Go) | Low (Go only) | Low (Mix only) |
| Breaking changes | Medium (SvelteKit evolves) | Very Low (HTMX stable) | Low (Phoenix careful) |
| Security patches | Higher surface area | Minimal surface area | Minimal surface area |
| Ecosystem knowledge | Need JS + Go devs | Go devs only | Elixir devs only |
| Deployment | Build frontend + backend | Single binary | Release tarball or Docker |
| Debugging | Browser + server | Mostly server | Mostly server |

---

## Public API Capabilities

All three options can serve a public JSON API. Here's how they compare:

| Feature | Go (both options) | Phoenix |
|---------|-------------------|---------|
| JSON serialization | encoding/json (fast) | Jason (fast) |
| API versioning | Router groups | Router scopes |
| Rate limiting | Manual or middleware | Hammer library |
| Authentication | Manual JWT/API keys | Guardian library |
| Documentation | swag, oapi-codegen | open_api_spex |
| GraphQL | gqlgen | Absinthe |
| WebSocket/SSE | Manual | Built-in |

Phoenix serves APIs excellently - it was an API framework before LiveView existed. Both approaches are production-ready for public APIs.

---

## Database Access Comparison

| Aspect | Prisma (v1) | sqlc (v2 Go) | Ecto (Phoenix) |
|--------|-------------|--------------|----------------|
| Query style | Method chaining | Raw SQL → generated Go | DSL or raw SQL |
| Type safety | Generated types | Generated types | Compile-time checks |
| Migrations | Prisma Migrate | Manual SQL | Ecto migrations |
| Validation | Separate (Zod) | Manual | Built-in (changesets) |
| Associations | Implicit loading | Manual joins | Explicit preload |
| N+1 prevention | `include` | Manual | `preload` (explicit) |
| Raw SQL escape | `$queryRaw` | Native | `Repo.query` / `fragment` |

### Ecto Highlights

**Changesets** - Validation is data, composable and testable:

```elixir
def changeset(species, attrs) do
  species
  |> cast(attrs, [:name, :abundance])
  |> validate_required([:name])
  |> validate_length(:name, min: 1, max: 255)
  |> unique_constraint(:name)
end
```

**Composable queries** - Build complex queries from simple pieces:

```elixir
Species
|> with_images()
|> with_hosts()
|> by_family("Cynipidae")
|> Repo.all()
```

**Explicit preloading** - No surprise N+1 queries:

```elixir
# Must explicitly request associations
species = Repo.get(Species, 1) |> Repo.preload([:hosts, :images])
```

---

## LLM Proficiency Comparison

How well can LLMs (Claude, GPT, etc.) work with each stack?

### Training Data Volume

| Stack | Relative Volume | Notes |
|-------|-----------------|-------|
| JavaScript/Svelte | Very High | JS dominates GitHub |
| Go | High | Top 10 language |
| HTMX | Low-Medium | Growing but newer |
| Alpine.js | Medium | Simple, decent adoption |
| templ | **Very Low** | Released 2023 |
| Elixir/Phoenix | Medium | Smaller but high-quality |
| Ecto | Medium | Well-documented |

### Proficiency Ratings

| Stack | Rating | Weak Points |
|-------|--------|-------------|
| Svelte/Go | 8/10 | Svelte 5 runes are new |
| HTMX/Go | 6/10 | **templ syntax** - very limited training data |
| Phoenix | 7/10 | May generate outdated patterns |

### Confidence by Feature (Glossary Example)

```
Svelte/Go:
├── Go JSON endpoint:     95%
├── Svelte component:     85%
└── SvelteKit patterns:   75%

HTMX/Go:
├── Go HTML endpoint:     90%
├── HTMX attributes:      80%
└── templ templates:      50% ← weak point

Phoenix:
├── Phoenix controller:   85%
├── LiveView:             80%
├── Ecto queries:         85%
└── HEEx templates:       80%
```

### Recommendations for Agent Work

| Stack | Agent Effectiveness | Supervision Needed |
|-------|--------------------|--------------------|
| Svelte/Go | High | Low-Medium |
| HTMX/Go | Medium | **High for templ** |
| Phoenix | Medium-High | Medium |

**Mitigations:**
- For HTMX/Go: Create `TEMPL_PATTERNS.md` with examples for agents
- For Phoenix: Include docs in agent context, review Elixir idioms
- Both: Tracer bullets will reveal actual supervision needs

---

## Summary Comparison

| Approach | Best For | Watch Out For |
|----------|----------|---------------|
| **Svelte/Go** | Rich client interactivity, existing JS expertise | Build complexity, two ecosystems, npm fatigue |
| **HTMX/Go** | Simplicity, minimal JS, fast dev, easy maintenance | Smaller ecosystem, templ is newer |
| **Phoenix** | Best DX once learned, real-time features, long-term maintainability | Learning Elixir, smaller hiring pool |

---

## Final Decision: Phoenix + Elixir

**Decision Date:** January 2026

**Chosen Stack:** Phoenix + Elixir (Option C)

### Rationale

After evaluating all three options including implementing a tracer bullet (glossary page with LiveView), Phoenix was selected for the following reasons:

1. **Developer experience** - Phoenix + LiveView provides the best DX once comfortable with Elixir. Server-rendered real-time UI without managing client-side state.

2. **Maintainer background** - Strong functional programming background (Scala, fp-ts, Akka) makes Elixir a natural fit. The learning curve is minimal given existing experience with:
   - Pattern matching
   - Immutable data
   - Actor model concurrency
   - Pipe-based composition

3. **Single maintainer context** - The "smaller hiring pool" concern doesn't apply. What matters is maintainer productivity and enjoyment.

4. **Long-term maintenance** - Phoenix has excellent backwards compatibility, minimal dependencies, and the Elixir ecosystem is curated and stable.

5. **Built-in capabilities** - LiveView, PubSub, Channels, and OTP provide real-time features without additional complexity.

6. **Ecto** - Composable queries, changesets for validation, and explicit preloading align well with FP preferences.

### What This Means

- V2 will be a full Elixir/Phoenix application
- The existing Go API code will be rewritten in Elixir (logic transfers, syntax changes)
- SvelteKit frontend is replaced by Phoenix LiveView
- Deployment remains on Fly.io (excellent Phoenix support)
- SQLite continues as the database (via ecto_sqlite3)

### Tracer Bullet Results

The Phoenix tracer bullet (glossary page) was completed successfully, validating:
- Ecto queries against existing SQLite schema
- LiveView for interactive table sorting
- HEEx templates with Tailwind styling
- Development workflow with Mix

The HTMX tracer bullet was not pursued after the Phoenix evaluation proved sufficient for the decision.
