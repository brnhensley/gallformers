# Change: Rewrite Gallformers with Svelte + Go

## Why

The [January 2026 technical audit](../../../TECHNICAL_AUDIT_2026.md) identified fundamental architectural issues that make the current Next.js/Prisma/TypeScript stack unsuitable as a foundation for continued development. The complexity of Prisma workarounds, fp-ts type gymnastics, and 654-line admin forms creates friction that would compound with new feature development.

Additionally, **critical security issues** (auth bypass, SQL injection, credentials in git) must be addressed regardless of the rewrite decision.

## What Changes

### Umbrella Scope

This is a **high-level umbrella proposal**. Each phase will have its own detailed sub-proposal:

| Phase | Description | Sub-Proposal |
|-------|-------------|--------------|
| 0 | Critical security fixes | `fix-security-critical` (archived) |
| 0.5 | Technical foundation | `define-v2-foundation` |
| 1 | Go API server | `add-go-api` (archived) |
| 2 | Svelte common components | `add-svelte-common` |
| 3 | Svelte public site | `add-svelte-public` |
| 4 | Svelte admin interface | `add-svelte-admin` |
| 5 | Cutover and deprecation | `cutover-v2` |

### What We Keep

- **Database schema** - Well-designed, normalized, captures the domain correctly
- **SQLite database** - Same file, same data
- **Data** - Gall/host/taxonomy records (the real asset)
- **Domain knowledge** - Business logic documents the domain
- **Reference articles** - Markdown files are portable
- **Image assets** - S3 storage is independent
- **External services** - Auth0, S3

### What We Replace

| Current | New | Rationale |
|---------|-----|-----------|
| Prisma ORM | Raw SQL / sqlc | Eliminates 15+ raw SQL workaround locations |
| TypeScript + fp-ts | Go | Simpler type system, better concurrency |
| Next.js SSR | Svelte SPA | Eliminates hydration complexity |
| React Hook Form | Svelte two-way binding | Cuts form code by 50%+ |
| Monolith | Separate API + frontend | Independent deployment, scaling |

### **BREAKING** Changes

- All API endpoints will change (new REST API design with OpenAPI docs)
- Admin UI completely rebuilt (same functionality, different implementation)
- Public site URLs preserved via careful routing in new stack

## Impact

- **Affected specs**: All current capabilities (this proposal establishes the new platform spec)
- **Affected code**: Entire codebase (parallel rebuild, not in-place modification)
- **Timeline**: Parallel development; old site remains live until cutover
- **Risk mitigation**: Phase 0 security fixes apply to current site immediately

## Success Criteria

1. All current functionality available in new stack
2. Zero data loss during migration
3. Public URLs preserved (no broken links)
4. Critical security issues resolved in Phase 0
5. Admin page complexity reduced by 50%+ (LOC metric)
6. Deployment reduced to single binary + static files

## Dependencies

- Phase 1 (Go API) provides endpoints needed by Phases 3-4, but some frontend scaffolding can begin in parallel
- Phase 2 (Svelte Common) provides shared components used by both public and admin UIs
- Phase 3 (Svelte Public) and Phase 4 (Svelte Admin) can overlap where practical
- Phase 0 (Security) is independent and should happen immediately

## Open Questions

1. **Auth strategy**: Continue with Auth0 or switch to simpler solution?
2. ~~**API versioning**: REST with OpenAPI or consider GraphQL?~~ **RESOLVED**: REST with OpenAPI, `/v2/` prefix versioning
3. ~~**Hosting**: Stay on DO Droplet or move to cheaper/simpler option?~~ **RESOLVED**: Fly.io for v2 (see `define-v2-foundation`)
4. **Image CDN**: Keep S3 direct or add CloudFront/CDN layer? (deferred to post-cutover)

## Deferred to Sub-Proposals

- **Image processing**: Separate proposal to follow oaks pattern
- **Reference article rendering**: Separate proposal for markdown/glossary handling
- **Search implementation**: Deferred to `add-go-api` (SQL LIKE vs FTS5)
- **Deployment architecture**: How Go API + Svelte are packaged (see `gallformers-v88`)
