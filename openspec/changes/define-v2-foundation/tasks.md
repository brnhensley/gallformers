# Tasks: Define V2 Technical Foundation

## 1. Review and Confirm Decisions

- [ ] 1.1 Review design.md analysis
- [ ] 1.2 Confirm `v2/` subdirectory structure (strict isolation)
- [ ] 1.3 Confirm Fly.io hosting with single-app architecture
- [ ] 1.4 Confirm Makefile-coordinated local dev (oaks pattern)
- [ ] 1.5 Confirm trunk-based git workflow

## 2. Research and Document Open Items

- [ ] 2.1 Research backup strategy (Litestream vs manual `fly ssh sftp get` vs other)
- [ ] 2.2 Define environment variables and secrets strategy
  - Required env vars for v2 (DATABASE_PATH, PROD_HOST, etc.)
  - Local dev setup (`.env` file pattern, `.env.example` template)
  - Fly.io secrets (`fly secrets set`)
- [ ] 2.3 Define CI/CD strategy for v2
  - Test pipeline (Go tests, Svelte build, type checking)
  - PR checks for v2 code
  - Deploy pipeline on push to main
- [ ] 2.4 Document rollback strategy/procedure
  - How to identify bad deployment
  - Step-by-step rollback commands
  - Database considerations

## 3. Cleanup Existing Fly.io Attempt

- [ ] 3.1 Destroy existing `gallformers` Fly.io app if present
- [ ] 3.2 Remove `fly.toml` from repo root
- [ ] 3.3 Remove `Dockerfile.fly` from repo root

## 4. Create Fly.io App

- [ ] 4.1 Create Fly.io app named `gallformers`
- [ ] 4.2 Create Fly.io volume for database
- [ ] 4.3 Configure initial secrets (`fly secrets set DATABASE_PATH=...`)

## 5. Create V2 Directory Structure

- [ ] 5.1 Create `v2/` directory
- [ ] 5.2 Create `v2/CLAUDE.md` with agent isolation rules
- [ ] 5.3 Create `v2/Makefile` (based on oaks pattern)
- [ ] 5.4 Create `v2/fly.toml` for Fly.io deployment
- [ ] 5.5 Create `v2/Dockerfile` (single container for Go + static files)
- [ ] 5.6 Create `v2/.env.example` with required env vars
- [ ] 5.7 Create `v2/.gitignore`

## 6. Scaffold Go API

- [ ] 6.1 Create `v2/api/` directory structure
  - `cmd/server/main.go` with `/health` endpoint
  - `internal/handlers/` (empty for now)
  - `go.mod`
  - `Makefile`
- [ ] 6.2 Implement health endpoint: `GET /health` returns `{"status": "ok"}`
- [ ] 6.3 Implement static file serving from embedded filesystem
- [ ] 6.4 Verify `go build` works
- [ ] 6.5 Verify `make run` starts server on :8080
- [ ] 6.6 Verify `curl localhost:8080/health` returns 200

## 7. Scaffold Svelte Web

- [ ] 7.1 Create `v2/web/` with SvelteKit
  - `npm create svelte@latest` or equivalent
  - Configure for static adapter
- [ ] 7.2 Create placeholder index page: "Gallformers v2 - Coming Soon"
- [ ] 7.3 Create `v2/web/Makefile`
- [ ] 7.4 Verify `npm run dev` works on :5173
- [ ] 7.5 Verify `npm run build` produces static files

## 8. Verify Local Development

- [ ] 8.1 Test `make dev` from `v2/` starts both servers
- [ ] 8.2 Test `curl localhost:8080/health` returns 200
- [ ] 8.3 Test `curl localhost:5173` returns 200
- [ ] 8.4 Test `make download-db` copies database (requires PROD_HOST env var)

## 9. Setup CI/CD

- [ ] 9.1 Create `.github/workflows/ci-v2.yml` for tests/build on PRs
- [ ] 9.2 Create `.github/workflows/deploy-v2.yml` for deployment
  - Trigger on push to main with changes in `v2/`
  - Run tests before deploy
  - Build and deploy to Fly.io
- [ ] 9.3 Add `FLY_API_TOKEN` to GitHub secrets
- [ ] 9.4 Test CI runs on PR with v2 changes
- [ ] 9.5 Test deploy pipeline on push to main

## 10. Verify Fly.io Deployment

- [ ] 10.1 Test `fly deploy` from `v2/` directory (manual, one-time)
- [ ] 10.2 Verify `curl https://gallformers.fly.dev/health` returns 200
- [ ] 10.3 Verify placeholder page loads at `https://gallformers.fly.dev`
- [ ] 10.4 Test CI/CD auto-deploys on push to main

## 11. Documentation Updates

- [ ] 11.1 Update root `CLAUDE.md` to mention v2 isolation
- [ ] 11.2 Update `rewrite-gallformers-v2` to mark hosting question resolved
