# V2 Development - Agent Instructions

## Scope

You are working on the **Gallformers V2 rewrite** using Phoenix LiveView. All v2 code lives in this directory (`v2/`).

The v2 stack is:
- **Phoenix 1.8** with LiveView - Full-stack web framework
- **Ecto** with ecto_sqlite3 - Database ORM
- **SQLite** - Database (shared with v1 during development)
- **Tailwind CSS** - Styling (v4 syntax)
- **Fly.io** - Production hosting

## Isolation Rules

- **DO NOT** modify code outside of `v2/`
- **DO NOT** add dependencies on v1 code (`pages/`, `libs/`, `components/`)
- **DO NOT** modify the root `CLAUDE.md`, `package.json`, or other v1 configuration files
- You **MAY** search and read v1 code to understand existing behavior
- You **MAY** use shared resources (`prisma/`, `migrations/`, `ref/`)

## When Replicating v1 Functionality

1. Search/read the relevant v1 code to understand the behavior
2. Document the behavior you need to replicate
3. Implement fresh code in v2
4. **NEVER** modify v1 files

## Development Commands

```bash
# From v2/ directory:
mix setup                  # Install deps, setup DB, build assets
mix phx.server             # Start dev server at http://localhost:4000
mix test                   # Run all tests
mix format                 # Format code
mix credo --strict         # Run code quality checks
mix precommit              # Run all checks before committing

# Database
mix ecto.migrate           # Run migrations
mix ecto.rollback          # Rollback last migration
mix ecto.reset             # Drop, create, migrate, seed

# Assets
mix assets.build           # Build CSS/JS
mix assets.deploy          # Build for production
```

## Database Access

- **Local dev**: Database at `priv/gallformers.sqlite` (not committed to git)
- **Production**: Database on Fly.io volume at `/data/gallformers.sqlite`

### Getting the Database

The database file is not committed to the v2 directory. To get it:

```bash
# Download from S3 (recommended - daily snapshot from production)
make download-db

# Or copy from v1's prisma directory (if available locally)
cp ../prisma/gallformers.sqlite priv/gallformers.sqlite
```

The database must exist at `priv/gallformers.sqlite` before running the app.

### Users Table

The `users` table stores user profile information (managed by `Gallformers.Accounts.User`):

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Primary key |
| `auth0_id` | text | Unique Auth0 identifier (e.g., "auth0\|12345") |
| `display_name` | text | User's chosen display name |
| `nickname` | text | Fallback name from Auth0 |
| `about_me` | text | User's bio/description text |
| `inaturalist_url` | text | Link to iNaturalist profile |
| `social_url` | text | Link to social media |
| `personal_url` | text | Link to personal website |
| `show_on_about` | boolean | Display on About page |
| `inserted_at` | datetime | Creation timestamp |
| `updated_at` | datetime | Last update timestamp |

**Note**: This table contains PII. Public database downloads have these fields sanitized. See [runbooks/database-backup.md](/runbooks/database-backup.md) for details.

## Project Structure

```
v2/
├── CLAUDE.md             # This file - agent instructions
├── mix.exs               # Elixir dependencies and project config
├── mix.lock              # Locked dependency versions
│
├── config/               # Application configuration
│   ├── config.exs        # Shared config
│   ├── dev.exs           # Development config
│   ├── test.exs          # Test config
│   ├── prod.exs          # Production config
│   └── runtime.exs       # Runtime config (secrets, env vars)
│
├── lib/
│   ├── gallformers/      # Business logic (contexts)
│   │   ├── application.ex
│   │   ├── repo.ex       # Ecto Repo
│   │   └── *.ex          # Domain contexts (Species, Hosts, etc.)
│   │
│   └── gallformers_web/  # Web layer
│       ├── components/   # Reusable components
│       │   ├── core_components.ex
│       │   └── layouts.ex
│       ├── controllers/  # Non-LiveView controllers
│       ├── live/         # LiveView modules
│       ├── endpoint.ex   # Phoenix endpoint
│       └── router.ex     # Routes
│
├── priv/
│   ├── repo/migrations/  # Ecto migrations
│   └── static/           # Static assets (compiled)
│
├── assets/
│   ├── css/app.css       # Tailwind styles
│   ├── js/app.js         # JavaScript entry point
│   └── vendor/           # Third-party JS
│
└── test/                 # Tests mirror lib/ structure
```

## Styling (Tailwind CSS)

### Custom Colors

