# Gallformers V2 - Makefile
#
# Phoenix/LiveView development commands

.PHONY: dev test download-db ci help deps assets setup clean check-db

# Download production database for local dev
# Uses public S3 snapshot (updated daily by GitHub Actions)
DB_URL ?= https://gallformers-backups.s3.amazonaws.com/public/gallformers.sqlite

download-db:
	@echo "Downloading database from S3..."
	@mkdir -p priv
	curl -L -o priv/gallformers.sqlite $(DB_URL)
	@echo "Database downloaded to priv/gallformers.sqlite"

# =============================================================================
# Build Dependencies
# =============================================================================

# Install Elixir dependencies
deps:
	mix deps.get

# Install npm packages and build assets
assets/node_modules: assets/package.json
	cd assets && npm install
	@touch assets/node_modules

assets: assets/node_modules
	mix assets.setup
	mix assets.build

# Ensure database exists and has data (not just Ecto's empty schema_migrations)
check-db:
	@if [ ! -f priv/gallformers.sqlite ]; then \
		echo ""; \
		echo "ERROR: Database not found at priv/gallformers.sqlite"; \
		echo "Run 'make download-db' to download the database"; \
		echo ""; \
		exit 1; \
	fi
	@DB_SIZE=$$(stat -f%z priv/gallformers.sqlite 2>/dev/null || stat -c%s priv/gallformers.sqlite 2>/dev/null); \
	if [ "$$DB_SIZE" -lt 100000 ]; then \
		echo ""; \
		echo "ERROR: Database appears empty (only $$DB_SIZE bytes)"; \
		echo "Run 'make download-db' to download the production database"; \
		echo ""; \
		exit 1; \
	fi

# Full setup (deps + assets + database)
setup: deps assets check-db

# =============================================================================
# Development
# =============================================================================

# Start development server (ensures deps and assets are ready)
dev: setup
	mix phx.server

# Run tests
test:
	mix test

# Run CI checks (same as GitHub Actions)
ci: assets/node_modules
	@echo "==> Checking formatting..."
	mix format --check-formatted
	@echo "==> Compiling with warnings as errors..."
	mix compile --warnings-as-errors
	@echo "==> Running Credo..."
	mix credo --strict
	@echo "==> Running tests..."
	mix test
	@echo "==> Building assets (validates JS/CSS bundling)..."
	mix assets.deploy
	@echo "==> Running Dialyzer..."
	mix dialyzer
	@echo "==> All CI checks passed!"

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

# Clean build artifacts
clean:
	rm -rf assets/node_modules
	rm -rf _build
	rm -rf deps
	rm -rf priv/static/assets

# Show help
help:
	@echo "Gallformers V2 Makefile"
	@echo ""
	@echo "Development:"
	@echo "  make dev          Start Phoenix dev server (:4000) - auto-installs deps"
	@echo "  make test         Run tests"
	@echo "  make ci           Run all CI checks (format, compile, credo, test, dialyzer)"
	@echo ""
	@echo "Build:"
	@echo "  make setup        Full setup (deps + assets + db check)"
	@echo "  make deps         Install Elixir dependencies"
	@echo "  make assets       Install npm packages and build assets"
	@echo "  make clean        Clean build artifacts (node_modules, _build, deps)"
	@echo ""
	@echo "Database:"
	@echo "  make download-db  Download database snapshot from S3"
	@echo ""
	@echo "Git Sync (multi-agent workflow):"
	@echo "  make sync-start              Reset branch to integration (for code1/code2)"
	@echo "  MSG=\"desc\" make sync-finish  Push, PR, merge to integration (for code1/code2)"
	@echo "  make sync-bugfix             Pull latest integration (for bugfix)"
	@echo "  make sync-main-to-integration  Sync main specs into integration via PR"

