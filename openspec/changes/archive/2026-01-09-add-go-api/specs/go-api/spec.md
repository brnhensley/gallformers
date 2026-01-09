# Capability: Go API

The Go API server provides REST endpoints for all gallformers data operations, replacing the Next.js API routes.

## ADDED Requirements

### Requirement: API Server Foundation

The Go API server SHALL provide a chi-based HTTP server with structured logging, CORS support, and health checking.

#### Scenario: Server startup
- **WHEN** the server binary is executed with valid DATABASE_PATH
- **THEN** it binds to port 8080 (or PORT env var)
- **AND** logs startup message with slog

#### Scenario: Health check (healthy)
- **WHEN** GET /health is requested
- **AND** database connection is working
- **THEN** return 200 with JSON `{"status": "ok", "database": "connected"}`

#### Scenario: Health check (unhealthy)
- **WHEN** GET /health is requested
- **AND** database connection fails
- **THEN** return 503 with JSON `{"status": "degraded", "database": "disconnected"}`

#### Scenario: CORS handling
- **WHEN** request includes Origin header
- **THEN** respond with appropriate CORS headers based on allowed origins
- **AND** allow localhost:5173 in development mode

---

### Requirement: Authentication Middleware

The API SHALL validate Auth0 JWT tokens stored in httpOnly cookies for protected endpoints.

#### Scenario: Valid token in cookie
- **WHEN** request includes valid auth_token httpOnly cookie
- **AND** token is valid Auth0 JWT for configured domain/audience
- **THEN** allow request to proceed
- **AND** populate request context with user claims including roles

#### Scenario: Missing token on protected endpoint
- **WHEN** request to protected endpoint lacks auth_token cookie
- **THEN** return 401 Unauthorized with JSON error

#### Scenario: Invalid token
- **WHEN** request includes invalid or expired JWT in cookie
- **THEN** return 401 Unauthorized with JSON error

#### Scenario: Public endpoints
- **WHEN** GET request to read-only endpoints (list, search, get by ID)
- **THEN** allow without authentication

#### Scenario: Super admin required
- **WHEN** request to super-admin-only endpoint (taxonomy, places, filter fields)
- **AND** user token does not include "superadmin" role
- **THEN** return 403 Forbidden with JSON error

---

### Requirement: Token Refresh Endpoint

The API SHALL provide an endpoint to refresh expired tokens.

#### Scenario: Refresh valid token
- **WHEN** POST /api/v2/auth/refresh with valid refresh token in cookie
- **THEN** issue new access token
- **AND** set new httpOnly cookie with refreshed token

#### Scenario: Refresh invalid token
- **WHEN** POST /api/v2/auth/refresh with invalid or missing refresh token
- **THEN** return 401 Unauthorized

---

### Requirement: Logout Endpoint

The API SHALL provide an endpoint to log out users.

#### Scenario: Logout
- **WHEN** POST /api/v2/auth/logout
- **THEN** clear the auth_token cookie by setting expired cookie
- **AND** return 200 OK

---

### Requirement: Current User Endpoint

The API SHALL provide an endpoint to retrieve current user information.

#### Scenario: Get current user
- **WHEN** GET /api/v2/me with valid auth cookie
- **THEN** return current user info (id, name, email, roles)

#### Scenario: Not authenticated
- **WHEN** GET /api/v2/me without valid auth cookie
- **THEN** return 401 Unauthorized

---

### Requirement: Gall Endpoints

The API SHALL provide CRUD operations for gall records.

#### Scenario: List galls
- **WHEN** GET /api/v2/galls
- **THEN** return array of all galls with species info
- **AND** include species_name in response
- **AND** include aliases array for each gall

#### Scenario: List galls with pagination
- **WHEN** GET /api/v2/galls?limit={n}&offset={m}
- **THEN** return at most n galls starting from offset m
- **AND** include total count in response metadata

#### Scenario: Search galls
- **WHEN** GET /api/v2/galls?q={term}
- **THEN** return galls where species name matches search term (LIKE)

