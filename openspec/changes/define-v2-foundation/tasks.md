# Tasks: Define V2 Technical Foundation

## 1. Review and Confirm Decisions

- [x] 1.1 Review design.md analysis
- [x] 1.2 Confirm `v2/` subdirectory structure (strict isolation)
- [x] 1.3 Confirm Fly.io hosting with single-app architecture
- [x] 1.4 Confirm Makefile-coordinated local dev (oaks pattern)
- [x] 1.5 Confirm trunk-based git workflow

## 2. Research and Document Open Items

- [x] 2.1 Research backup strategy (Litestream vs manual `fly ssh sftp get` vs other)
  - Decision: Litestream for continuous backup + daily public snapshot
  - See `v2/docs/backup-strategy.md`
- [x] 2.2 Define environment variables and secrets strategy
  - Required env vars for v2 (DATABASE_PATH, PROD_HOST, etc.)
  - Local dev setup (`.env` file pattern, `.env.example` template)
  - Fly.io secrets (`fly secrets set`)
- [x] 2.3 Define CI/CD strategy for v2
  - Test pipeline (Go tests, Svelte build, type checking)
  - PR checks for v2 code
  - Deploy pipeline on push to main
  - See `v2/docs/ci-cd-strategy.md`
- [x] 2.4 Document rollback strategy/procedure
  - How to identify bad deployment
  - Step-by-step rollback commands
  - Database considerations
  - See `v2/runbooks/`

## 3. Cleanup Existing Fly.io Attempt

- [x] 3.1 Destroy existing `gallformers` Fly.io app if present
- [x] 3.2 Remove `fly.toml` from repo root
- [x] 3.3 Remove `Dockerfile.fly` from repo root

## 4. Create Fly.io App

- [x] 4.1 Create Fly.io app named `gallformers`
- [x] 4.2 Create Fly.io volume for database
- [x] 4.3 Configure initial secrets (`fly secrets set DATABASE_PATH=...`)

## 5. Create V2 Directory Structure

- [x] 5.1 Create `v2/` directory
- [x] 5.2 Create `v2/CLAUDE.md` with agent isolation rules
- [x] 5.3 Create `v2/Makefile` (based on oaks pattern)
- [x] 5.4 Create `v2/fly.toml` for Fly.io deployment
- [x] 5.5 Create `v2/Dockerfile` (single container for Go + static files)
- [x] 5.6 Create `v2/.env.example` with required env vars
- [x] 5.7 Create `v2/.gitignore`

## 6. Scaffold Go API

- [x] 6.1 Create `v2/api/` directory structure
  - `cmd/server/main.go` with `/health` endpoint
  - `internal/handlers/` (empty for now)
  - `go.mod`
  - `Makefile`
- [x] 6.2 Implement health endpoint: `GET /health` returns `{"status": "ok"}`
- [x] 6.3 Implement static file serving from embedded filesystem
- [x] 6.4 Verify `go build` works
- [x] 6.5 Verify `make run` starts server on :8080
- [x] 6.6 Verify `curl localhost:8080/health` returns 200

## 7. Scaffold Svelte Web

- [x] 7.1 Create `v2/web/` with SvelteKit
  - `npm create svelte@latest` or equivalent
  - Configure for static adapter
- [x] 7.2 Create placeholder index page: "Gallformers v2 - Coming Soon"
- [x] 7.3 Create `v2/web/Makefile`
- [x] 7.4 Verify `npm run dev` works on :5173
- [x] 7.5 Verify `npm run build` produces static files

## 8. Verify Local Development

- [x] 8.1 Test `make dev` from `v2/` starts both servers
- [x] 8.2 Test `curl localhost:8080/health` returns 200
- [x] 8.3 Test `curl localhost:5173` returns 200
- [x] 8.4 Test `make download-db` copies database (requires PROD_HOST env var)

## 9. Setup CI/CD

- [x] 9.1 Create `.github/workflows/ci-v2.yml` for tests/build on PRs
- [x] 9.2 Create `.github/workflows/deploy-v2.yml` for deployment
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

## 12. Status Page Setup

- [ ] 12.1 Set up Upptime in separate repo or branch
  - Configure `.upptimerc.yml` for v2 endpoints
  - Enable GitHub Pages
  - Configure health check intervals
- [ ] 12.2 Configure monitoring endpoints
  - `https://gallformers-v2.fly.dev/health`
  - Main site availability
- [ ] 12.3 Document status page usage in runbooks
  - How to manually add incidents
  - How to acknowledge/resolve incidents
- [ ] 12.4 Update `v2/runbooks/incident-response.md` with status page procedures

## 13. Backup System Setup

- [x] 13.1 Create S3 bucket for backups
  - Create `gallformers-backups` bucket in us-east-1
  - Enable versioning
  - Configure public read policy for `public/` prefix
- [x] 13.2 Create IAM user for Litestream
  - Create user with S3 read/write access to backup bucket
  - Generate access key credentials
- [x] 13.3 Add Litestream to Docker image
  - Create `v2/litestream.yml` config
  - Update Dockerfile to install Litestream
  - Update CMD to use Litestream wrapper
- [x] 13.4 Configure Fly.io secrets
  - Add LITESTREAM_ACCESS_KEY_ID
  - Add LITESTREAM_SECRET_ACCESS_KEY
- [x] 13.5 Create daily snapshot workflow
  - Create `.github/workflows/db-snapshot.yml`
  - Configure scheduled run (daily)
  - Add AWS credentials to GitHub secrets
- [x] 13.6 Update Makefile download-db target
  - Point to public S3 URL
- [x] 13.7 Test and verify
  - Deploy with Litestream enabled
  - Verify data appears in S3 (deferred - no database yet)
  - Test restore procedure (deferred - no database yet)
  - Update restore-database runbook with specific commands
