# Gallformers V2 - Top-level Makefile
#
# Coordinates development across components:
#   - api/  - Go REST API server
#   - web/  - Svelte frontend

.PHONY: dev dev-api dev-web build test clean download-db help

# Start both API and web dev servers
# API runs on :8080, web on :5173
# Ctrl+C kills both
dev:
	@echo "Starting API server on http://localhost:8080"
	@echo "Starting web dev server on http://localhost:5173"
	@echo "Press Ctrl+C to stop both..."
	@trap 'kill 0' INT; \
		(cd api && $(MAKE) run) & \
		(cd web && npm run dev) & \
		wait

# Start only the API server
dev-api:
	cd api && $(MAKE) run

# Start only the web dev server
dev-web:
	cd web && npm run dev

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
# Requires PROD_HOST env var (e.g., user@server) for current DO setup
# After Fly.io migration, will use: fly ssh sftp get /data/gallformers.sqlite
download-db:
	@echo "Downloading database from production..."
	@if [ -z "$$PROD_HOST" ]; then \
		echo "Error: PROD_HOST env var not set"; \
		echo "Set PROD_HOST to user@server for scp access"; \
		exit 1; \
	fi
	scp $${PROD_HOST}:/mnt/gallformers_data/prisma/gallformers.sqlite ../prisma/
	@echo "Database downloaded to ../prisma/gallformers.sqlite"

# Show help
help:
	@echo "Gallformers V2 Makefile"
	@echo ""
	@echo "Development:"
	@echo "  make dev        Start API (:8080) and web (:5173) together"
	@echo "  make dev-api    Start only the API server"
	@echo "  make dev-web    Start only the web dev server"
	@echo ""
	@echo "Building:"
	@echo "  make build      Build all components (web first, then API with embedded files)"
	@echo ""
	@echo "Testing:"
	@echo "  make test       Run all tests"
	@echo ""
	@echo "Database:"
	@echo "  make download-db  Download database from production (requires PROD_HOST)"
	@echo ""
	@echo "Other:"
	@echo "  make clean      Clean build artifacts"