#### Scenario: Get gall by ID
- **WHEN** GET /api/v2/galls/{id}
- **THEN** return single gall with full details
- **OR** return 404 if not found

#### Scenario: Create gall (authenticated)
- **WHEN** POST /api/v2/galls with valid auth and JSON body
- **THEN** create new gall record
- **AND** return 201 with created gall

#### Scenario: Update gall (authenticated)
- **WHEN** PUT /api/v2/galls/{id} with valid auth and JSON body
- **THEN** update existing gall record
- **AND** return 200 with updated gall
- **OR** return 404 if not found

#### Scenario: Delete gall (authenticated)
- **WHEN** DELETE /api/v2/galls/{id} with valid auth
- **THEN** delete gall record
- **AND** return 204 No Content
- **OR** return 404 if not found

---

### Requirement: Host Endpoints

The API SHALL provide CRUD operations for host plant records.

#### Scenario: List hosts
- **WHEN** GET /api/v2/hosts
- **THEN** return array of all hosts

#### Scenario: Search hosts
- **WHEN** GET /api/v2/hosts?q={term}
- **THEN** return hosts where name matches search term

#### Scenario: Simple host list
- **WHEN** GET /api/v2/hosts?simple=true
- **THEN** return simplified host list (id, name only)

#### Scenario: Get host by ID
- **WHEN** GET /api/v2/hosts/{id}
- **THEN** return single host with full details

#### Scenario: Upsert host (authenticated)
- **WHEN** POST/PUT /api/v2/hosts with valid auth and JSON body
- **THEN** create or update host record
- **AND** aliases included in request payload are saved

#### Scenario: Delete host (authenticated)
- **WHEN** DELETE /api/v2/hosts/{id} with valid auth
- **THEN** delete host record permanently
- **AND** return 204 No Content
- **OR** return 404 if not found

---

### Requirement: Taxonomy Endpoints

The API SHALL provide CRUD operations for taxonomy hierarchy (family, genus, section).

#### Scenario: Get taxonomy by species
- **WHEN** GET /api/v2/taxonomy?speciesid={id}
- **THEN** return taxonomy chain for species

#### Scenario: List families
- **WHEN** GET /api/v2/taxonomy/families
- **THEN** return array of all families

#### Scenario: Search families
- **WHEN** GET /api/v2/taxonomy/families?q={term}
- **THEN** return families matching search term

#### Scenario: Get family by ID
- **WHEN** GET /api/v2/taxonomy/families/{id}
- **THEN** return single family with associated genera

#### Scenario: Upsert family (authenticated)
- **WHEN** POST/PUT /api/v2/taxonomy/families with valid auth
- **THEN** create or update family record

#### Scenario: Delete family (authenticated)
- **WHEN** DELETE /api/v2/taxonomy/families/{id} with valid auth
- **THEN** delete family if no associated genera exist
- **OR** return 400 if family has genera

#### Scenario: List genera
- **WHEN** GET /api/v2/taxonomy/genera
- **THEN** return array of all genera

#### Scenario: Move genus (authenticated)
- **WHEN** POST /api/v2/taxonomy/genera/move with valid auth
- **AND** body contains {genusId, targetFamilyId}
- **THEN** move genus to new family

#### Scenario: List sections
- **WHEN** GET /api/v2/taxonomy/sections
- **THEN** return array of all sections

#### Scenario: Delete section (authenticated)
- **WHEN** DELETE /api/v2/taxonomy/sections/{id} with valid auth
- **THEN** delete section record

---

### Requirement: Source Endpoints

The API SHALL provide CRUD operations for scientific source/reference records.

#### Scenario: List sources
- **WHEN** GET /api/v2/sources
- **THEN** return array of all sources

#### Scenario: Search sources
- **WHEN** GET /api/v2/sources?q={term}
- **THEN** return sources where author or title matches

#### Scenario: Sources by species
- **WHEN** GET /api/v2/sources?speciesid={id}
- **THEN** return sources associated with species

