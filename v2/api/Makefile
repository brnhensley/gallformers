# Gallformers V2 API Makefile

.PHONY: build run test lint clean generate generate-templ templ-watch help

# Build the binary (CGO required for SQLite)
build: generate-templ
	CGO_ENABLED=1 go build -o bin/gallformers-api ./cmd/server

# Run the server locally
run: build
	./bin/gallformers-api

# Run tests
test:
	go test ./...

# Run linter (install: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)
lint:
	golangci-lint run ./...

# Clean build artifacts
clean:
	rm -rf bin/
	go clean

# Generate sqlc code from SQL queries
generate:
	cd internal/db && sqlc generate

# Generate Go code from templ files
generate-templ:
	templ generate

# Watch templ files and regenerate on changes
templ-watch:
	templ generate --watch

# Run with hot reload (templ watch + go run)
dev-htmx:
	@echo "Starting templ watch in background..."
	templ generate --watch &
	@echo "Starting Go server..."
	CGO_ENABLED=1 go run ./cmd/server

# Show help
help:
	@echo "Gallformers V2 API Makefile"
	@echo ""
	@echo "  make build         Build the API binary (includes templ generate)"
	@echo "  make run           Build and run the server"
	@echo "  make test          Run tests"
	@echo "  make lint          Run linter (golangci-lint)"
	@echo "  make clean         Remove build artifacts"
	@echo "  make generate      Regenerate sqlc code from SQL queries"
	@echo "  make generate-templ Generate Go code from templ files"
	@echo "  make templ-watch   Watch templ files and regenerate on changes"
	@echo "  make dev-htmx      Run with templ hot reload for HTMX development"
