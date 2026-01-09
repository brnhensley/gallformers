# Gallformers V2 API

Go REST API server for gallformers.org.

## Prerequisites

- Go 1.21+
- SQLite database (shared with v1 at `../prisma/gallformers.sqlite`)
- [sqlc](https://sqlc.dev/) for query generation: `go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest`

## Setup

```bash
# From v2/api/ directory
go mod download
```

## Running

```bash
# Start the API server on :8080
make run

# Or use the parent Makefile from v2/
make dev-api
```

The server serves:
- API endpoints at `/api/v2/*`
- OpenAPI docs at `/api/docs`
- Static files at `/*`

## Testing

```bash
# Run all tests
make test

# Run with verbose output
go test -v ./...
```

## Code Generation

After modifying SQL queries in `internal/db/queries/*.sql`:

```bash
make generate   # Runs sqlc generate
```

## Environment Variables

See `v2/.env.example` for all required variables. Key ones:

- `DATABASE_PATH` - Path to SQLite database
- `AUTH0_*` - Auth0 configuration for admin authentication
- `CORS_ORIGINS` - Allowed CORS origins (comma-separated)
