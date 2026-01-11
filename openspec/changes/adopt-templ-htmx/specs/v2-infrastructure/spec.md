## MODIFIED Requirements

### Requirement: V2 code MUST live in isolated v2/ subdirectory

All v2 code MUST reside in a `v2/` subdirectory within the existing repository. This provides strict isolation from v1 code while allowing access to shared resources.

#### Scenario: Go API and templates code location
- Given the gallformers repository
- When adding Go server code
- Then it MUST be placed under `v2/api/` or `v2/internal/` directory
- And templates MUST be placed under `v2/templates/` directory
- And static assets MUST be placed under `v2/static/` directory

#### Scenario: No separate frontend directory
- Given the V2 architecture uses Go + Templ + HTMX
- When building the frontend
- Then there is NO separate `v2/web/` directory
- And NO Node.js build step is required
- And templates compile with `templ generate` as part of Go build

#### Scenario: Shared resources remain at root
- Given v2 development is in progress
- When accessing shared resources (database, migrations, reference articles)
- Then they remain at their current locations (`prisma/`, `migrations/`, `ref/`)
- And both v1 and v2 code can access them

### Requirement: V2 MUST deploy to Fly.io as single app

V2 deployment MUST use Fly.io with a single-app architecture where the Go binary serves API routes, HTML pages, and static files.

#### Scenario: V2 deployment during development
- Given v2 is in development
- When deploying for testing
- Then deployment uses `fly deploy` from `v2/` directory
- And a single Fly.io app named `gallformers` is deployed
- And the Go binary serves API at `/api/*` routes
- And the Go binary serves HTML pages at public routes
- And the Go binary serves static files at `/static/*`
- And Fly.io handles SSL, routing, and container management

#### Scenario: V2 cutover to production
- Given v2 is ready for production
- When cutting over from v1
- Then Fly.io resources are scaled up
- And DNS is pointed to Fly.io
- And DO Droplet is deprecated

#### Scenario: No Node.js in production
- Given the V2 production deployment
- When the Docker container runs
- Then only the Go binary executes
- And no Node.js runtime is present
- And no npm/pnpm packages are installed in the image

### Requirement: V2 build process MUST use Templ

V2 MUST use Templ for HTML templating, generating type-safe Go code from `.templ` files.

#### Scenario: Template compilation
- Given `.templ` files exist in `v2/templates/`
- When `make build` is run
- Then `templ generate` runs first
- And `.templ` files compile to `_templ.go` files
- And the Go build includes generated template code

#### Scenario: Type-safe templates
- Given a template references a data struct field
- When the field name is misspelled
- Then the Go compiler reports an error
- And the build fails with a clear message

#### Scenario: Template hot reload in development
- Given a developer is running `make dev`
- When a `.templ` file is modified
- Then `templ generate` runs automatically
- And the Go server restarts with updated templates

### Requirement: V2 MUST use HTMX for dynamic interactions

V2 MUST use HTMX for dynamic page updates instead of a JavaScript framework.

#### Scenario: Search with HTMX
- Given a user types in the search box
- When input changes after debounce delay
- Then an HTMX request is sent to `/partials/search`
- And the server returns an HTML fragment
- And HTMX swaps the fragment into the results container

#### Scenario: Filter changes in ID tool
- Given a user changes a filter dropdown in the ID tool
- When the filter value changes
- Then an HTMX request is sent to `/partials/id`
- And the server returns updated results as HTML
- And HTMX swaps the fragment into the results grid

#### Scenario: Admin form submission
- Given an admin submits a species edit form
- When the form is submitted via HTMX
- Then the server validates and saves the data
- And returns either success feedback or error messages as HTML
- And HTMX updates the page accordingly

### Requirement: V2 MUST implement page caching with invalidation

V2 MUST cache rendered HTML pages and invalidate them when underlying data changes.

#### Scenario: Page cache on first request
- Given a user requests `/gall/123` for the first time
- When the page is not in cache
- Then the handler fetches data from the database
- And renders the page with Templ
- And stores the rendered HTML in the cache
- And returns the HTML to the user

#### Scenario: Page cache hit
- Given a user requests `/gall/123` that is cached
- When the cache contains valid HTML for that key
- Then the handler returns the cached HTML directly
- And no database query is executed
- And no template rendering occurs

#### Scenario: Cache invalidation on edit
- Given an admin edits species #123
- When the edit is saved successfully
- Then the cache entry for `/gall/123` is deleted
- And related cache entries (host pages) are also invalidated
- And the next request for `/gall/123` fetches fresh data

#### Scenario: Glossary change invalidates all pages
- Given an admin edits a glossary term
- When the edit is saved successfully
- Then the entire page cache is cleared
- And the glossary linker is rebuilt with new terms

## ADDED Requirements

### Requirement: V2 MUST support JavaScript islands for complex features

V2 MUST allow JavaScript islands for features that require rich client-side interactivity.

#### Scenario: Range map island
- Given a species page with range data
- When the page renders
- Then a container div is rendered with embedded GeoJSON data
- And a separate JavaScript module loads and initializes the map
- And the map displays the species range

#### Scenario: Island builds
- Given island source code in `v2/islands/`
- When `make build-islands` is run
- Then Vite builds each island to a standalone bundle
- And bundles are output to `v2/static/islands/`

#### Scenario: Islands work without affecting other pages
- Given a page that does not use any islands
- When the page loads
- Then no island JavaScript is loaded
- And the page works with only HTMX (14KB)

### Requirement: V2 MUST render markdown with glossary linking

V2 MUST render markdown content server-side and auto-link glossary terms.

#### Scenario: Markdown rendering
- Given a species description in markdown format
- When the species page is rendered
- Then markdown is converted to HTML using goldmark
- And the HTML is included in the page

#### Scenario: Glossary term linking
- Given a species description contains the word "cynipid"
- When the description is rendered
- And "cynipid" is a term in the glossary
- Then "cynipid" is wrapped in a link to `/glossary#cynipid`

#### Scenario: Case-insensitive glossary matching
- Given a description contains "Cynipid" (capitalized)
- When the description is rendered
- Then the term is linked while preserving original capitalization

## REMOVED Requirements

### Requirement: Svelte frontend code location
- This requirement is removed. V2 no longer uses SvelteKit.
- The `v2/web/` directory structure is eliminated.

### Requirement: Placeholder apps MUST implement health check and static page
- The Svelte placeholder scenario is removed.
- The Go health check scenario remains valid.
