## ADDED Requirements

### Requirement: V2 frontend MUST use pure SPA architecture

The V2 Svelte frontend MUST be built as a pure Single Page Application (SPA) with client-side rendering only. No Server-Side Rendering (SSR) or Static Site Generation (SSG) with prerendered data.

#### Scenario: SvelteKit configuration for SPA mode
- Given the V2 SvelteKit configuration
- When `svelte.config.js` is configured
- Then it MUST use `adapter-static` with `fallback: 'index.html'`
- And it MUST NOT enable prerendering at the layout level
- And the build output MUST be a single-page app shell

#### Scenario: Data fetching happens client-side
- Given a user navigates to a species page (e.g., `/gall/123`)
- When the page loads
- Then the JavaScript bundle loads first
- And then the page fetches data from the API (`/api/species/123`)
- And the page renders the data after the API response
- And no data is baked into the HTML at build time

#### Scenario: Admin sees changes immediately
- Given an admin edits a species record
- When the admin saves the changes
- Then the API updates the database
- And when the admin views the species page
- Then the page fetches fresh data from the API
- And the admin sees their changes without any cache invalidation or rebuild

#### Scenario: Go serves SPA with fallback routing
- Given a user directly navigates to `/gall/123` (deep link)
- When the Go server receives the request
- Then it serves `index.html` (not a 404)
- And SvelteKit's client-side router handles the route
- And the page fetches and displays the correct data

### Requirement: V2 build process MUST NOT require database access

The V2 build process MUST succeed without database connectivity. All data is fetched at runtime, not build time.

#### Scenario: Build without database
- Given the V2 web build is running (`make build` in `v2/web/`)
- When no database is available
- Then the build MUST complete successfully
- And the output is a valid SPA bundle
- And no prerendered data pages are generated

#### Scenario: CI/CD build isolation
- Given the CI/CD pipeline builds V2
- When the web build step runs
- Then it does not need `DATABASE_PATH` configured
- And it does not connect to any database
- And the build produces deployable artifacts

## MODIFIED Requirements

### Requirement: V2 MUST deploy to Fly.io as single app

V2 deployment MUST use Fly.io with a single-app architecture where the Go binary serves both API routes and static Svelte files. The Go server MUST handle SPA fallback routing.

#### Scenario: V2 deployment during development
- Given v2 is in development
- When deploying for testing
- Then deployment uses `fly deploy` from `v2/` directory
- And a single Fly.io app named `gallformers` is deployed
- And the Go binary serves API at `/api/*` routes
- And the Go binary serves static files for known assets (JS, CSS, images)
- And the Go binary serves `index.html` for all other routes (SPA fallback)
- And Fly.io handles SSL, routing, and container management

#### Scenario: V2 cutover to production
- Given v2 is ready for production
- When cutting over from v1
- Then Fly.io resources are scaled up
- And DNS is pointed to Fly.io
- And DO Droplet is deprecated

#### Scenario: Deep link handling
- Given a user shares a link to `https://gallformers.org/gall/123`
- When another user clicks the link
- Then the Go server serves `index.html`
- And the SvelteKit router activates and handles `/gall/123`
- And the page fetches data from `/api/species/123`
- And the user sees the species page