#### Scenario: Get source by ID
- **WHEN** GET /api/v2/sources/{id}
- **THEN** return single source

#### Scenario: Get source by title
- **WHEN** GET /api/v2/sources/by-title/{title}
- **THEN** return source with exact title match

#### Scenario: CRUD operations (authenticated)
- **WHEN** POST/PUT/DELETE /api/v2/sources with valid auth
- **THEN** create, update, or delete source record

---

### Requirement: Glossary Endpoints

The API SHALL provide CRUD operations for glossary term records.

#### Scenario: List glossary
- **WHEN** GET /api/v2/glossary
- **THEN** return array of all glossary entries

#### Scenario: Search glossary
- **WHEN** GET /api/v2/glossary?q={term}
- **THEN** return entries where word or definition matches

#### Scenario: Get by word
- **WHEN** GET /api/v2/glossary/by-word/{word}
- **THEN** return glossary entry with exact word match

#### Scenario: CRUD operations (authenticated)
- **WHEN** POST/PUT/DELETE /api/v2/glossary with valid auth
- **THEN** create, update, or delete glossary entry

---

### Requirement: Place Endpoints

The API SHALL provide CRUD operations for geographic place records.

#### Scenario: List places
- **WHEN** GET /api/v2/places
- **THEN** return array of all places

#### Scenario: Search places
- **WHEN** GET /api/v2/places?q={term}
- **THEN** return places where name or code matches

#### Scenario: Get by name
- **WHEN** GET /api/v2/places/by-name/{name}
- **THEN** return place with exact name match

#### Scenario: CRUD operations (authenticated)
- **WHEN** POST/PUT/DELETE /api/v2/places with valid auth
- **THEN** create, update, or delete place record

---

### Requirement: GallHost Relationship Endpoints

The API SHALL provide operations for gall-to-host associations.

#### Scenario: List hosts for gall
- **WHEN** GET /api/v2/gall-hosts?gallid={id}
- **THEN** return array of hosts associated with gall

#### Scenario: Create association (authenticated)
- **WHEN** POST /api/v2/gall-hosts with valid auth
- **AND** body contains {gallId, hostId}
- **THEN** create gall-host association

#### Scenario: Delete association (authenticated)
- **WHEN** DELETE /api/v2/gall-hosts with valid auth
- **AND** body contains {gallId, hostId}
- **THEN** remove gall-host association
- **AND** return 204 No Content
- **OR** return 404 if association not found

---

### Requirement: SpeciesSource Relationship Endpoints

The API SHALL provide operations for species-to-source associations.

#### Scenario: List sources for species
- **WHEN** GET /api/v2/species-sources?speciesid={id}
- **THEN** return array of source associations

#### Scenario: Get specific association
- **WHEN** GET /api/v2/species-sources?speciesid={id}&sourceid={id}
- **THEN** return single association with details

#### Scenario: Create association (authenticated)
- **WHEN** POST /api/v2/species-sources with valid auth
- **AND** body contains {speciesId, sourceId, ...details}
- **THEN** create species-source association

#### Scenario: Update association (authenticated)
- **WHEN** PUT /api/v2/species-sources with valid auth
- **AND** body contains {speciesId, sourceId, ...details}
- **THEN** update existing association details

#### Scenario: Delete association (authenticated)
- **WHEN** DELETE /api/v2/species-sources with valid auth
- **AND** body contains {speciesId, sourceId}
- **THEN** remove species-source association
- **AND** return 204 No Content

---

### Requirement: FilterField Endpoints

The API SHALL provide operations for filter field configuration.

#### Scenario: List field types
- **WHEN** GET /api/v2/filter-fields
- **THEN** return array of filter field type names

#### Scenario: List values by type
- **WHEN** GET /api/v2/filter-fields/{type}
- **THEN** return array of filter values for that type

#### Scenario: CRUD operations (authenticated)
- **WHEN** POST/PUT/DELETE /api/v2/filter-fields with valid auth
- **THEN** create, update, or delete filter field value

