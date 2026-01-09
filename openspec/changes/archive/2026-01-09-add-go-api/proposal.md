# Change: Add Go API Server

## Prerequisites

- **define-v2-foundation**: V2 directory structure, Fly.io deployment, and CLAUDE.md isolation rules must be in place

## Why

The current Next.js API routes suffer from architectural friction:
- 15+ raw SQL workarounds bypassing Prisma's limitations
- fp-ts type gymnastics that obscure simple operations
- Inconsistent error handling across endpoints
- No OpenAPI documentation (clients must read source code)
- Deployment pain (manual Docker builds, scp to DO)

The Go API establishes the foundation for all v2 backend work, providing:
- Type-safe SQL via sqlc (no ORM, no workarounds)
- OpenAPI-first design with generated documentation
- Simpler concurrency model for future optimizations
- Single binary deployment to Fly.io

## What Changes

### New Capability: Go API Server

A complete REST API replacing all 41 Next.js API endpoints, organized by domain:

| Domain | Endpoints | Description |
|--------|-----------|-------------|
| **Auth** | 4 | Login callback, refresh, logout, me |
| **Gall** | 5 | List/search, get, create, update, delete |
| **Species** | 2 | List/search, get (read-only, managed via gall/host) |
| **Host** | 5 | List/search, get, create, update, delete |
| **Taxonomy** | 10 | Family/genus/section hierarchy CRUD |
| **Source** | 6 | List/search, get, by-title, create, update, delete |
| **Glossary** | 6 | List/search, get, by-word, create, update, delete |
| **Place** | 6 | List/search, get, by-name, create, update, delete |
| **GallHost** | 3 | List, create, delete relationship |
| **SpeciesSource** | 4 | List, get, upsert, delete relationship |
| **FilterField** | 6 | List types, list values, get, create, update, delete |
| **Search** | 1 | Global search across domains |
| **Health** | 1 | Health check for Fly.io |

### Technical Approach

- **Router**: chi (lightweight, stdlib-compatible)
- **Database**: sqlc for type-safe SQL queries against SQLite
- **Auth**: Auth0 JWT validation middleware
- **Docs**: OpenAPI 3.0 spec with Swagger UI at `/api/docs`
- **Logging**: slog with structured JSON output
- **API Versioning**: `/api/v2/` prefix (v1 reserved for legacy if needed)

### What's NOT in This Proposal

- **Image endpoints**: Covered by `add-image-processing`
- **Article endpoints**: Covered by `add-articles-system`
- **Frontend**: Covered by `add-svelte-admin` and `add-svelte-public`

## Impact

- **New specs**: `go-api` capability
- **Affected proposals**:
  - `add-image-processing` (depends on this for core API patterns)
  - `add-articles-system` (depends on this for core API patterns)
  - `add-svelte-admin` (consumes these endpoints)
  - `add-svelte-public` (consumes these endpoints)
- **Affected code**: All new code in `v2/api/`
- **Risk**: Low - parallel implementation, v1 unchanged

## Dependencies

- **Requires**: `define-v2-foundation` (v2 directory structure, Fly.io setup)
- **Blocks**: `add-image-processing`, `add-articles-system` (they need API patterns established)

## Success Criteria

1. `make dev` from `v2/` starts API server on :8080
2. `curl localhost:8080/api/v2/health` returns 200 with JSON status
3. `curl localhost:8080/api/docs` serves Swagger UI with all endpoints documented
4. All 41 endpoints from v1 have equivalent v2 endpoints passing integration tests
5. Authenticated endpoints reject requests without valid Auth0 JWT
6. `fly deploy` from `v2/` deploys working API to Fly.io
7. sqlc generates type-safe Go code from SQL queries