Colors are defined in `assets/css/app.css` via `@theme`. Use these classes:

| Class | Hex | Use for |
|-------|-----|---------|
| `text-gf-maroon` / `bg-gf-maroon` | #661419 | Headings, links, primary accent |
| `text-gf-sky-blue` / `bg-gf-sky-blue` | #c1e0f3 | Header background |
| `text-gf-autumn` / `bg-gf-autumn` | #bc6428 | Subtitles, secondary text |
| `bg-cadet-blue` | #96adc8 | Table headers |
| `bg-canary` | #f8f991 | Selected/highlighted rows |

### Page Styling Patterns

**Page titles:**
```heex
<h1 class="text-2xl font-bold text-gf-maroon mb-4">Page Title</h1>
```

**Links:**
```heex
<.link href="..." class="hover:underline">Link text</.link>
```
Note: Link color is inherited from the base `a` style in `app.css` (Bootstrap blue #0d6efd).

**Cards (v1-style):**
```heex
<div class="bg-white rounded border border-gray-200 shadow-sm">
  <div class="px-4 py-3 border-b border-gray-200">
    <h2 class="text-xl font-semibold text-gf-maroon">Card Title</h2>
  </div>
  <div class="p-4">
    Content here
  </div>
</div>
```

**Page container:**
```heex
<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <!-- page content -->
</div>
```

### Global Styles

Applied automatically via layouts:
- **Font**: League Spartan (falls back to system fonts)
- **Header**: Sky blue background, maroon navigation
- **Footer**: Light gray background, maroon links

---

## Coding Standards

**See [CODING_STANDARDS.md](./CODING_STANDARDS.md)** for general Elixir/Phoenix conventions including:
- Module structure and organization
- Documentation (`@moduledoc`, `@doc`, `@spec`)
- Naming conventions
- Ecto patterns
- LiveView patterns
- Testing conventions

This file documents **project-specific** patterns and gotchas only.

---

## Project-Specific Guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included `:req` (`Req`) library for HTTP requests - **avoid** `:httpoison`, `:tesla`, and `:httpc`

### Authentication & current_scope

This project uses `current_scope` for authentication context. If you encounter errors about missing `current_scope` assign:

1. Ensure routes are in the correct `live_session` (authenticated vs public)
2. Pass `current_scope` to `<Layouts.app>` when required
3. Check router.ex for the proper live_session configuration

---

## Elixir Gotchas

- Elixir lists **do not support index-based access** (`list[0]`). Use `Enum.at/2`, pattern matching, or `hd/1`/`tl/1`
- Block expressions (`if`, `case`, `cond`) return values - you *must* bind the result to use it

---

## Ecto Gotchas

- `Ecto.Schema` fields always use the `:string` type, even for database `:text` columns
- Use `Ecto.Changeset.get_field(changeset, :field)` to access fields - not `changeset.field`
- Generate migrations with: `mix ecto.gen.migration migration_name_using_underscores`

### SQLite Compatibility

This project uses **SQLite** (via ecto_sqlite3), not PostgreSQL. Many Ecto examples online assume PostgreSQL. Always ensure your queries are SQLite-compatible:

**Case-insensitive search (NO `ilike`):**
```elixir
# WRONG - PostgreSQL only
where: ilike(s.name, ^search_term)

# CORRECT - SQLite compatible
search_term = "%#{String.downcase(query)}%"
where: fragment("lower(?) LIKE ?", s.name, ^search_term)
```

**Distinct on column (NO `distinct: column`):**
```elixir
# WRONG - PostgreSQL's DISTINCT ON
distinct: t.id

# CORRECT - SQLite compatible (use group_by instead)
group_by: [t.id, t.name]
```

**Other SQLite limitations to watch for:**
- No `RETURNING` clause in older SQLite versions (ecto_sqlite3 handles this)
- No `FULL OUTER JOIN` - use `LEFT JOIN` with `UNION`
- Limited `ALTER TABLE` support - some migrations may need workarounds
- No native `BOOLEAN` type - stored as integers (0/1)

---

## Test Guidelines

This project uses `LazyHTML` for HTML assertions in tests. See `CODING_STANDARDS.md` for general testing patterns.

---

## Important Notes

- The v1 site (Next.js on Digital Ocean) continues running until cutover
- All v2 work must stay within the `v2/` directory
- Use the beads workflow for issue tracking (`bd` commands)

---

## PubSub / Real-time Updates

The admin interface uses Phoenix PubSub for real-time updates across browser tabs/sessions. This pattern is implemented in context modules and consumed by LiveViews.

### Pattern Overview

**Context module** (e.g., `lib/gallformers/glossary.ex`):

```elixir
# Topic name for this context
@topic "glossary"

# Subscribe to updates (called from LiveView mount)
def subscribe do
  Phoenix.PubSub.subscribe(Gallformers.PubSub, @topic)
end

# Broadcast after successful operations
defp broadcast({:ok, record}, event) do
  Phoenix.PubSub.broadcast(Gallformers.PubSub, @topic, {event, record})
  {:ok, record}
end

defp broadcast({:error, changeset}, _event) do
  {:error, changeset}
end

# Usage in CRUD functions
def create_glossary(attrs) do
  %Glossary{}
  |> Glossary.changeset(attrs)
  |> Repo.insert()
  |> broadcast(:glossary_created)
end
```

**LiveView** (e.g., `lib/gallformers_web/live/admin/glossary_live/index.ex`):

```elixir
def mount(_params, _session, socket) do
  # Subscribe only when connected (not during static render)
  if connected?(socket), do: Glossary.subscribe()
  {:ok, stream(socket, :glossaries, Glossary.list_glossaries())}
end

# Handle broadcasts
def handle_info({:glossary_created, glossary}, socket) do
  {:noreply, stream_insert(socket, :glossaries, glossary, at: 0)}
end

def handle_info({:glossary_updated, glossary}, socket) do
  {:noreply, stream_insert(socket, :glossaries, glossary)}
end

def handle_info({:glossary_deleted, glossary}, socket) do
  {:noreply, stream_delete(socket, :glossaries, glossary)}
end
```

### Contexts with PubSub

| Context | Topic | Events |
|---------|-------|--------|
| `Species` | `"species"` | `:species_created`, `:species_updated`, `:species_deleted` |
| `Hosts` | `"hosts"` | `:host_created`, `:host_updated`, `:host_deleted` |
| `Sources` | `"sources"` | `:source_created`, `:source_updated`, `:source_deleted` |
| `Taxonomy` | `"taxonomy"` | `:taxonomy_created`, `:taxonomy_updated`, `:taxonomy_deleted` |
| `Glossary` | `"glossary"` | `:glossary_created`, `:glossary_updated`, `:glossary_deleted` |
| `Places` | `"places"` | `:place_created`, `:place_updated`, `:place_deleted` |
| `Articles` | `"articles"` | `:article_created`, `:article_updated`, `:article_deleted` |

### Notes

- PubSub is currently used only in Admin LiveViews
- The `Gallformers.PubSub` process is started in `application.ex`
- Always check `connected?(socket)` before subscribing to avoid subscribing during static render

---

## Deployment (Fly.io)

V2 deploys to Fly.io. Configuration is in `fly.toml`.

### Prerequisites

```bash
# Install Fly CLI
brew install flyctl

# Login to Fly
fly auth login
```

### Deploy Commands

```bash
# From v2/ directory:
fly deploy              # Deploy to production
fly status              # Check deployment status
fly logs                # View application logs
fly ssh console         # SSH into running machine
```

### Configuration

Key settings in `fly.toml`:

| Setting | Value | Purpose |
|---------|-------|---------|
| `app` | `gallformers` | App name |
| `primary_region` | `iad` | US East (matches S3 region) |
| `DATABASE_PATH` | `/data/gallformers.sqlite` | SQLite on persistent volume |
| `min_machines_running` | `1` | Always keep one machine running |

### Database Volume

The SQLite database is stored on a persistent Fly volume mounted at `/data`:

```bash
fly volumes list        # List volumes
fly volumes create gallformers_data --region iad --size 1  # Create volume
```

### Migrations

Migrations run automatically on deploy via `docker-entrypoint.sh` (not `release_command`, which doesn't work with SQLite volumes on Fly).

### Secrets

```bash
fly secrets list                          # List secrets
fly secrets set SECRET_KEY_BASE=xxx       # Set a secret
fly secrets set AUTH0_CLIENT_ID=xxx AUTH0_CLIENT_SECRET=xxx AUTH0_DOMAIN=xxx
```

### Health Check

The app exposes `/health` endpoint for Fly's health checks.

### Monitoring

```bash
fly logs                    # Stream logs
fly logs --app gallformers  # Explicit app name
fly status                  # Machine status
fly dashboard               # Open web dashboard
```
