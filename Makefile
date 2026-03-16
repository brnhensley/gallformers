# Gallformers - Makefile
#
# Phoenix/LiveView development commands

.PHONY: dev dev-lan test test-db test-prod-data test-prod-data-e2e test-prod-data-all download-db ci preflight help deps assets setup clean check-db build run-local-release dump-schema preview preview-stop preview-destroy

# Download production database for local dev
# Downloads full pg_dump from private S3 bucket and restores into local Postgres
# Requires AWS credentials (AWS_ACCESS_KEY_ID/SECRET_ACCESS_KEY in .env or ~/.aws)
DUMP_BUCKET ?= gallformers-full-backups

download-db:
	@echo "Finding latest backup..."
	$(eval LATEST_DATE := $(shell aws s3 ls s3://$(DUMP_BUCKET)/ | tail -1 | awk '{print $$2}' | tr -d '/'))
	@echo "Downloading backup from $(LATEST_DATE)..."
	aws s3 cp s3://$(DUMP_BUCKET)/$(LATEST_DATE)/gallformers.dump /tmp/gallformers.dump
	@echo "Restoring into gallformers_dev..."
	mix ecto.drop
	mix ecto.create
	pg_restore --no-owner --no-acl -d gallformers_dev /tmp/gallformers.dump || true
	@echo "Verifying..."
	@psql -d gallformers_dev -tAc "SELECT count(*) FROM species" | grep -qE '^[1-9]' || { \
		echo "ERROR: Restore failed — no species data found"; \
		exit 1; \
	}
	@echo "Database restored to gallformers_dev"

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

# Ensure dev database exists and has data
check-db:
	@psql -d gallformers_dev -tAc "SELECT count(*) FROM species" 2>/dev/null | grep -qE '^[1-9]' || { \
		echo ""; \
		echo "ERROR: Dev database not found or has no species data"; \
		echo "Set it up with:"; \
		echo "  make download-db"; \
		echo ""; \
		exit 1; \
	}

# Dump database schema (Postgres SQL format)
dump-schema:
	mix ecto.dump
	@echo "Schema dumped to priv/repo/structure.sql"

# Full setup (deps + assets + database)
setup: deps assets check-db

# =============================================================================
# Development
# =============================================================================

# Start development server (ensures deps and assets are ready)
# Loads .env if present for Auth0 and other local config
dev: setup
	set -a && [ -f .env ] && . .env; set +a && PREVIEW_DEPLOY=true mix phx.server

# Start dev server on port 4002 for LAN access (dev already binds 0.0.0.0)
# Usage: make dev-lan              # default port 4002
#        make dev-lan LAN_PORT=4444 # custom port
LAN_PORT ?= 4002
dev-lan: setup
	@echo "Starting LAN dev server on port $(LAN_PORT)..."
	@echo "Access from other devices at http://$$(ipconfig getifaddr en0 2>/dev/null || hostname -I | awk '{print $$1}'):$(LAN_PORT)"
	set -a && [ -f .env ] && . .env; set +a && PHX_BIND=0.0.0.0 PORT=$(LAN_PORT) PREVIEW_DEPLOY=true mix phx.server

# =============================================================================
# Production Build
# =============================================================================

# Build production release locally
build: deps
	MIX_ENV=prod mix compile
	MIX_ENV=prod mix assets.deploy
	MIX_ENV=prod mix release --overwrite

# Run the locally built production release
# Requires SECRET_KEY_BASE and DATABASE_URL environment variables
run-local-release:
	@if [ -z "$$SECRET_KEY_BASE" ]; then \
		echo "Generating SECRET_KEY_BASE..."; \
		export SECRET_KEY_BASE=$$(mix phx.gen.secret); \
	fi; \
	DATABASE_URL=$${DATABASE_URL:-postgres://localhost/gallformers_dev} \
	PHX_HOST=localhost \
	PORT=4000 \
	_build/prod/rel/gallformers/bin/gallformers start

# =============================================================================
# Testing
# =============================================================================

# Set up fresh test database with migrations + seed data
test-db:
	@echo "Setting up test database..."
	@MIX_ENV=test mix ecto.drop --quiet 2>/dev/null || true
	@MIX_ENV=test mix ecto.create --quiet
	@MIX_ENV=test mix ecto.migrate --quiet
	@psql -d gallformers_test -f priv/repo/test_seeds.sql --quiet
	@echo "Test database ready"

# Run tests (rebuilds test DB first, excludes E2E tests)
test: test-db
	mix test

# Load production data into the test database from the daily pg_dump backup
# Requires AWS credentials (same as download-db)
load-prod-data-test:
	@echo "Loading production data into test database..."
	@if [ ! -f /tmp/gallformers.dump ]; then \
		echo "Downloading latest backup..."; \
		$(eval LATEST_DATE := $(shell aws s3 ls s3://$(DUMP_BUCKET)/ | tail -1 | awk '{print $$2}' | tr -d '/')) \
		aws s3 cp s3://$(DUMP_BUCKET)/$(LATEST_DATE)/gallformers.dump /tmp/gallformers.dump; \
	else \
		echo "Using cached /tmp/gallformers.dump"; \
	fi
	@MIX_ENV=test mix ecto.drop --quiet 2>/dev/null || true
	@MIX_ENV=test mix ecto.create --quiet
	@pg_restore --no-owner --no-acl -d gallformers_test /tmp/gallformers.dump || true
	@echo "Production data loaded into gallformers_test"

# Run context-level tests against production data (no browser)
# Validates data integrity and exercises write paths against real data
# All writes use Ecto sandbox (rolled back automatically)
# Requires AWS credentials for downloading the backup
test-prod-data: load-prod-data-test
	@echo "Running prod data context tests..."
	@mix test test/prod_data/invariants_test.exs test/prod_data/write_operations_test.exs --include prod_data; \
		status=$$?; \
		echo "Restoring test database..."; \
		$(MAKE) test-db; \
		exit $$status

# Run E2E browser tests against production data
# Requires chromedriver: brew install chromedriver
test-prod-data-e2e: load-prod-data-test
	$(call check_chromedriver)
	@echo "Running prod data E2E tests..."
	@GALLFORMERS_E2E=1 mix test test/prod_data/e2e --include prod_data; \
		status=$$?; \
		echo "Restoring test database..."; \
		$(MAKE) test-db; \
		exit $$status

# Run all prod data tests (context + E2E in separate passes)
test-prod-data-all: load-prod-data-test
	$(call check_chromedriver)
	@echo "Running prod data context tests..."
	@mix test test/prod_data/invariants_test.exs test/prod_data/write_operations_test.exs --include prod_data
	@echo "Running prod data E2E tests..."
	@GALLFORMERS_E2E=1 mix test test/prod_data/e2e --include prod_data; \
		status=$$?; \
		echo "Restoring test database..."; \
		$(MAKE) test-db; \
		exit $$status

# Check for unexpected test exclusions (non-E2E tests with @tag :skip, etc.)
# Runs ALL tests including E2E - if output shows "X excluded", investigate
test-check-exclusions:
	$(call check_chromedriver)
	mix test.check_exclusions

# =============================================================================
# E2E Testing (Wallaby/Chrome)
# =============================================================================
# E2E tests are excluded from regular test runs. Use these targets to run them.
# Requires chromedriver: brew install chromedriver (macOS)
# See test/support/e2e_case.ex for documentation on writing E2E tests.

.PHONY: e2e e2e-public e2e-search e2e-browse e2e-admin e2e-auth e2e-setup e2e-headed e2e-slow e2e-changed

# Helper function to check chromedriver (called by all E2E targets)
define check_chromedriver
	@if ! command -v chromedriver >/dev/null 2>&1; then \
		echo ""; \
		echo "ERROR: chromedriver not found"; \
		echo ""; \
		echo "E2E tests require chromedriver. Install it:"; \
		echo "  macOS:   brew install chromedriver"; \
		echo "           xattr -d com.apple.quarantine \$$(which chromedriver)"; \
		echo "  Ubuntu:  sudo apt-get install chromium-chromedriver"; \
		echo ""; \
		echo "Then run: make e2e-setup"; \
		echo ""; \
		exit 1; \
	fi
endef

# Check chromedriver installation (required for Wallaby E2E tests)
e2e-setup:
	@echo "Checking chromedriver installation..."
	@if command -v chromedriver >/dev/null 2>&1; then \
		echo "✓ chromedriver found: $$(chromedriver --version)"; \
	else \
		echo "✗ chromedriver not found"; \
		echo ""; \
		echo "Install chromedriver:"; \
		echo "  macOS:   brew install chromedriver"; \
		echo "           xattr -d com.apple.quarantine \$$(which chromedriver)"; \
		echo "  Ubuntu:  sudo apt-get install chromium-chromedriver"; \
		echo "  Or download from: https://chromedriver.chromium.org/downloads"; \
		exit 1; \
	fi
	@echo ""
	@echo "Done. Run 'make e2e' to run E2E tests."

# Run all E2E tests
e2e:
	$(call check_chromedriver)
	@echo "Running all E2E tests..."
	GALLFORMERS_E2E=1 mix test test/e2e --include e2e

# Run E2E tests for public pages only
e2e-public:
	$(call check_chromedriver)
	@echo "Running public pages E2E tests..."
	GALLFORMERS_E2E=1 mix test test/e2e/public --include e2e

# Run E2E tests for search functionality only
e2e-search:
	$(call check_chromedriver)
	@echo "Running search E2E tests..."
	GALLFORMERS_E2E=1 mix test test/e2e/search --include e2e

# Run E2E tests for browse functionality only
e2e-browse:
	$(call check_chromedriver)
	@echo "Running browse E2E tests..."
	GALLFORMERS_E2E=1 mix test test/e2e/browse --include e2e

# Run E2E tests for admin functionality only
e2e-admin:
	$(call check_chromedriver)
	@echo "Running admin E2E tests..."
	GALLFORMERS_E2E=1 mix test test/e2e/admin --include e2e

# Run E2E tests for auth functionality only
e2e-auth:
	$(call check_chromedriver)
	@echo "Running auth E2E tests..."
	GALLFORMERS_E2E=1 mix test test/e2e/auth --include e2e

# Run E2E tests with visible browser (for debugging)
e2e-headed:
	$(call check_chromedriver)
	@echo "Running E2E tests with visible browser..."
	GALLFORMERS_E2E=1 E2E_HEADED=1 mix test test/e2e --include e2e

# Run E2E tests in slow motion (for debugging)
# Note: Wallaby doesn't have a built-in slow mode like Playwright,
# but headed mode helps with visual debugging
e2e-slow:
	$(call check_chromedriver)
	@echo "Running E2E tests with visible browser (slow mode)..."
	GALLFORMERS_E2E=1 E2E_HEADED=1 mix test test/e2e --include e2e --trace

# Run only E2E tests affected by changed files (smart mode)
# Usage: make e2e-changed              # Compare against main
#        make e2e-changed REF=HEAD~3   # Compare against specific ref
e2e-changed:
	$(call check_chromedriver)
	@./scripts/e2e-changed $(REF)

# =============================================================================

# Run CI checks (same as GitHub Actions)
ci: assets/node_modules test-db
	@echo "==> Running precommit checks (format, compile, credo, migrations, tests)..."
	mix precommit
	@echo ""
	@echo "==> Core CI checks passed! Running extended checks..."
	@echo ""
	@echo "==> Building assets (validates JS/CSS bundling)..."
	mix assets.deploy
	@echo "==> Running Dialyzer..."
	mix dialyzer
	@echo "==> All CI checks passed!"

# Run everything before pushing (local only, not for CI)
# Requires: chromedriver (make e2e-setup) and AWS credentials (for prod data tests)
preflight: ci
	$(call check_chromedriver)
	@echo ""
	@echo "==> CI checks passed. Running E2E browser tests..."
	GALLFORMERS_E2E=1 mix test test/e2e --include e2e
	@echo "Stopping stale chromedriver processes..."
	@pkill -f chromedriver 2>/dev/null || true
	@sleep 1
	@echo ""
	@echo "==> E2E tests passed. Running prod data tests..."
	$(MAKE) test-prod-data-all
	@echo ""
	@echo "==> All preflight checks passed! Safe to push."

# =============================================================================
# Preview Deploys
# =============================================================================
# Deploy current branch to a disposable Fly.io preview instance.
# One-time setup: fly apps create gallformers-preview && fly secrets set ... (mirror prod secrets)

# Build and deploy preview from current local branch
preview:
	fly deploy --config fly.preview.toml

# Stop the preview machine (preserves app config and secrets)
preview-stop:
	fly machine stop --select --config fly.preview.toml

# Destroy the preview app entirely
preview-destroy:
	fly apps destroy gallformers-preview --yes

# Clean build artifacts
clean:
	rm -rf assets/node_modules
	rm -rf _build
	rm -rf deps
	rm -rf priv/static/assets

# Show help
help:
	@echo "Gallformers Makefile"
	@echo ""
	@echo "Development:"
	@echo "  make dev               Start Phoenix dev server (:4000) - auto-installs deps"
	@echo "  make dev-lan           Start dev server on :4002 for LAN access (LAN_PORT=N to override)"
	@echo "  make test              Run tests (fast, excludes E2E and prod_data)"
	@echo "  make test-prod-data    Run context tests against prod data copy (no browser)"
	@echo "  make test-prod-data-e2e  Run E2E tests against prod data copy (requires chromedriver)"
	@echo "  make test-prod-data-all  Run all tests against prod data copy"
	@echo "  make ci                Run all CI checks (format, compile, credo, test, dialyzer)"
	@echo "  make preflight         Run EVERYTHING before pushing (ci + e2e + prod data tests)"
	@echo ""
	@echo "E2E Testing (Wallaby/Chrome):"
	@echo "  make e2e-setup         Check chromedriver installation"
	@echo "  make e2e               Run all E2E tests"
	@echo "  make e2e-changed       Run E2E tests for changed files only (smart)"
	@echo "  make e2e-public        Run E2E tests for public pages only"
	@echo "  make e2e-search        Run E2E tests for search only"
	@echo "  make e2e-browse        Run E2E tests for browse only"
	@echo "  make e2e-admin         Run E2E tests for admin only"
	@echo "  make e2e-auth          Run E2E tests for auth only"
	@echo "  make e2e-headed        Run E2E tests with visible browser"
	@echo "  make e2e-slow          Run E2E tests in slow motion (debugging)"
	@echo ""
	@echo "Build:"
	@echo "  make setup             Full setup (deps + assets + db check)"
	@echo "  make deps              Install Elixir dependencies"
	@echo "  make assets            Install npm packages and build assets"
	@echo "  make build             Build production release locally"
	@echo "  make run-local-release Run the locally built production release"
	@echo "  make clean             Clean build artifacts (node_modules, _build, deps)"
	@echo ""
	@echo "Database:"
	@echo "  make download-db       Download pg_dump from S3 and restore to local Postgres"
	@echo "  make test-db           Rebuild test database (drop, create, migrate, seed)"
	@echo ""
	@echo "Preview Deploys:"
	@echo "  make preview           Deploy current branch to preview (gallformers-preview.fly.dev)"
	@echo "  make preview-stop      Stop the preview machine (preserves config)"
	@echo "  make preview-destroy   Destroy the preview app entirely"
