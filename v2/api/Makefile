# Gallformers V2 API Makefile

.PHONY: build run test clean help

# Build the binary
build:
	CGO_ENABLED=0 go build -o bin/gallformers-api ./cmd/server

# Run the server locally
run: build
	./bin/gallformers-api

# Run tests
test:
	go test -v ./...

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
	@echo "  make clean    Remove build artifacts"
