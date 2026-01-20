# Gallformers Technical Audit Report

**Date:** January 2026
**Purpose:** Due diligence assessment prior to major feature work

---

## Executive Summary

The gallformers codebase is a functioning production system with solid domain modeling, but it has accumulated significant technical debt and architectural complexity that makes it **unsuitable as a foundation for major new features**. The planned features (audit trails, undo behavior, admin simplification, image rework, maps, geographic expansion) would require fighting against the current architecture rather than building on it.

**Recommendation:** Parallel rebuild using a simpler stack (Svelte + Go + SQLite), preserving the database schema and migrating data.

---

## Part 1: Current State Assessment

### What Works Well

| Area | Assessment |
|------|------------|
| **Domain Model** | Schema is well-designed, properly normalized, captures the domain correctly |
| **Data Quality** | The actual gall/host/taxonomy data is the real asset |
| **Type Coverage** | 99%+ TypeScript coverage prevents runtime type errors |
| **FP Patterns** | Consistent TaskEither usage provides predictable error handling |
| **API Abstraction** | The `apiUpsertEndpoint`/`apiIdEndpoint` pattern is clean |

### Critical Issues

| Issue | Severity | Impact |
|-------|----------|--------|
| **Auth bypass bug** | CRITICAL | All "protected" endpoints are unprotected due to missing `return` after `res.status(401).end()` in `libs/api/apipage.ts` |
| **SQL injection** | CRITICAL | 6+ files with string interpolation in raw SQL (`gallhost.ts`, `species.ts`, `taxonomy.ts`, `place.ts`, `source.ts`) |
| **N+1 queries** | HIGH | `getGalls`/`getHosts` trigger 1000+ queries for 1000 records (taxonomy lookup per species) |
| **Missing DB indexes** | HIGH | No indexes on foreign key columns, causing table scans |
| **~8% test coverage** | HIGH | Only 9 test files; 0 API tests, 0 DB tests, 2/27 components tested |
| **Manual deployment** | MEDIUM | SSH/SCP with site downtime, no CI/CD automation |

### Architectural Problems

#### Prisma

The ORM has created more problems than it solved:
- 15+ locations with raw SQL workarounds
- Cannot do cascade deletes (manual cleanup code throughout)
- Disconnect/connect operations fail in single transactions
- Generated types are complex and leak into business logic
- N+1 problems require manual batching the ORM should handle

#### TypeScript + fp-ts

The 99% coverage is both shield and burden:
- ~700 lines of type definitions in `apitypes.ts` alone
- Type gymnastics in `libs/db/utils.ts` with `as unknown as T` casts
- LLMs struggle with pipe/TaskEither patterns
- Strict typing creates friction for simple changes
- `strictFunctionTypes: false` required for fp-ts compatibility

#### Next.js SSR

Adds complexity without proportional benefit:
- `getServerSideProps` boilerplate on every admin page
- Hydration complexity
- Blurs the line between client and server code
- Makes deployment heavier than necessary

#### Monolithic Architecture

Single server handles everything:
- Static page serving
- API endpoints
- Image processing (Sharp/Jimp)
- Authentication
- Database access

This makes scaling, deployment, and failure isolation difficult.

---

## Part 2: Detailed Findings by Area

### Database Layer

**Schema Design: Good**
- Well-normalized structure with appropriate junction tables
- Self-referential taxonomy hierarchy is clean
- Proper foreign key relationships

**Data Access: Problematic**
- N+1 queries in `getGalls()` (gall.ts:259) and `getHosts()` (host.ts:237)
- Missing indexes on all FK columns will cause table scans
- Extensive raw SQL bypasses Prisma type safety
- `globalSearch()` makes 5 sequential queries instead of parallel

**Migrations: Manual**
- No automated migration runner
- Raw SQL with manual up/down sections
- Temporary table workarounds for SQLite limitations

### Testing

| Category | Count | Tested | Coverage |
|----------|-------|--------|----------|
| Components | 27 | 2 | 7.4% |
| Pages | 37 | 1 | 2.7% |
| API Routes | 42 | 0 | 0% |
| Database Modules | 15 | 0 | 0% |
| Utility Modules | 10 | 8 | 80% |
| **Total** | **~131** | **~11** | **~8.4%** |

No E2E tests. No integration tests. Jest configured but underutilized.

### Dependencies

**Critical Issues:**
- `remove` package: v0.1.5 from 2016 (10 years old, unmaintained)
- AWS SDK S3: v3.948.0 (~15 months outdated)
- Test dependencies in production bundle (`jest-environment-jsdom`, `@testing-library/user-event`)

**Framework Versions (Current):**
- Next.js 14.2.33
- React 18.3.1
- TypeScript 5.9.3
- Prisma 6.19.1

### Security

**Authentication:**
- NextAuth + Auth0 delegation (good)
- But: auth guard bug means protection is ineffective
- Hardcoded admin list in `components/auth.tsx`
- Authorization only checked in UI, not API routes

**Injection Risks:**
- SQL injection via string interpolation in 6+ files
- XSS mitigated by DOMPurify usage

**Missing:**
- Security headers (CSP, X-Frame-Options, etc.)
- CSRF token validation
- Rate limiting
- API versioning

### Deployment

**Current Process:**
1. Local Docker build
2. SSH to server
3. SCP image transfer
4. Manual maintenance mode toggle
5. Manual database migration (if needed)
6. Server-side redeploy

