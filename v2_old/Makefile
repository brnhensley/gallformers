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
	@echo "Other:"
	@echo "  make clean      Clean build artifacts"

