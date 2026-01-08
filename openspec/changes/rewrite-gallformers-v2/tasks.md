# Tasks: Gallformers V2 Rewrite

This is an **umbrella proposal**. Most tasks are creating and completing sub-proposals.

## 0. Pre-Work

- [x] 0.1 Review and approve this umbrella proposal
- [x] 0.2 Create `fix-security-critical` sub-proposal (archived)
- [x] 0.3 Create `define-v2-foundation` sub-proposal
- [x] 0.4 Create `add-go-api` sub-proposal
- [x] 0.5 Create `add-svelte-admin` sub-proposal
- [x] 0.6 Create `add-svelte-public` sub-proposal
- [x] 0.7 Create `cutover-v2` sub-proposal
- [x] 0.8 Create `add-articles-system` sub-proposal
- [x] 0.9 Create `add-svelete-common` sub-proposal

## 1. Phase 0: Security Fixes (Immediate) - COMPLETE

- [x] 1.1 Complete `fix-security-critical` proposal implementation
  - Fix auth bypass in `libs/api/apipage.ts`
  - Parameterize SQL in `gallhost.ts`, `species.ts`, `taxonomy.ts`, `place.ts`, `source.ts`
  - Rotate credentials, remove `.env.local` from git history
- [x] 1.2 Deploy security fixes to production

## 1.5. Phase 0.5: Technical Foundation

- [x] 1.5.1 Complete `define-v2-foundation` proposal implementation
  - Create `v2/` directory structure with isolation
  - Create `v2/CLAUDE.md` with agent rules
  - Setup Fly.io deployment + CI/CD
  - Scaffold Go API and Svelte web placeholders
- [x] 1.5.2 Verify local dev and Fly.io deployment work

## 2. Phase 1: Go API Server

- [ ] 2.1 Complete `add-go-api` proposal implementation
  - Set up Go project with chi router
  - Implement sqlc schemas
  - Build read endpoints (species, galls, hosts, taxonomy, search)
  - Build auth middleware (Auth0 JWT)
  - Build mutation endpoints
  - Generate OpenAPI documentation
- [ ] 2.2 API parity testing against current endpoints

## 3. Phase 2: Svelte Admin

- [ ] 3.1 Complete `add-svelte-admin` proposal implementation
  - Set up SvelteKit project
  - Build auth flow
  - Rebuild gall admin page
  - Rebuild host admin page
  - Rebuild taxonomy admin
  - Rebuild all other admin pages
- [ ] 3.2 Admin feature parity testing

## 4. Phase 3: Svelte Public Site

- [ ] 4.1 Complete `add-svelte-public` proposal implementation
  - Species/gall/host pages (SPA routes)
  - Search functionality
  - Reference article rendering (see deferred proposal)
  - Image gallery (see deferred proposal)
- [ ] 4.2 Public site feature parity testing
- [ ] 4.3 URL preservation verification

## 5. Phase 4: Cutover

- [ ] 5.1 Complete `cutover-v2` proposal implementation
  - Final data sync procedure
  - DNS switch plan
  - Rollback procedure
- [ ] 5.2 Execute cutover
- [ ] 5.3 Post-cutover monitoring
- [ ] 5.4 Archive old codebase

## 6. Completion

- [ ] 6.1 Archive all sub-proposals
- [ ] 6.2 Archive this umbrella proposal
- [ ] 6.3 Update `openspec/project.md` with new tech stack