---

### Requirement: Global Search Endpoint

The API SHALL provide unified search across multiple domains.

#### Scenario: Global search
- **WHEN** GET /api/v2/search?q={term}
- **THEN** return grouped results: `{ species, glossary, sources, taxa, places }`
- **AND** species includes galls and plants with their aliases
- **AND** taxa includes genus, section, and family matches
- **AND** results within each group sorted alphabetically by name

---

### Requirement: OpenAPI Documentation

The API SHALL provide interactive API documentation.

#### Scenario: Swagger UI
- **WHEN** GET /api/docs
- **THEN** serve Swagger UI with complete API specification

#### Scenario: OpenAPI spec
- **WHEN** GET /api/openapi.yaml
- **THEN** return OpenAPI 3.0 specification

---

### Requirement: Error Response Format

The API SHALL return consistent error responses.

#### Scenario: Error response structure
- **WHEN** any error occurs
- **THEN** return JSON with structure: `{"error": {"code": "...", "message": "..."}}`
- **AND** appropriate HTTP status code

#### Scenario: Not found
- **WHEN** resource does not exist
- **THEN** return 404 with code "NOT_FOUND"

#### Scenario: Unauthorized
- **WHEN** authentication required but missing/invalid
- **THEN** return 401 with code "UNAUTHORIZED"

#### Scenario: Bad request
- **WHEN** request validation fails
- **THEN** return 400 with code "BAD_REQUEST" and descriptive message

---

### Requirement: Structured Logging

The API SHALL log all requests with structured context.

#### Scenario: Request logging
- **WHEN** any HTTP request completes
- **THEN** log with: request_id, method, path, status, duration_ms
- **AND** user_id if authenticated

#### Scenario: Error logging
- **WHEN** error occurs during request handling
- **THEN** log error with context at ERROR level
- **AND** include request_id for correlation

---

### Requirement: Input Validation

The API SHALL validate all input and enforce constraints matching v1 behavior.

#### Scenario: Required fields
- **WHEN** request body missing required fields
- **THEN** return 400 Bad Request with field-specific error message

#### Scenario: Unique constraints
- **WHEN** create/update would violate unique constraint (e.g., duplicate glossary word)
- **THEN** return 400 Bad Request with constraint violation message

#### Scenario: Referential integrity
- **WHEN** delete would orphan related records (e.g., delete family with genera)
- **THEN** return 400 Bad Request explaining the constraint

#### Scenario: Validation parity
- **WHEN** implementing validation for any entity
- **THEN** validation rules MUST match v1 behavior
- **AND** implementer should review corresponding v1 admin page for constraints

---

### Requirement: Audit Fields

All entities SHALL include audit tracking fields.

#### Scenario: Create record
- **WHEN** any entity is created
- **THEN** set `created_at` to current timestamp
- **AND** set `created_by` to authenticated user ID
- **AND** set `updated_at` to current timestamp
- **AND** set `updated_by` to authenticated user ID

#### Scenario: Update record
- **WHEN** any entity is updated
- **THEN** set `updated_at` to current timestamp
- **AND** set `updated_by` to authenticated user ID
- **AND** preserve original `created_at` and `created_by`

---

### Requirement: Pagination

List endpoints SHALL support optional pagination.

#### Scenario: Default behavior (no pagination)
- **WHEN** GET request to list endpoint without limit/offset params
- **THEN** return all results (v1 parity)

#### Scenario: Paginated request
- **WHEN** GET request includes `?limit={n}&offset={m}`
- **THEN** return at most n results starting from offset m
- **AND** include `total` count in response for pagination UI
- **AND** include `limit` and `offset` in response metadata

---

### Requirement: Delete Operations

All delete operations SHALL be hard deletes.

#### Scenario: Delete entity
- **WHEN** DELETE request for any entity with valid auth
- **THEN** permanently remove record from database
- **AND** cascade delete related records where referential integrity requires
