# V2 Development - Agent Instructions

## Scope

You are working on the gallformers v2 rewrite. All v2 code lives in this directory (`v2/`).

The v2 stack is:
- **Go API** (`v2/api/`) - REST API server serving JSON endpoints and static files
- **Svelte Web** (`v2/web/`) - SvelteKit frontend (JavaScript, not TypeScript) compiled to static files
- **SQLite** - Database (shared with v1 during development)
- **Fly.io** - Production hosting

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

## Important Notes

- The v1 site (Next.js on Digital Ocean) continues running until cutover
- All v2 work must stay within the `v2/` directory
- Use the beads workflow for issue tracking (`bd` commands)