**Issues:**
- No CI/CD automation
- No Docker health checks
- Node version mismatch (CI: v21, local: v20)
- No automated rollback
- Troubleshooting runbook incomplete

### Code Organization

**Large Files (candidates for splitting):**
- `libs/db/gall.ts`: 29KB
- `libs/db/taxonomy.ts`: 28KB
- `pages/admin/gall.tsx`: 654 lines
- `pages/admin/host.tsx`: 485 lines

**Good Abstractions:**
- `useAdmin` hook for admin page logic
- `useSpecies` hook for species/host shared logic
- `apiUpsertEndpoint` / `apiIdEndpoint` generic handlers

**Duplication:**
- FilterField adapters could use factory pattern
- Controller/Typeahead pattern repeated 40+ times in admin pages
- `toUpsertFields`/`updatedFormFields`/`createNew` trio repeated across admin pages

---

## Part 3: Feature Feasibility Analysis

| Planned Feature | Difficulty | Why |
|----------------|------------|-----|
| **Audit trails** | HARD | Requires schema changes, middleware changes, touching every mutation |
| **Undo/safe edits** | VERY HARD | Needs event sourcing; fp-ts patterns make state tracking complex |
| **Deployment improvements** | MEDIUM | Docker exists but Next.js + Prisma combo is heavy |
| **Geographic expansion** | MEDIUM | Mostly data work, but admin complexity makes it tedious |
| **Admin simplification** | VERY HARD | 654-line gall.tsx with entangled React Hook Form + Controller patterns |
| **Taxonomy maintenance** | HARD | taxonomy.ts is 28KB of complex mutations |
| **Maps rework** | MEDIUM | Depends on frontend framework choice |
| **Image rework** | HARD | Logic scattered across components, libs/images, libs/db/images, S3 |

---

## Part 4: Recommendation

### Rewrite with Simpler Stack

Given:
- Fundamental issues with Prisma/TypeScript complexity
- Scope of planned features
- Proven success with Svelte + Go + SQLite on other projects
- Tolerance for parallel development period

**Recommended Architecture:**

```
┌─────────────────┐     ┌─────────────────┐
│  Svelte SPA     │────▶│   Go API        │
│  (Static files) │     │   (REST/JSON)   │
└─────────────────┘     └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │    SQLite       │
                        │  (same schema)  │
                        └─────────────────┘
```

### What to Preserve

1. **Database schema** - Well-designed, keep it
2. **Data** - The real asset
3. **Domain knowledge** - Business logic documents how the domain works
4. **Reference articles** - Markdown files are portable
5. **Image assets** - S3 storage is independent

### What to Abandon

1. **Prisma** - Use raw SQL or lightweight query builder
2. **TypeScript/fp-ts** - Go's type system is simpler and sufficient
3. **Next.js SSR** - Svelte with static build
4. **React Hook Form** - Svelte two-way binding is simpler
5. **Monolith** - Separate API server from frontend

### New Stack Advantages

| Feature | How It Becomes Easy |
|---------|---------------------|
| Audit trails | Middleware on every handler, audit table populated automatically |
| Undo | Event sourcing: store mutations as events, replay to undo |
| Better deployment | Single Go binary + static files, deploy anywhere |
| Admin simplification | Svelte two-way binding eliminates 50%+ of form code |
| Geographic expansion | Clean API makes data management straightforward |
| Real API | Built from scratch with proper REST design and OpenAPI docs |
| Image rework | Go image processing in dedicated handlers |
| Maps | Modern JS map libraries integrate easily with Svelte |

### Migration Path

1. **Phase 0: Fix critical security issues** (do regardless of rewrite)
   - Add `return` after 401 responses
   - Parameterize SQL queries

2. **Phase 1: Build Go API**
   - Same SQLite database, new API layer
   - Implement audit table from day one
   - Build endpoints incrementally
   - Add OpenAPI documentation

3. **Phase 2: Build Svelte Admin**
   - Start with most painful pages (gall, host)
   - Simpler forms, same functionality
   - Point at Go API

4. **Phase 3: Build Svelte Public Site**
   - Static generation for public pages
   - Modern maps integration
   - New image handling

5. **Phase 4: Cutover**
   - DNS switch
   - Old site becomes archive

---

## Part 5: If Incremental Fix Instead

If rewrite isn't feasible, prioritize:

### Immediate (Security)
- [ ] Fix auth bypass: add `return` after `res.status(401).end()` in `libs/api/apipage.ts`
- [ ] Parameterize all SQL queries in `gallhost.ts`, `species.ts`, `taxonomy.ts`, `place.ts`, `source.ts`

### Before Major Changes (Testing)
- [ ] Add integration tests for gall/host/taxonomy CRUD
- [ ] Add API route tests for critical endpoints

### Performance
- [ ] Add indexes to FK columns in schema
- [ ] Fix N+1 queries in `getGalls()` and `getHosts()`

### Deployment
- [ ] Add health checks to Dockerfile
- [ ] Automate deployment via GitHub Actions

---

## Conclusion

The gallformers codebase shows careful thought about domain modeling, error handling, and type safety. But the technology choices (Prisma, heavy TypeScript, Next.js SSR) have created accidental complexity that now blocks progress.

The data and domain knowledge are the assets. The code is the liability.

**Rebuild around the assets.**
