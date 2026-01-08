# Change: Define V2 Technical Foundation

## Why

The `rewrite-gallformers-v2` umbrella proposal establishes **what** we're building (Go API + Svelte frontend) but not **where** or **how** we build it. Before starting Phase 1 (`add-go-api`), we need decisions on:

- **Repository strategy**: How do we isolate v2 code from v1?
- **Development workflow**: How do agents work without mixing v1/v2 context?
- **Deployment pipeline**: Eliminate manual DO pain (nginx, certs, scp, ssh)
- **Hosting**: Fly.io for v2 (proven with [oaks project](https://github.com/jeffdc/oaks))
- **Local development**: Makefile-coordinated ([oaks pattern](https://github.com/jeffdc/oaks))

These decisions affect every subsequent phase. Getting them wrong means rework across all sub-proposals.

## What Changes

This proposal delivers **documented decisions and scaffolding** that become prerequisites for:
- `add-go-api` (Phase 1)
- `add-svelte-admin` (Phase 2)
- `add-svelte-public` (Phase 3)
- `cutover-v2` (Phase 4)

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Repository structure | Same repo, `v2/` subdirectory | Strict isolation, clear cutover path |
| Agent isolation | `v2/CLAUDE.md` with explicit rules | Prevent context pollution |
| Git branching | Trunk-based | Works with beads, no long branches |
| Hosting platform | **Fly.io** | Eliminates manual DO infrastructure pain |
| Deployment pipeline | `fly deploy` + CI/CD | Automatic on push, no manual steps |
| Local development | Makefile-coordinated | Proven pattern from oaks |
| Database access | Development copy | Safe, simple |

### Deliverables

1. **design.md**: Full analysis with decisions
2. **`v2/` directory**: Scaffolded structure with CLAUDE.md, Makefile, fly.toml
3. **Placeholder apps**: Minimal Go API + Svelte web that build and deploy
4. **Updated umbrella**: Close open questions in `rewrite-gallformers-v2`

## Impact

- **Affected specs**: Creates new `v2-infrastructure` capability spec
- **Affected proposals**: `rewrite-gallformers-v2` (closes open questions), all Phase 1-4 sub-proposals
- **Risk**: Low (scaffolding only, no v1 changes)

## Dependencies

- Requires `rewrite-gallformers-v2` to be reviewed/approved as the high-level direction
- Blocks all Phase 1-4 implementation proposals

## Success Criteria

1. `v2/CLAUDE.md` exists with explicit agent isolation rules (DO NOT modify outside v2/, MAY search/read v1)
2. `make dev` from `v2/` starts both servers; `curl localhost:8080/health` and `curl localhost:5173` both return 200
3. `fly deploy` from `v2/` succeeds; `curl https://gallformers.fly.dev/health` returns 200
4. Environment variables documented for both local dev (`.env`) and Fly.io (`fly secrets`)
5. CI/CD pipeline runs v2 tests and deploys on push to main
