# Gallformers V2 - Makefile
#
# Phoenix/LiveView development commands

.PHONY: dev test download-db help

# Download production database for local dev
# Uses public S3 snapshot (updated daily by GitHub Actions)
DB_URL ?= https://gallformers-backups.s3.amazonaws.com/public/gallformers.sqlite

download-db:
	@echo "Downloading database from S3..."
	@mkdir -p priv
	curl -L -o priv/gallformers.sqlite $(DB_URL)
	@echo "Database downloaded to priv/gallformers.sqlite"

# Start development server
dev:
	mix phx.server

# Run tests
test:
	mix test

# Show help
help:
	@echo "Gallformers V2 Makefile"
	@echo ""
	@echo "Development:"
	@echo "  make dev          Start Phoenix dev server (:4000)"
	@echo "  make test         Run tests"
	@echo ""
	@echo "Database:"
	@echo "  make download-db  Download database snapshot from S3"
	@echo ""
