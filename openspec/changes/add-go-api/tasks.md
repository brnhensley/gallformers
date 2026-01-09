# Tasks: Add Go API Server

## Prerequisites
- [x] Verify `define-v2-foundation` is complete (v2/ directory exists, Fly.io deployment works)

## 1. Project Scaffolding

- [x] 1.1 Initialize Go module (`v2/api/go.mod`)
- [x] 1.2 Create directory structure (`cmd/server/`, `internal/handlers/`, `internal/middleware/`, `internal/db/`)
- [x] 1.3 Add Makefile with build, run, test, lint targets
- [x] 1.4 Create `cmd/server/main.go` with minimal chi router
- [x] 1.5 Add health check endpoint (`GET /health`) with DB check (200 ok / 503 degraded)
- [x] 1.6 Implement graceful shutdown (30s timeout on SIGTERM/SIGINT)
- [x] 1.7 Verify `make run` starts server on :8080

## 2. Database Layer (sqlc)

- [x] 2.1 Install sqlc (`go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest`)
- [x] 2.2 Export SQLite schema (`sqlite3 ../prisma/gallformers.sqlite .schema > internal/db/schema.sql`)
- [x] 2.3 Create `internal/db/sqlc.yaml` configuration
- [x] 2.4 Write base queries for health check (verify DB connection)
- [x] 2.5 Run `sqlc generate`, verify output in `internal/db/generated/`
- [x] 2.6 Wire up database connection in main.go (WAL mode, 5s busy timeout)

## 3. Core Middleware

- [x] 3.1 Implement logging middleware (slog, request_id, duration)
- [x] 3.2 Implement CORS middleware (read origins from CORS_ORIGINS env var)
- [x] 3.3 Implement Auth0 JWT validation middleware (extract from httpOnly cookie)
- [x] 3.4 Implement RequireSuperAdmin middleware (check roles claim)
- [x] 3.5 Implement MaxBodySize middleware (1MB limit)
- [x] 3.6 Create response helpers (RespondJSON, RespondError)
- [x] 3.7 Add middleware unit tests

## 3a. Auth0 Configuration

- [x] 3a.1 Configure Auth0 to include roles in JWT claims (via Rules or Actions)
- [x] 3a.2 Define roles in Auth0: `admin`, `superadmin`
- [x] 3a.3 Assign existing admin users to appropriate roles
- [x] 3a.4 Implement OAuth callback handler (exchange code for tokens)
- [x] 3a.5 Implement httpOnly cookie setting on login (Secure, SameSite=Lax, Path=/)
- [x] 3a.6 Implement `/api/v2/me` endpoint (return current user from token)
- [x] 3a.7 Implement `/api/v2/auth/refresh` endpoint (refresh expired tokens)
- [x] 3a.8 Implement `/api/v2/auth/logout` endpoint (clear auth cookie)
- [x] 3a.9 Test login/refresh/logout flow end-to-end
- [x] 3a.10 Add auth handler unit tests

## 4. OpenAPI Documentation

- [x] 4.1 Create `api/openapi.yaml` skeleton with info, servers, security schemes
- [x] 4.2 Add Swagger UI static files (embed in binary or use CDN)
- [x] 4.3 Serve OpenAPI spec at `/api/docs`
- [x] 4.4 Verify Swagger UI loads and displays spec

## 5. Domain: Gall

- [x] 5.1 Write sqlc queries (`internal/db/queries/gall.sql`)
  - ListGalls, SearchGalls, GetGallByID, GetGallBySpeciesID
  - CreateGall, UpdateGall, DeleteGall
  - Include alias queries (aliases nested in gall payloads)
- [x] 5.2 Implement handlers (`internal/handlers/gall.go`)
  - GET /api/v2/galls (list, search by q param, optional limit/offset pagination)
  - GET /api/v2/galls/{id}
  - POST /api/v2/galls (auth required, includes aliases)
  - PUT /api/v2/galls/{id} (auth required, includes aliases)
  - DELETE /api/v2/galls/{id} (auth required)
- [ ] 5.3 Implement audit field handling (created_at/by, updated_at/by)
- [x] 5.4 Add OpenAPI spec for gall endpoints
- [x] 5.5 Write handler unit tests
- [x] 5.6 Write integration tests comparing v1 and v2 responses

## 6. Domain: Species

- [x] 6.1 Write sqlc queries (`internal/db/queries/species.sql`)
  - ListSpecies, SearchSpecies, GetSpeciesByID
- [x] 6.2 Implement handlers (`internal/handlers/species.go`)
  - GET /api/v2/species (list, search by q param)
  - GET /api/v2/species/{id}
