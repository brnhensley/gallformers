# v2-infrastructure Specification

## Purpose
TBD - created by archiving change define-v2-foundation. Update Purpose after archive.
## Requirements
### Requirement: V2 code MUST live in isolated v2/ subdirectory

All v2 code MUST reside in a `v2/` subdirectory within the existing repository. This provides strict isolation from v1 code while allowing access to shared resources.

#### Scenario: Go API code location
- Given the gallformers repository
- When adding Go API server code
- Then it MUST be placed under `v2/api/` directory
- And it MUST have its own `go.mod` file

#### Scenario: Svelte frontend code location
- Given the gallformers repository
- When adding Svelte frontend code
- Then it MUST be placed under `v2/web/` directory
- And it MUST have its own `package.json` file

#### Scenario: Shared resources remain at root
- Given v2 development is in progress
- When accessing shared resources (database, migrations, reference articles)
- Then they remain at their current locations (`prisma/`, `migrations/`, `ref/`)
- And both v1 and v2 code can access them

### Requirement: V2 directory MUST include agent isolation instructions

A `v2/CLAUDE.md` file MUST exist with explicit rules for AI agent behavior during v2 development.

#### Scenario: Agent working on v2
- Given an AI agent is tasked with v2 development
- When the agent reads `v2/CLAUDE.md`
- Then the agent MUST NOT modify code outside `v2/`
- And the agent MUST NOT add dependencies on v1 code
- And the agent MAY search and read v1 code to understand existing behavior
- And the agent MAY use shared resources (`prisma/`, `migrations/`, `ref/`)

#### Scenario: Agent needs to understand v1 behavior
- Given an AI agent needs to replicate v1 functionality
- When implementing equivalent behavior in v2
- Then the agent MAY search and read v1 code
- And the agent MUST document the behavior being replicated
- And the agent MUST implement fresh code in v2
- And the agent MUST NOT modify any v1 files

### Requirement: V2 MUST deploy to Fly.io as single app

V2 deployment MUST use Fly.io with a single-app architecture where the Go binary serves both API routes and static Svelte files.

#### Scenario: V2 deployment during development
- Given v2 is in development
- When deploying for testing
- Then deployment uses `fly deploy` from `v2/` directory
- And a single Fly.io app named `gallformers` is deployed
- And the Go binary serves API at `/health` and static files at other routes
- And Fly.io handles SSL, routing, and container management

#### Scenario: V2 cutover to production
- Given v2 is ready for production
- When cutting over from v1
- Then Fly.io resources are scaled up
- And DNS is pointed to Fly.io
- And DO Droplet is deprecated

### Requirement: Database path MUST use environment variable

V2 MUST read the database path from the `DATABASE_PATH` environment variable, not hardcoded paths.

#### Scenario: Local development database access
- Given a developer is running v2 locally
- When the API server starts
- Then it reads `DATABASE_PATH` from the environment (or `.env` file)
- And connects to the SQLite database at that path
- And the path is typically `../prisma/gallformers.sqlite` for local dev

#### Scenario: Production database access
- Given v2 is deployed to Fly.io
- When the API server starts
- Then it reads `DATABASE_PATH` from Fly.io secrets
- And connects to the SQLite database on the mounted volume
- And the path is `/data/gallformers.sqlite`

### Requirement: Local development MUST use Makefile coordination

V2 local development MUST use a Makefile (following the [oaks project](https://github.com/jeffdc/oaks) pattern) to coordinate API and web dev servers.

#### Scenario: Starting local development
- Given a developer wants to work on v2
- When they run `make dev` from `v2/`
- Then the Go API server starts on port 8080
- And the Svelte dev server starts on port 5173
- And both servers can be stopped with Ctrl+C

#### Scenario: Database download for local development
- Given a developer needs a fresh database copy
- When they run `make download-db` from `v2/`
- Then it reads `PROD_HOST` from the environment
- And downloads production SQLite to `prisma/gallformers.sqlite`
- And the API server can read from this local copy

### Requirement: Placeholder apps MUST implement health check and static page

The initial v2 scaffold MUST include working placeholder apps that validate the infrastructure.

#### Scenario: Go API placeholder
- Given the v2 Go API is scaffolded
- When a request is made to `GET /health`
- Then it returns `{"status": "ok"}` with HTTP 200
- And no database connection is required for this endpoint

#### Scenario: Svelte placeholder
- Given the v2 Svelte web is scaffolded
- When the index page is loaded
- Then it displays "Gallformers v2 - Coming Soon"
- And the page builds to static files that Go can serve

