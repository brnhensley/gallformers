# Design: V2 Technical Foundation

## Context

Gallformers v2 is a parallel rebuild using Go + Svelte + SQLite. The current site (Next.js/Prisma) must remain live until cutover. This document analyzes options for repository structure, hosting, deployment, and development workflow.

### Current State (Corrected)

| Aspect | Current Setup |
|--------|---------------|
| Repository | Single repo (`jeffdc/gallformers`) |
| Deployment | **Manual pain**: build locally, scp tarball to DO, ssh and reload |
| Hosting | Digital Ocean Droplet (~$25/month bare Linux) |
| Infrastructure | **Manual**: nginx, Let's Encrypt certs, reverse proxy, secrets |
| Database | SQLite on mounted volume (`/mnt/gallformers_data/`) |
| Backups | **None automated** (no Litestream despite earlier assumptions) |
| CI/CD | None (GitHub Actions for tests only) |

### Reference: oaks Project

The [oaks project](https://github.com/jeffdc/oaks) demonstrates the target architecture:
- Go API (`api/`) deployed to Fly.io
- Svelte web (`web/`) with local dev mode
- Top-level Makefile for coordinated development
- Comprehensive CLAUDE.md for agent isolation
- Working `fly.toml` configuration

---

## Decision 1: Repository Structure

### Recommendation: **Same Repository with Strict Isolation**

```
gallformers/
├── v2/                   # NEW: All v2 code lives here
│   ├── CLAUDE.md         # V2-specific agent instructions
│   ├── Makefile          # Local dev coordination
│   ├── api/              # Go API server
│   │   ├── cmd/server/
│   │   ├── internal/
│   │   ├── go.mod
│   │   └── Makefile
│   ├── web/              # Svelte frontend
│   │   ├── src/
│   │   ├── package.json
│   │   └── Makefile
│   └── fly.toml          # V2 deployment config
│
├── pages/                # EXISTING: v1 Next.js (DO NOT TOUCH from v2 work)
├── libs/                 # EXISTING: v1 TypeScript (DO NOT TOUCH from v2 work)
├── components/           # EXISTING: v1 React (DO NOT TOUCH from v2 work)
├── prisma/               # SHARED: Database schema + SQLite
├── ref/                  # SHARED: Reference articles
├── migrations/           # SHARED: SQL migrations
└── ...
```

**Key isolation rules:**

1. **All v2 code under `v2/` directory** - never scatter across root
2. **`v2/CLAUDE.md`** - agent instructions specific to v2 work
3. **No code sharing** unless VERY intentional (e.g., migrations)
4. **Read v1 for understanding**, but don't modify or depend on it
5. **Separate `fly.toml`** in `v2/` for v2 deployment

**Why `v2/` subdirectory instead of `api/` + `web/` at root:**
- Cleaner isolation from v1 code
- Single directory to focus agent context
- Easy to set working directory to `v2/` for development
- Clear cutover: delete everything outside `v2/`, move `v2/*` to root

### Agent Context Management

The `v2/CLAUDE.md` file MUST include:

```markdown
# V2 Development - Agent Instructions

## Scope
You are working on the gallformers v2 rewrite. All v2 code lives in this directory.

## Isolation Rules
- DO NOT modify code outside of `v2/`
- DO NOT add dependencies on v1 code (`pages/`, `libs/`, `components/`)
- You MAY search and read v1 code to understand existing behavior
- You MAY use shared resources (`prisma/`, `migrations/`, `ref/`)

## When replicating v1 functionality:
1. Search/read the relevant v1 code
2. Document the behavior you need to replicate
3. Implement fresh code in v2
4. NEVER modify v1 files
```

---

## Decision 2: Git Branching Strategy

### Recommendation: **Trunk-Based (v2 in `v2/` subdirectory)**

**Rationale:**
- Works with beads workflow (daemon watches main)
- No long-running branch maintenance
- v2 code in `v2/` directory won't interfere with v1
- Current v1 deployment ignores unknown directories

**Workflow:**
```bash
# Normal development on main (or short-lived branches)
git checkout -b add-go-api origin/main
# ... work in v2/ directory ...
git add v2/
git commit -m "add: Go API foundation"
# Merge to main when ready
```

---

## Decision 3: Hosting Platform

### Recommendation: **Fly.io for v2 (Keep DO for v1 until cutover)**

**Rationale:**
- You have Fly.io experience (oaks project proves it works)
- `fly.toml` already exists in gallformers (partially configured)
- Free/cheap tier during development, scale at cutover
- Eliminates manual infrastructure pain:
  - No nginx config
  - No cert management
  - No ssh + scp deployments
  - No manual Docker orchestration

**Migration path:**
1. **During v2 development**: Run v2 on Fly.io (minimal resources, low cost)
2. **At cutover**: Scale up Fly.io, point DNS, deprecate DO Droplet
3. **Post-cutover**: Cancel DO Droplet (~$25/month savings)

**Fly.io setup for v2:**
- **App name**: `gallformers` (destroy existing incomplete app if present)
- **Architecture**: Single Fly.io app - Go binary serves API routes AND static Svelte files
- **Why single app**: Simpler deployment, no CORS, no multiple apps to coordinate

```
v2/
├── fly.toml              # Single app config
├── Dockerfile            # Builds Go binary with embedded static files
├── api/
│   └── ...               # Go source
└── web/
    └── ...               # Svelte source (built, then embedded in Go binary)
```

**Database considerations:**
- SQLite on Fly.io volume (simple, proven pattern from oaks)
- Volume mounted at `/data/gallformers.sqlite`

---

## Decision 4: Deployment Pipeline

### Recommendation: **Fly.io Deploy (`fly deploy`)**

**Current pain points eliminated:**
| Pain Point | Fly.io Solution |
|------------|-----------------|
| Build locally, scp tarball | `fly deploy` builds remotely |
| SSH to server, manually reload | Automatic deployment |
| Manage nginx config | Built-in proxy |
| Let's Encrypt cert renewal | Automatic SSL |
| Manual rollback | `fly releases` + `fly deploy --image` |

**Development workflow (from oaks):**
```bash
# Local development
cd v2
make dev          # Starts API + web locally

# Deploy to Fly.io
fly deploy        # From v2/ directory
```

**CI/CD (required):**
```yaml
# .github/workflows/deploy-v2.yml
on:
  push:
    branches: [main]
    paths: ['v2/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - run: cd v2 && flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

CI/CD is essential to avoid falling back into manual deployment patterns.

---

## Decision 5: Local Development

### Recommendation: **Makefile-coordinated dev (oaks pattern)**

```makefile
# v2/Makefile
.PHONY: dev dev-api dev-web build test clean

# Start both API and web dev servers
dev:
	@echo "Starting API server on http://localhost:8080"
	@echo "Starting web dev server on http://localhost:5173"
	@trap 'kill 0' INT; \
		(cd api && $(MAKE) run) & \
		(cd web && npm run dev) & \
		wait

dev-api:
	cd api && $(MAKE) run

dev-web:
	cd web && npm run dev

build:
	cd api && $(MAKE) build
	cd web && npm run build

test:
	cd api && $(MAKE) test
	cd web && npm test

# Download production database for local dev
# Requires PROD_HOST env var (e.g., user@server)
download-db:
	@echo "Downloading database from production..."
	scp $${PROD_HOST}:/mnt/gallformers_data/prisma/gallformers.sqlite ../prisma/
```

---

## Decision 6: Database Access During Development

### Recommendation: **Development Copy with Environment Variable**

**Process:**
1. Copy production SQLite to local: `make download-db`
2. Work against local copy
3. v2 API reads from path specified by `DATABASE_PATH` env var
4. Production stays untouched during development

**Environment configuration:**
- Local dev: `DATABASE_PATH=../prisma/gallformers.sqlite` (in `.env` file)
- Fly.io: `DATABASE_PATH=/data/gallformers.sqlite` (via `fly secrets`)

**Post-cutover:**
- Database lives on Fly.io volume at `/data/gallformers.sqlite`
- Use `fly ssh sftp get` pattern from oaks for backups

---

## Decision 7: Placeholder App Definition

### What the placeholder apps must do:

**Go API placeholder:**
- `GET /health` returns `{"status": "ok"}` with 200 status
- Serves static files from embedded filesystem at all other routes
- Reads `DATABASE_PATH` env var (but doesn't require DB connection for health check)

**Svelte placeholder:**
- Index page displays "Gallformers v2 - Coming Soon"
- Builds to static files that Go binary can serve

**Why this definition:**
- Health endpoint proves deployment and routing work
- Static page proves Svelte build pipeline works
- No database required for initial foundation verification
- Simple enough to implement quickly, complete enough to validate infrastructure

---

## Summary of Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Repository structure | Same repo, `v2/` subdirectory | Strict isolation, clear cutover path |
| Agent isolation | `v2/CLAUDE.md` with explicit rules | MAY read v1, MUST NOT modify |
| Git branching | Trunk-based | Works with beads, no long branches |
| Hosting platform | Fly.io (app name: `gallformers`) | Eliminates manual infrastructure pain |
| Deployment architecture | Single app (Go serves static files) | Simpler, no CORS, one deployment |
| Deployment pipeline | `fly deploy` + CI/CD | Simple, automatic, rollback-capable |
| Local development | Makefile-coordinated | Proven pattern from oaks |
| Database access | Dev copy via `DATABASE_PATH` env var | Safe, configurable for local/prod |
| Placeholder apps | Health endpoint + static page | Validates infrastructure without DB |

---

## Project Structure After Setup

```
gallformers/
├── v2/                          # ALL V2 CODE HERE
│   ├── CLAUDE.md                # Agent isolation rules
│   ├── Makefile                 # Dev coordination
│   ├── fly.toml                 # Fly.io config
│   ├── Dockerfile               # Single container (Go + static files)
│   ├── .env.example             # Required env vars template
│   │
│   ├── api/                     # Go API server
│   │   ├── cmd/
│   │   │   └── server/
│   │   │       └── main.go
│   │   ├── internal/
│   │   │   ├── handlers/
│   │   │   └── middleware/
│   │   ├── go.mod
│   │   └── Makefile
│   │
│   └── web/                     # Svelte frontend
│       ├── src/
│       │   ├── routes/
│       │   ├── lib/
│       │   └── app.html
│       ├── static/
│       ├── package.json
│       ├── svelte.config.js
│       └── Makefile
│
├── pages/                       # v1 (until cutover)
├── libs/                        # v1 (until cutover)
├── components/                  # v1 (until cutover)
├── prisma/                      # SHARED
│   ├── schema.prisma
│   └── gallformers.sqlite
├── ref/                         # SHARED
├── migrations/                  # SHARED (v1 schema frozen)
├── Dockerfile                   # v1 DO deployment
└── ...
# Note: Root fly.toml and Dockerfile.fly will be REMOVED (incomplete v1 Fly attempt)
```

---

## Migration Path

### Phase 1: Foundation (This Proposal)
1. Create `v2/` directory structure
2. Create `v2/CLAUDE.md` with isolation rules
3. Create `v2/Makefile` for local dev
4. Create `v2/fly.toml` for Fly.io deployment
5. Scaffold `v2/api/` and `v2/web/` with minimal placeholders
6. Verify local dev works (`make dev`)
7. Verify Fly.io deploy works (placeholder app)

### Phase 2-4: Implementation
- Follow `add-go-api`, `add-svelte-admin`, `add-svelte-public` proposals
- All work happens in `v2/` directory
- v1 continues running on DO Droplet

### Phase 5: Cutover
1. Scale up Fly.io resources
2. Final database sync to Fly.io volume
3. DNS switch to Fly.io
4. Verify everything works
5. Move `v2/*` contents to root (optional, can keep structure)
6. Delete v1 code
7. Cancel DO Droplet

---

## Open Questions Resolved

From `rewrite-gallformers-v2` proposal:

| Question | Resolution |
|----------|------------|
| **Hosting** | **Fly.io for v2, DO for v1 until cutover** |
| **Image CDN** | **Keep S3 direct (defer CDN to post-cutover)** |

Note: Auth strategy and API versioning decisions are deferred to `add-go-api` proposal.

---

## Risks

| Risk | Mitigation |
|------|------------|
| Agent searches v1 code, gets confused | `v2/CLAUDE.md` with explicit isolation rules |
| Fly.io learning curve | Working [oaks project](https://github.com/jeffdc/oaks) as reference |
| Database sync issues | Start with dev copy, simple volume mount |
| Trunk-based breaks v1 | v2 code isolated in `v2/` directory |
