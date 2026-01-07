## ADDED Requirements

### Requirement: Platform Architecture

The Gallformers platform SHALL consist of a Go API server and Svelte frontend, both consuming a shared SQLite database.

#### Scenario: Component separation

- **WHEN** the system is deployed
- **THEN** the Go API server runs as a standalone binary
- **AND** the Svelte frontend serves static files
- **AND** both access the same SQLite database

#### Scenario: API server responsibilities

- **WHEN** the API server handles a request
- **THEN** it SHALL provide REST endpoints for all data operations
- **AND** it SHALL validate Auth0 JWT tokens for protected routes

#### Scenario: Frontend responsibilities

- **WHEN** the frontend serves content
- **THEN** the application SHALL operate as a single-page application
- **AND** all data operations SHALL use the Go API

### Requirement: Database Continuity

The platform SHALL preserve the existing SQLite database schema and data integrity during migration.

#### Scenario: Schema preservation

- **WHEN** migrating to the new platform
- **THEN** all existing tables SHALL retain their structure
- **AND** all foreign key relationships SHALL be preserved
- **AND** all existing data SHALL be migrated without loss

### Requirement: Authentication

The platform SHALL use Auth0 for authentication of admin users.

#### Scenario: Public access

- **WHEN** an unauthenticated user accesses public pages
- **THEN** they SHALL be able to view all public content
- **AND** they SHALL NOT be able to access admin pages
- **AND** they SHALL NOT be able to perform mutations

#### Scenario: Admin authentication

- **WHEN** an admin user authenticates via Auth0
- **THEN** the Go API SHALL validate the JWT token
- **AND** the API SHALL authorize based on user roles

### Requirement: URL Preservation

The platform SHALL preserve all public URLs to maintain SEO and external links.

#### Scenario: Species page URLs

- **WHEN** migrating species pages
- **THEN** `/gall/[id]` routes SHALL resolve to the same content
- **AND** `/host/[id]` routes SHALL resolve to the same content
- **AND** `/family/[id]` routes SHALL resolve to the same content
- **AND** `/genus/[id]` routes SHALL resolve to the same content

#### Scenario: Reference article URLs

- **WHEN** migrating reference articles
- **THEN** `/ref/[slug]` routes SHALL resolve to the same content
- **AND** markdown rendering SHALL produce equivalent HTML

### Requirement: API Documentation

The platform SHALL provide OpenAPI documentation for all API endpoints.

#### Scenario: OpenAPI spec generation

- **WHEN** the API server is built
- **THEN** an OpenAPI 3.0 specification SHALL be generated
- **AND** the spec SHALL document all endpoints, parameters, and responses
- **AND** the spec SHALL include authentication requirements

#### Scenario: API documentation UI

- **WHEN** a developer accesses `/api/docs`
- **THEN** they SHALL see interactive API documentation
- **AND** they SHALL be able to test endpoints directly

### Requirement: Deployment Simplicity

The platform SHALL deploy as a single binary plus static files.

#### Scenario: Build output

- **WHEN** the platform is built for production
- **THEN** the Go API SHALL compile to a single binary
- **AND** the Svelte frontend SHALL compile to static files
- **AND** no runtime dependencies beyond SQLite SHALL be required

#### Scenario: Deployment process

- **WHEN** deploying to production
- **THEN** the process SHALL copy the binary and static files
- **AND** the process SHALL restart the service
- **AND** the process SHALL NOT require Node.js or npm on the server