- [x] 6.3 Add OpenAPI spec for species endpoints
- [x] 6.4 Write integration tests

## 7. Domain: Host

- [x] 7.1 Write sqlc queries (`internal/db/queries/host.sql`)
  - ListHosts, SearchHosts, GetHostByID
  - CreateHost, UpdateHost, DeleteHost
  - Include alias queries (aliases nested in host payloads)
- [x] 7.2 Implement handlers (`internal/handlers/host.go`)
  - GET /api/v2/hosts (list, search by q param, simple flag, optional pagination)
  - GET /api/v2/hosts/{id}
  - POST /api/v2/hosts (auth required, includes aliases)
  - PUT /api/v2/hosts/{id} (auth required, includes aliases)
  - DELETE /api/v2/hosts/{id} (auth required)
- [x] 7.4 Add OpenAPI spec for host endpoints
- [x] 7.5 Write handler unit tests
- [x] 7.6 Write integration tests

## 8. Domain: Taxonomy

- [x] 8.1 Write sqlc queries (`internal/db/queries/taxonomy.sql`)
  - Taxonomy CRUD (GetByID, GetBySpeciesID, GetByName, Upsert, Delete)
  - Family CRUD (List, GetByID, Search, Upsert, Delete)
  - Genus CRUD (List, GetByID, Search, Move)
  - Section CRUD (List, GetByID, Delete)
- [x] 8.2 Implement handlers (`internal/handlers/taxonomy.go`)
  - GET /api/v2/taxonomy
  - GET /api/v2/taxonomy/{id}
  - POST /api/v2/taxonomy (auth required)
  - DELETE /api/v2/taxonomy/{id} (auth required)
  - GET /api/v2/taxonomy/families
  - GET /api/v2/taxonomy/families/{id}
  - POST /api/v2/taxonomy/families (auth required)
  - DELETE /api/v2/taxonomy/families/{id} (auth required)
  - GET /api/v2/taxonomy/genera
  - POST /api/v2/taxonomy/genera/move (auth required)
  - GET /api/v2/taxonomy/sections
  - GET /api/v2/taxonomy/sections/{id}
  - DELETE /api/v2/taxonomy/sections/{id} (auth required)
- [x] 8.3 Add OpenAPI spec for taxonomy endpoints
- [x] 8.4 Write integration tests

## 9. Domain: Source

- [x] 9.1 Write sqlc queries (`internal/db/queries/source.sql`)
  - ListSources, SearchSources, GetSourceByID, GetSourceByTitle
  - CreateSource, UpdateSource, DeleteSource
- [x] 9.2 Implement handlers (`internal/handlers/source.go`)
  - GET /api/v2/sources (list, search by q param, by speciesid)
  - GET /api/v2/sources/{id}
  - GET /api/v2/sources/by-title/{title}
  - POST /api/v2/sources (auth required)
  - PUT /api/v2/sources/{id} (auth required)
  - DELETE /api/v2/sources/{id} (auth required)
- [x] 9.3 Add OpenAPI spec for source endpoints
- [x] 9.4 Write integration tests

## 10. Domain: Glossary

- [x] 10.1 Write sqlc queries (`internal/db/queries/glossary.sql`)
  - ListGlossary, SearchGlossary, GetGlossaryByID, GetGlossaryByWord
  - CreateGlossary, UpdateGlossary, DeleteGlossary
- [x] 10.2 Implement handlers (`internal/handlers/glossary.go`)
  - GET /api/v2/glossary (list, search by q param)
  - GET /api/v2/glossary/{id}
  - GET /api/v2/glossary/by-word/{word}
  - POST /api/v2/glossary (auth required)
  - PUT /api/v2/glossary/{id} (auth required)
  - DELETE /api/v2/glossary/{id} (auth required)
- [x] 10.3 Add OpenAPI spec for glossary endpoints
- [x] 10.4 Write integration tests

## 11. Domain: Place

- [x] 11.1 Write sqlc queries (`internal/db/queries/place.sql`)
  - ListPlaces, SearchPlaces, GetPlaceByID, GetPlaceByName
  - CreatePlace, UpdatePlace, DeletePlace
- [x] 11.2 Implement handlers (`internal/handlers/place.go`)
  - GET /api/v2/places (list, search by q param)
  - GET /api/v2/places/{id}
  - GET /api/v2/places/by-name/{name}
  - POST /api/v2/places (auth required)
  - PUT /api/v2/places/{id} (auth required)
  - DELETE /api/v2/places/{id} (auth required)
- [x] 11.3 Add OpenAPI spec for place endpoints
- [x] 11.4 Write integration tests

## 12. Domain: GallHost (Relationship)

