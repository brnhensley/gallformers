# Gallformers V2 - Top-level Makefile
#
# Coordinates development across components:
#   - api/  - Go REST API server
#   - web/  - Svelte frontend

.PHONY: dev dev-api dev-web storybook build test clean download-db help

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

