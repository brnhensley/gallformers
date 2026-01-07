# Design: Gallformers V2 Architecture

## Context

The gallformers codebase has been in production since ~2020, serving the gall identification community. The [January 2026 technical audit](../../../TECHNICAL_AUDIT_2026.md) revealed:

- **Critical security issues**: Auth bypass, SQL injection, credentials in git
- **Architectural debt**: Prisma workarounds, N+1 queries, 654-line admin forms
- **Blocked improvements**: Admin simplification and deployment modernization fight the current architecture

The audit recommended parallel rebuild rather than incremental fixes based on:
- Scope of planned features
- Fundamental issues with Prisma/TypeScript complexity
- Proven success with Svelte + Go + SQLite on other projects

## Goals

- Preserve all current functionality
- Preserve all data (zero data loss)
- Preserve public URLs (SEO, external links)
- Simplify admin page implementation by 50%+
- Reduce deployment complexity (single binary + static files)
- Fix all critical security issues

## Non-Goals

- Adding new features during migration (preserve current behavior)
- Changing the database schema (preserve SQLite structure)
- Changing external service integrations (keep S3, Auth0, etc.)
- Mobile app (web-only)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Svelte SPA                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Public Site │  │ Admin Pages │  │ Static Assets       │  │
│  │ (SPA)       │  │ (SPA)       │  │ (CSS, Images, etc)  │  │
│  └──────┬──────┘  └──────┬──────┘  └─────────────────────┘  │
└─────────┼────────────────┼──────────────────────────────────┘
          │                │
          ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│                      Go API Server                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ REST API    │  │ Auth        │  │ Data Layer          │  │
│  │ (OpenAPI)   │  │ (Auth0 JWT) │  │ (sqlc)              │  │
│  └──────┬──────┘  └─────────────┘  └──────────┬──────────┘  │
└─────────┼─────────────────────────────────────┼─────────────┘
          │                                     │
          ▼                                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      SQLite Database                        │
│        (Same schema, same data, proven structure)           │
└─────────────────────────────────────────────────────────────┘
```

## Decisions

### Decision 1: Go for API Server

**Choice**: Go with standard library + chi router + sqlc

**Alternatives considered**:
- **Rust**: Higher learning curve, overkill for this use case
- **Node.js**: Same ecosystem issues we're escaping
- **Python/FastAPI**: Good option but Go has better deployment story (single binary)

**Rationale**:
- Single binary deployment
- Excellent SQLite support
- sqlc generates type-safe queries from SQL (no ORM complexity)
- Strong concurrency model for future scaling
- Proven on similar projects

### Decision 2: Svelte for Frontend

**Choice**: SvelteKit as SPA

**Alternatives considered**:
- **React**: Same complexity issues, already know its pain points
- **Vue**: Viable but Svelte has simpler reactivity model
- **HTMX + Go templates**: Simpler but limits interactivity

**Rationale**:
- Two-way binding eliminates form library complexity
- Compiled output is small and fast
- SPA provides smooth navigation and editing experience
- No SSG build complexity or stale static files

### Decision 3: Keep SQLite Schema

**Choice**: Same database schema, no changes

**Rationale**:
- Schema is well-designed and normalized
- Data is the asset, not the code
- Simplifies migration (same structure = simpler data copy)

### Decision 4: sqlc Instead of ORM

**Choice**: sqlc for Go database access

**Alternatives considered**:
- **GORM**: Repeats Prisma's problems (ORM complexity, magic)
- **Raw database/sql**: Type-unsafe, verbose
- **ent**: Facebook's ORM, heavy for this use case

**Rationale**:
- Write SQL directly (no ORM abstraction layer)
- sqlc generates type-safe Go code from SQL
- No N+1 surprises, full control over queries
- SQL is the source of truth

### Decision 5: Auth0 JWT Validation

**Choice**: Keep Auth0, validate JWTs in Go middleware

**Rationale**:
- Already have Auth0 configured
- Don't change auth during migration
- Go JWT validation is straightforward
- Consider alternatives post-migration if needed

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Extended parallel development | Phase 0 security fixes apply immediately to current site |
| Data sync during transition | Read from production SQLite, atomic cutover |
| URL breakage (SEO) | Careful routing to preserve all public URLs |
| Missing functionality | Feature parity checklist before cutover |
| Learning curve (Go, Svelte) | Start with simple endpoints/pages, iterate |

## Migration Plan

### Phase 0: Security Fixes (Current Site)

Apply immediately regardless of rewrite:
1. Fix auth bypass (`return` after `res.status(401).end()`)
2. Parameterize all SQL queries
3. Rotate credentials, remove from git

### Phase 1: Go API Server

1. Set up Go project structure
2. Implement sqlc schemas matching current Prisma schema
3. Build read-only endpoints first (species, galls, hosts, taxonomy)
4. Add authentication middleware
5. Build mutation endpoints
6. OpenAPI documentation

### Phase 2: Svelte Admin

1. Set up SvelteKit project
2. Build authentication flow
3. Rebuild gall admin page (worst pain point)
4. Rebuild host admin page
5. Rebuild taxonomy admin
6. Rebuild remaining admin pages
7. Feature parity testing

### Phase 3: Svelte Public Site

1. Species/gall/host pages (SPA routes)
2. Search functionality
3. Reference article rendering (see deferred proposal)
4. Image gallery handling (see deferred proposal)

### Phase 4: Cutover

1. Final data sync
2. DNS switch
3. Monitoring and verification
4. Archive old codebase

## Open Questions

1. ~~**Image processing**: Keep Sharp/Jimp in separate service or use Go image libraries?~~ **DEFERRED**: Separate proposal (follow oaks pattern)
2. ~~**Search**: Keep simple SQL search or add full-text search (SQLite FTS5)?~~ **DEFERRED**: To `add-go-api` proposal
3. **Caching**: Add Redis/memcached or rely on SQLite query cache?
4. ~~**Hosting**: Stay on DO Droplet or move to fly.io / railway?~~ **RESOLVED**: Fly.io (see `define-v2-foundation`)