- [x] 12.1 Write sqlc queries (`internal/db/queries/gallhost.sql`)
  - ListHostsByGallID, CreateGallHost, DeleteGallHost
- [x] 12.2 Implement handlers (`internal/handlers/gallhost.go`)
  - GET /api/v2/gall-hosts (by gallid param)
  - POST /api/v2/gall-hosts (auth required)
  - DELETE /api/v2/gall-hosts (auth required)
- [x] 12.3 Add OpenAPI spec for gall-host endpoints
- [x] 12.4 Write handler unit tests
- [x] 12.5 Write integration tests

## 13. Domain: SpeciesSource (Relationship)

- [x] 13.1 Write sqlc queries (`internal/db/queries/speciessource.sql`)
  - ListSpeciesSources, GetSpeciesSource, UpsertSpeciesSource, DeleteSpeciesSource
- [x] 13.2 Implement handlers (`internal/handlers/speciessource.go`)
  - GET /api/v2/species-sources (by speciesid, or speciesid+sourceid)
  - POST /api/v2/species-sources (auth required)
  - PUT /api/v2/species-sources (auth required)
  - DELETE /api/v2/species-sources (auth required)
- [x] 13.3 Add OpenAPI spec for species-source endpoints
- [x] 13.4 Write handler unit tests
- [x] 13.5 Write integration tests

## 14. Domain: FilterField

- [x] 14.1 Write sqlc queries (`internal/db/queries/filterfield.sql`)
  - ListFilterFieldTypes, ListFilterFieldsByType, GetFilterFieldByID
  - CreateFilterField, UpdateFilterField, DeleteFilterField
- [x] 14.2 Implement handlers (`internal/handlers/filterfield.go`)
  - GET /api/v2/filter-fields (list field types)
  - GET /api/v2/filter-fields/{type} (list values by type)
  - GET /api/v2/filter-fields/{type}/{id}
  - POST /api/v2/filter-fields (auth required)
  - PUT /api/v2/filter-fields/{type}/{id} (auth required)
  - DELETE /api/v2/filter-fields/{type}/{id} (auth required)
- [x] 14.3 Add OpenAPI spec for filter-field endpoints
- [x] 14.4 Write integration tests

## 15. Domain: Global Search

- [x] 15.1 Write sqlc queries (`internal/db/queries/search.sql`)
  - SearchSpecies (by name, includes aliases)
  - SearchGlossary (by word, definition)
  - SearchSources (by title, author)
  - SearchTaxa (genus, section, family by name)
  - SearchPlaces (by name, code)
- [x] 15.2 Implement handlers (`internal/handlers/search.go`)
  - GET /api/v2/search?q={term}
  - Returns grouped results: `{ species, glossary, sources, taxa, places }`
- [x] 15.3 Add OpenAPI spec for search endpoint
- [x] 15.4 Write integration tests comparing to v1 globalsearch results

## 16. Unit Testing

Unit tests are implemented per-domain (tasks above) and include:
- Handler logic (request parsing, response formatting)
- Middleware (auth validation, CORS, logging)
- Response helpers
- Validation logic

## 17. Integration Testing

- [ ] 17.1 Create test harness that runs queries against both v1 and v2
- [ ] 17.2 Verify all GET endpoints return equivalent data
- [ ] 17.3 Verify auth requirements match v1 (which endpoints need auth)
- [ ] 17.4 Test error responses (404 for missing resources, 401 for unauthorized, 503 for DB unavailable)
- [ ] 17.5 Test pagination on all list endpoints
- [ ] 17.6 Document any intentional differences from v1

## 18. Deployment

- [ ] 18.1 Update `v2/Dockerfile` to build Go API
- [ ] 18.2 Add DATABASE_PATH environment variable handling
- [ ] 18.3 Add Auth0 environment variables (AUTH0_DOMAIN, AUTH0_AUDIENCE)
- [ ] 18.4 Test `fly deploy` from v2/ directory
- [ ] 18.5 Verify health endpoint on Fly.io
- [ ] 18.6 Verify API endpoints work on Fly.io with test database

## 19. Documentation

- [x] 19.1 Complete OpenAPI spec for all endpoints
- [x] 19.2 Add README.md in v2/api/ with development instructions
- [x] 19.3 Document environment variables in .env.example
- [x] 19.4 Update v2/CLAUDE.md with API-specific guidance

## Parallelizable Work

After scaffolding (sections 1-4), domain handlers (sections 5-15) can be implemented in parallel:
- Gall + Species (related data)
- Host (independent)
- Taxonomy (complex hierarchy, do early)
- Source + Glossary + Place (similar patterns)
- GallHost + SpeciesSource (relationship tables)
- FilterField + Search (UI support)
