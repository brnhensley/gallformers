# Gallformers V2 - Top-level Makefile
#
# Coordinates development across components:
#   - api/  - Go REST API server
#   - web/  - Svelte frontend

.PHONY: dev dev-api dev-web prod prod-api prod-web prod-embedded storybook build test clean download-db help

# Start both API and web dev servers
# API runs on :8080, web on :5173
# Ctrl+C kills both
dev:
	@echo "Starting API server on http://localhost:8080"
	@echo "Starting web dev server on http://localhost:5173"
	@echo "Press Ctrl+C to stop both..."
	@if [ -f .env ]; then set -a && . ./.env && set +a; fi && \
		trap 'kill 0' INT && \
		(cd api && $(MAKE) run) & \
		(cd web && npm run dev) & \
		wait

# Start only the API server (loads .env from v2/)
dev-api:
	@if [ -f .env ]; then set -a && . ./.env && set +a; fi && \
		cd api && $(MAKE) run

# Start only the web dev server
dev-web:
	cd web && npm run dev

# Start both API and web servers in production mode locally
# API runs on :8080, web preview on :4173
# Requires `make build` first
# Ctrl+C kills both
prod:
	@echo "Starting API server on http://localhost:8080"
	@echo "Starting web preview server on http://localhost:4173"
	@echo "Press Ctrl+C to stop both..."
	@if [ -f .env ]; then set -a && . ./.env && set +a; fi && \
		trap 'kill 0' INT && \
		(cd api && ./bin/gallformers-api) & \
		(cd web && npm run preview) & \
		wait

# Start only the API server in production mode (from built binary)
prod-api:
	@if [ -f .env ]; then set -a && . ./.env && set +a; fi && \
		cd api && ./bin/gallformers-api

# Start only the web preview server (production build)
prod-web:
	cd web && npm run preview

# Production-identical local testing (RECOMMENDED for catching deploy issues)
# Builds web, embeds in Go binary, runs Go server ONLY - exactly like Fly.io
# No Vite, no preview server - all requests go through Go's static file handler
prod-embedded:
	@echo "Building web static files..."
	cd web && npm run build
	@echo "Copying to Go embed directory..."
	rm -rf api/cmd/server/static/* 2>/dev/null || true
	cp -r web/build/* api/cmd/server/static/
	@echo "Rebuilding Go binary with embedded files..."
	cd api && $(MAKE) build
	@echo ""
	@echo "Starting Go server on http://localhost:8080"
	@echo "This is IDENTICAL to production - no Vite/Node involved!"
	@echo ""
	@if [ -f .env ]; then set -a && . ./.env && set +a; fi && \
		cd api && ./bin/gallformers-api

# Start Storybook component explorer
storybook:
	cd web && npm run storybook

# Build all components
build:
	cd web && npm run build
	cd api && $(MAKE) build

# Run all tests
test:
	cd api && $(MAKE) test
	cd web && npm test

# Clean all build artifacts
clean:
	cd api && $(MAKE) clean
	cd web && rm -rf build .svelte-kit node_modules

# Download production database for local dev
# Uses public S3 snapshot (updated daily by GitHub Actions)
DB_URL ?= https://gallformers-backups.s3.amazonaws.com/public/gallformers.sqlite

download-db:
	@echo "Downloading database from S3..."
	@mkdir -p data
	curl -L -o data/gallformers.sqlite $(DB_URL)
	@echo "Database downloaded to data/gallformers.sqlite"

# =============================================================================
# Git Sync Targets (for multi-agent workflow)
# =============================================================================
# Integration branch for Phoenix work
INTEGRATION_BRANCH ?= adopt-phoenix-liveview

.PHONY: sync-start sync-finish sync-bugfix sync-main-to-integration

# For code1/code2 agents - run BEFORE starting work
# Resets current branch to match integration branch
sync-start:
	@echo "Syncing with integration branch ($(INTEGRATION_BRANCH))..."
	git fetch origin
	git reset --hard origin/$(INTEGRATION_BRANCH)
	@echo "Ready to work. Branch is now in sync with $(INTEGRATION_BRANCH)."

# For code1/code2 agents - run AFTER work is complete
# Pushes branch, creates PR to integration, and merges it
# Usage: MSG="search LiveView" make sync-finish
sync-finish:
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" = "$(INTEGRATION_BRANCH)" ] || [ "$$BRANCH" = "main" ]; then \
		echo "Error: sync-finish is for code1/code2 branches, not $$BRANCH"; \
		exit 1; \
	fi; \
	echo "Pushing $$BRANCH to origin..."; \
	git push origin $$BRANCH; \
	echo "Creating PR to $(INTEGRATION_BRANCH)..."; \
	gh pr create --base $(INTEGRATION_BRANCH) --head $$BRANCH \
		--title "Merge $$BRANCH: $${MSG:-completed work}" \
		--body "Automated merge from $$BRANCH"; \
	echo "Merging PR..."; \
	gh pr merge --merge --delete-branch=false; \
	echo "Done. Changes merged to $(INTEGRATION_BRANCH)."

# For bugfix agent - sync with integration branch (works directly on it)
sync-bugfix:
	@echo "Syncing with integration branch ($(INTEGRATION_BRANCH))..."
	git fetch origin
	git pull origin $(INTEGRATION_BRANCH)
	@echo "Ready to work on $(INTEGRATION_BRANCH)."

# For planning (main worktree) - sync main specs INTO integration branch via PR
# If conflicts exist, PR will be created but not merged - resolve manually
sync-main-to-integration:
	@echo "Creating PR to sync main into $(INTEGRATION_BRANCH)..."
	git fetch origin
	gh pr create --base $(INTEGRATION_BRANCH) --head main \
		--title "Sync main specs into integration" \
		--body "Sync latest spec/planning changes from main into $(INTEGRATION_BRANCH)" || true
	@echo "Attempting to merge PR..."
	@gh pr merge --merge 2>/dev/null && echo "Done. Main synced into $(INTEGRATION_BRANCH)." || \
		echo "PR has conflicts. Resolve via: gh pr view --web, or use bugfix worktree to merge manually."

# =============================================================================

# Show help
help:
	@echo "Gallformers V2 Makefile"
	@echo ""
	@echo "Development:"
	@echo "  make dev        Start API (:8080) and web (:5173) together"
	@echo "  make dev-api    Start only the API server"
	@echo "  make dev-web    Start only the web dev server"
	@echo "  make storybook  Start Storybook component explorer (:6006)"
	@echo ""
	@echo "Production (local):"
	@echo "  make prod          Start API (:8080) and web preview (:4173) together"
	@echo "  make prod-api      Start only the API server (built binary)"
	@echo "  make prod-web      Start only the web preview server"
	@echo "  make prod-embedded Build & run Go with embedded files (IDENTICAL to Fly.io)"
	@echo ""
	@echo "Building:"
	@echo "  make build      Build all components (web first, then API with embedded files)"
	@echo ""
	@echo "Testing:"
	@echo "  make test       Run all tests"
	@echo ""
	@echo "Database:"
	@echo "  make download-db  Download database snapshot from S3"
	@echo ""
	@echo "Git Sync (multi-agent workflow):"
	@echo "  make sync-start              Reset branch to integration (for code1/code2)"
	@echo "  MSG=\"desc\" make sync-finish  Push, PR, merge to integration (for code1/code2)"
	@echo "  make sync-bugfix             Pull latest integration (for bugfix)"
	@echo "  make sync-main-to-integration  Sync main specs into integration via PR"
	@echo ""
	@echo "Other:"
	@echo "  make clean      Clean build artifacts"

