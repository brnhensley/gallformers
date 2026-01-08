# Gallformers V2 API Makefile

.PHONY: build run test lint clean help

# Build the binary (CGO required for SQLite)
build:
	CGO_ENABLED=1 go build -o bin/gallformers-api ./cmd/server

# Run the server locally
run: build
	./bin/gallformers-api

# Run tests
test:
	go test -v ./...

# Run linter (install: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)
lint:
	golangci-lint run ./...

# Clean build artifacts
clean:
	rm -rf bin/
	go clean

# Show help
help:
	@echo "Gallformers V2 API Makefile"
	@echo ""
	@echo "  make build    Build the API binary"
	@echo "  make run      Build and run the server"
	@echo "  make test     Run tests"
	@echo "  make lint     Run linter (golangci-lint)"
	@echo "  make clean    Remove build artifacts"
