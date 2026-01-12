# V2 Development - Agent Instructions

## Scope

You are working on the gallformers v2 rewrite. All v2 code lives in this directory (`v2/`).

The v2 stack is:
- **Go API** (`v2/api/`) - REST API server serving JSON endpoints and static files
- **Svelte Web** (`v2/web/`) - SvelteKit frontend (JavaScript, not TypeScript) compiled to static files
- **SQLite** - Database (shared with v1 during development)
- **Fly.io** - Production hosting
- **JavaScript** - Do not create TypeScript files this is a JavaScript project -- you are too dense to understand TypeScript and it creates huge messes. Do not do it or you will be fired, no excuses you have been told.

## Isolation Rules

- **DO NOT** modify code outside of `v2/`
- **DO NOT** add dependencies on v1 code (`pages/`, `libs/`, `components/`)
- **DO NOT** modify the root `CLAUDE.md`, `package.json`, or other v1 configuration files
- You **MAY** search and read v1 code to understand existing behavior
- You **MAY** use shared resources (`prisma/`, `migrations/`, `ref/`)

## When Replicating v1 Functionality

1. Search/read the relevant v1 code to understand the behavior
2. Document the behavior you need to replicate
3. Implement fresh code in v2
4. **NEVER** modify v1 files

## Development Commands

```bash
# From v2/ directory:
make dev          # Start both API (:8080) and web (:5173) servers
make dev-api      # Start only the API server
make dev-web      # Start only the web dev server
make build        # Build all components
make test         # Run all tests
make download-db  # Download production database for local dev
```

## Database Access

- Local dev: Uses `DATABASE_PATH` env var (typically `../prisma/gallformers.sqlite`)
- Production: Database on Fly.io volume at `/data/gallformers.sqlite`
- Run `make download-db` to get a fresh copy of production data

## Project Structure

```
v2/
├── CLAUDE.md         # This file - agent instructions
├── Makefile          # Development coordination
├── fly.toml          # Fly.io deployment config
├── Dockerfile        # Production container build
├── .env.example      # Required environment variables template
│
├── api/              # Go API server
│   ├── cmd/server/   # Main entry point
│   ├── internal/     # Private packages
│   ├── go.mod        # Go dependencies
│   └── Makefile      # API-specific commands
│
└── web/              # Svelte frontend
    ├── src/          # Source code
    ├── static/       # Static assets
    ├── package.json  # Node dependencies
    └── Makefile      # Web-specific commands
```

## Deployment

V2 deploys to Fly.io automatically via CI/CD when changes are pushed to `v2/` on main.

Manual deployment: `fly deploy` from `v2/` directory.

## API Development

### sqlc Workflow

Database queries use [sqlc](https://sqlc.dev/) for type-safe code generation:

1. Add/modify queries in `api/internal/db/queries/*.sql`
2. Run `make generate` from `v2/api/` (or `~/go/bin/sqlc generate`)
3. Generated code appears in `api/internal/db/generated/`

### Handler Patterns

Domain handlers follow a consistent pattern:

```go
type FooHandler struct {
    queries *db.Queries
}

func NewFooHandler(q *db.Queries) *FooHandler {
    return &FooHandler{queries: q}
}

func (h *FooHandler) RegisterRoutes(r chi.Router) {
    r.Route("/foos", func(r chi.Router) {
        r.Get("/", h.List)
        r.Get("/{id}", h.GetByID)
        r.With(mw.RequireAuth).Post("/", h.Create)
        r.With(mw.RequireAuth).Put("/{id}", h.Update)
        r.With(mw.RequireAuth).Delete("/{id}", h.Delete)
    })
}
```

Use `middleware.RespondJSON()` and `middleware.RespondError()` for responses.

## Styling (Tailwind v4)

V2 uses **Tailwind v4** which reads configuration from CSS, not `tailwind.config.js`.

### Custom Colors

Colors are defined in `web/src/app.css` via `@theme`. Use these classes:

| Class | Hex | Use for |
|-------|-----|---------|
| `text-gf-maroon` / `bg-gf-maroon` | #661419 | Headings, links, primary accent |
| `text-gf-sky-blue` / `bg-gf-sky-blue` | #c1e0f3 | Header background |
| `text-gf-autumn` / `bg-gf-autumn` | #bc6428 | Subtitles, secondary text |
| `bg-cadet-blue` | #96adc8 | Table headers |
| `bg-canary` | #f8f991 | Selected/highlighted rows |

### Page Styling Patterns

**Page titles:**
```svelte
<h1 class="text-2xl font-bold text-gf-maroon mb-4">Page Title</h1>
```

**Links:**
```svelte
<a href="..." class="text-gf-maroon hover:underline">Link text</a>
```

**Cards (v1-style):**
```svelte
<div class="bg-white rounded border border-gray-200 shadow-sm">
  <div class="px-4 py-3 border-b border-gray-200">
    <h2 class="text-xl font-semibold text-gf-maroon">Card Title</h2>
  </div>
  <div class="p-4">
    Content here
  </div>
</div>
```

**Page container:**
```svelte
<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <!-- page content -->
</div>
```

### Global Styles

These apply automatically to all pages via `+layout.svelte`:
- **Font**: League Spartan (falls back to system fonts)
- **Header**: Sky blue background, maroon navigation (in `Layout.svelte`)
- **Footer**: Light gray background, maroon links (in `Layout.svelte`)

### Adding New Colors

To add colors, edit `web/src/app.css`:

```css
@theme {
  --color-my-new-color: #hexvalue;
}
```

Then use as `text-my-new-color` or `bg-my-new-color`.

## Important Notes

- The v1 site (Next.js on Digital Ocean) continues running until cutover
- All v2 work must stay within the `v2/` directory
- Use the beads workflow for issue tracking (`bd` commands)
