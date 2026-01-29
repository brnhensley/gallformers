## Work Quality Standards

**CRITICAL**: These standards override any instinct to "move fast" or "show quick progress."

### Investigation Before Action

When fixing bugs, issues, or implementing changes:

1. **STOP** - Do not edit any files yet
2. **Investigate fully** - Find ALL related files, not just the obvious one
   - If fixing icons, list ALL icon files in both locations
   - If fixing a bug, trace ALL code paths involved
   - If migrating something, inventory EVERYTHING that needs to move
3. **Use TodoWrite** - Create a task list of everything that needs to happen
4. **Present findings** - Show me what you found and your proposed approach
5. **Wait for approval** - Only proceed after I confirm the approach

### No Partial Fixes

- Never commit a fix until it is COMPLETE
- If you fixed one file but there might be others, STOP and check
- When in doubt, ask: "Is there anything else related to this?"
- One complete commit is better than three partial ones

### TodoWrite is Mandatory

Use TodoWrite for ANY task that:
- Touches more than 1 file
- Involves copying, migrating, or syncing between locations
- Fixes a bug (investigation tasks + fix tasks)
- Has any ambiguity about scope

The task list must be created BEFORE making any changes.

### Questions Over Assumptions

If you're unsure about scope, ASK. Examples:
- "V1 has 26 icon files - should I copy all of them or just the essential ones?"
- "I found 3 places this bug could originate - should I investigate all of them?"
- "This fix touches the database - should I also check the related API endpoints?"

# Gallformers Project Overview

**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads) for issue tracking. Use `bd` commands instead of markdown TODOs. See AGENTS.md for workflow details.

## What is Gallformers?

Gallformers (gallformers.org) is a comprehensive online database and reference guide for **galls** - abnormal plant growths caused by insects, mites, and other organisms. The site serves as a resource for:

- **Identification**: Helping users identify galls by their characteristics (shape, color, texture, location on host plant)
- **Taxonomy**: Documenting gall-forming species and their relationships
- **Host Plants**: Cataloging which plants are affected by which gall-formers
- **Education**: Providing guides, keys, and reference materials about galls
- **Research**: Serving as a data repository for researchers and naturalists

## Tech Stack

- **Phoenix 1.8** with LiveView - Full-stack web framework
- **Ecto** with ecto_sqlite3 - Database ORM
- **SQLite** - Database
- **Tailwind CSS v4** - Styling
- **Fly.io** - Production hosting

**Legacy V1**: The original Next.js implementation is archived in `v1/`. See [v1/CLAUDE.md](v1/CLAUDE.md) for all V1-specific documentation.

## Project Structure

```
gallformers/
├── assets/              # Frontend assets (JS, CSS, Tailwind)
├── config/              # Phoenix configuration
├── lib/                 # Elixir application code
│   ├── gallformers/     # Business logic (contexts)
│   └── gallformers_web/ # Web layer (LiveViews, controllers)
├── priv/                # Static files, database, migrations
├── test/                # Tests
├── docs/                # Documentation
├── runbooks/            # Operational runbooks
├── services/            # Auxiliary services
│   ├── tileserver-gl/   # Map tile server
│   └── usda_plants/     # USDA plants data (Rust)
├── .beads/              # Beads issue tracking
├── .github/             # CI workflows
└── v1/                  # Legacy Next.js app (see v1/CLAUDE.md)
```

## Development Commands

```bash
mix setup                  # Install deps, setup DB, build assets
mix phx.server             # Start dev server at http://localhost:4000
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

## Before Committing

Always run before committing:

```bash
mix precommit    # Runs format, credo, and tests
make ci          # Full CI check (format, compile, credo, test, assets, dialyzer)
```

Do not commit until precommit passes.

**CRITICAL: Always compile with `--warnings-as-errors`**. When verifying code changes, NEVER use plain `mix compile` - always use `mix compile --warnings-as-errors` or run `mix precommit`. CI enforces warnings-as-errors, so skipping this locally will cause CI failures.

## Testing

### Test Database

Tests use a **separate test database** (`priv/gallformers_test.sqlite`) that is:
- **Schema-only**: Created from `priv/repo/structure.sql` (no production data)
- **Minimal seed data**: Loaded from `priv/repo/test_seeds.sql` with just enough data for tests
- **Rebuilt fresh**: `make test` rebuilds the test DB before each run

```bash
make test-db               # Rebuild test database manually (rarely needed)
```

**Important**: The test database uses `journal_mode: :delete` (not WAL) to prevent sandbox
rollbacks from affecting the main database file.

### Unit & Integration Tests

```bash
make test                  # Rebuild test DB + run tests (excludes E2E)
mix test                   # Run tests without rebuilding DB
mix test test/gallformers  # Run only context tests
mix test path/to/test.exs  # Run specific test file
mix test path/to/test.exs:42  # Run specific test at line 42
```

Tests use Ecto's SQL Sandbox for isolation - each test runs in a transaction that's rolled back.

### E2E Tests (Browser-based)

E2E tests use [Wallaby](https://github.com/elixir-wallaby/wallaby) with Chrome. They're **excluded
from regular test runs** to keep the dev loop fast.

**Prerequisites**: ChromeDriver is required.
```bash
# macOS
brew install chromedriver
xattr -d com.apple.quarantine $(which chromedriver)  # Allow through Gatekeeper

# Verify installation
make e2e-setup
```

**Running E2E tests**:
```bash
make e2e                   # Run all E2E tests
make e2e-changed           # Run only tests affected by changed files (smart)
make e2e-public            # Public pages only
make e2e-search            # Search functionality only
make e2e-browse            # Species/hosts/galls browsing only
make e2e-admin             # Admin pages only
make e2e-auth              # Authentication flows only
```

**Debugging**:
```bash
make e2e-headed            # Run with visible browser
E2E_HEADED=1 make e2e-admin  # Specific area with visible browser
```

### Test Organization

| Directory | Type | Coverage |
|-----------|------|----------|
| `test/gallformers/` | Unit | Context modules (business logic) |
| `test/gallformers_web/live/` | Integration | LiveView tests (no browser) |
| `test/gallformers_web/controllers/` | Integration | Controller/API tests |
| `test/e2e/public/` | E2E | Home, about, glossary, resources |
| `test/e2e/search/` | E2E | Global search, ID tool |
| `test/e2e/browse/` | E2E | Species, hosts, galls detail pages |
| `test/e2e/admin/` | E2E | Admin dashboard, CRUD operations |
| `test/e2e/auth/` | E2E | Login, logout, protected routes |

### Writing E2E Tests

All E2E tests must be tagged with `@moduletag :e2e` plus an area tag. See
`test/support/e2e_case.ex` for full documentation.

```elixir
defmodule GallformersWeb.E2E.MyTest do
  use GallformersWeb.E2ECase

  @moduletag :e2e
  @moduletag :e2e_public  # Area tag

  test "page loads", %{session: session} do
    session
    |> visit("/")
    |> assert_has(Query.css("body.phx-connected"))
  end
end
```

## Database

- **Local dev**: `priv/gallformers.sqlite` (not committed)
- **Production**: Fly.io volume at `/data/gallformers.sqlite`

### Getting the Database

```bash
# Download from S3 (recommended - daily snapshot from production)
make download-db
```

## Key Domain Concepts

### Galls
A gall is an abnormal plant growth induced by another organism. Each gall entry includes:
- **Morphology**: shape, color, texture, alignment, walls, cells
- **Location**: where on the host plant (leaf, stem, bud, etc.)
- **Seasonality**: when the gall appears
- **Detachability**: whether it falls off the plant
- **Hosts**: which plants it affects

### Species
Gall-forming organisms, primarily:
- Insects (wasps, midges, aphids, flies, etc.)
- Mites
- Other organisms (fungi, bacteria, nematodes)

Each species has:
- **Taxonomy**: family, genus, species name
- **Abundance**: how common it is
- **Range**: geographic distribution
- **Aliases**: alternative names
- **Sources**: references to scientific literature

### Hosts
Plants that galls form on, with:
- **Taxonomy**: family, genus, species
- **Common names**
- **Geographic range**
- **Associated galls**

### Taxonomy
Standard biological classification:
- Kingdom -> Phylum -> Class -> Order -> Family -> Genus -> Species
- The database tracks all taxonomic levels and relationships

## Coding Standards

See **[CODING_STANDARDS.md](./CODING_STANDARDS.md)** for Elixir/Phoenix conventions.

## Reusable UI Components

**CRITICAL**: This project has reusable UI components that MUST be used. Do NOT implement custom/inline versions of these components. Creating new UI patterns requires explicit user approval.

### Component Locations

| File | Components |
|------|------------|
| `lib/gallformers_web/components/core_components.ex` | `.button`, `.input`, `.modal`, `.table`, `.icon`, `.flash`, `.header`, `.back`, `.list`, `.simple_form`, etc. |
| `lib/gallformers_web/components/form_components.ex` | `.typeahead`, `.multi_select_typeahead`, `.multi_select_dropdown`, `.search_input`, `.toggle`, `.radio_group`, `.file_dropzone`, `.rename_modal` |
| `lib/gallformers_web/components/ui_components.ex` | `.card`, `.loading_spinner`, `.error_message`, `.pagination`, `.alert`, `.info_tip`, `.loading_overlay`, `.skeleton`, `.tabs`, `.see_also` |
| `lib/gallformers_web/components/data_display_components.ex` | `.image_gallery`, `.species_card`, `.host_list`, `.source_citation`, `.taxonomy_breadcrumb`, `.data_completeness_indicator`, `.edit_button`, `.external_links`, `.source_list`, `.range_map`, etc. |

### Key Components

- **`.typeahead`** - Single-select search with keyboard navigation, ARIA accessibility, and the `Typeahead` JS hook. Use for host/genus pickers.
- **`.multi_select_typeahead`** - Multi-select with chips and dropdown. Use for locations, textures, etc.
- **`.input`** - Standard form inputs with labels and error handling.
- **`.card`** - Consistent card styling with title and icon.

### Before Adding UI Code

1. **Check existing components** - Search `core_components.ex` and `form_components.ex`
2. **Check existing pages** - See how similar UI is implemented elsewhere
3. **If no component exists** - ASK before implementing inline. We may want to create a reusable component.

### Never Do This

```elixir
# WRONG - inline typeahead implementation
<input type="text" phx-keyup="search" ... />
<div :if={@results != []}>
  <button :for={item <- @results} phx-click="select" ...>
```

```elixir
# CORRECT - use the component
<.typeahead
  id="host-picker"
  query={@query}
  results={@results}
  selected={@selected}
  search_event="search"
  select_event="select"
  clear_event="clear"
  ...
/>
```

## Schema Field Definitions (In Progress)

Schemas should be the single source of truth for required/optional fields. This ensures:
- Changeset validations and UI `required` attributes stay in sync
- No drift between what the form requires and what the database validates
- Data audit tools can use the same definitions

**Target Pattern (being implemented):**

```elixir
# In schema module
defmodule Gallformers.Sources.Source do
  use Ecto.Schema
  use Gallformers.SchemaFields  # Behavior for field metadata

  @required_fields [:title, :author, :pubyear, :link, :citation, :license]
  @optional_fields [:datacomplete, :licenselink]

  @impl Gallformers.SchemaFields
  def required_fields, do: @required_fields

  def changeset(source, attrs) do
    source
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)  # Uses the attribute
  end
end
```

```elixir
# In form template - auto-derives required from schema
<.input field={@form[:title]} schema={Source} label="Title:" />
```

**Tracking:**
- `gallformers-1j8o` - Field audit (define what's required for each schema)
- `gallformers-uvz3` - Tracer bullet (Source form migration)
- `gallformers-kntb` - Full implementation

**Current State:** Most forms hardcode `required` attributes separately from schema validations. This will be unified once the pattern is proven.

## Styling (Tailwind CSS)

### Custom Colors

Colors are defined in `assets/css/app.css` via `@theme`:

| Class | Hex | Use for |
|-------|-----|---------|
| `text-gf-maroon` / `bg-gf-maroon` | #661419 | Headings, links, primary accent |
| `text-gf-sky-blue` / `bg-gf-sky-blue` | #c1e0f3 | Header background |
| `text-gf-autumn` / `bg-gf-autumn` | #bc6428 | Subtitles, secondary text |
| `bg-cadet-blue` | #96adc8 | Table headers |
| `bg-canary` | #f8f991 | Selected/highlighted rows |

### Icons (Phosphor)

This project uses [Phosphor Icons](https://phosphoricons.com/) with the `ph-` prefix (e.g., `ph-detective`, `ph-trash`).

**IMPORTANT: When using a new icon that hasn't been used before:**

1. Download the SVG from Phosphor's GitHub:
   ```bash
   # Example for "detective" icon:
   curl -o assets/vendor/phosphor/detective.svg \
     https://raw.githubusercontent.com/phosphor-icons/core/main/assets/regular/detective.svg
   ```

2. Rebuild assets:
   ```bash
   mix assets.build
   ```

3. Restart the Phoenix server (hot reload doesn't pick up new icons)

**Existing icons** are in `assets/vendor/phosphor/`. Check there before downloading.

## SQLite Compatibility

This project uses **SQLite** (via ecto_sqlite3), not PostgreSQL. Always ensure queries are SQLite-compatible:

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

## PubSub / Real-time Updates

The admin interface uses Phoenix PubSub for real-time updates. Pattern:

**Context module:**
```elixir
@topic "glossary"

def subscribe do
  Phoenix.PubSub.subscribe(Gallformers.PubSub, @topic)
end

defp broadcast({:ok, record}, event) do
  Phoenix.PubSub.broadcast(Gallformers.PubSub, @topic, {event, record})
  {:ok, record}
end
```

**LiveView:**
```elixir
def mount(_params, _session, socket) do
  if connected?(socket), do: Glossary.subscribe()
  {:ok, stream(socket, :glossaries, Glossary.list_glossaries())}
end

def handle_info({:glossary_created, glossary}, socket) do
  {:noreply, stream_insert(socket, :glossaries, glossary, at: 0)}
end
```

## Deployment (Fly.io)

### Prerequisites

```bash
brew install flyctl
fly auth login
```

### Deploy Commands

```bash
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

### Secrets

```bash
fly secrets list
fly secrets set SECRET_KEY_BASE=xxx
fly secrets set AUTH0_CLIENT_ID=xxx AUTH0_CLIENT_SECRET=xxx AUTH0_DOMAIN=xxx
```

## Beads Workflow

This project uses **Beads** for issue tracking. See the session startup hook for commands.

Key points:
- Use `bd ready` to find available work
- Use `bd create` to create new issues (NOT TodoWrite)
- Run `bd sync` before ending sessions
- Follow the session close protocol for git commits

## Time Tracking with Watchmen

This project uses **watchmen** for time tracking. A hook automatically starts the timer when a Claude Code session begins.

**Session start:**
- Remind the user: "Time tracking has started for this session (watchmen project: iowa)."

**Session end (when user says done for the day):**
1. Check for git commits since session started
2. If commits exist: Generate summary from commit messages, run `watchmen stop -n "<summary>"`
3. If no commits: Ask user what they accomplished, use as note

**Commands:**
- `watchmen status` - Check if timer is running
- `watchmen stop -n "note"` - Stop with a note

## Git Workflow

**Push approval rules:**
| Change Type | Approval Required | Notes |
|-------------|-------------------|-------|
| Beads | No | Daemon auto-syncs to `beads-sync` branch |
| Everything else | **Yes** | Always ask user before pushing |

**Commit messages:** Present tense, imperative mood.

**CRITICAL: Never amend commits.** Always create new commits. Amending pushed commits causes history divergence that requires force-push, which is forbidden.

CRITICAL: Never push to main without explicit approval.

## Multi-Agent Workflow

Multiple agents can work in parallel using separate git worktrees.

**Worktree locations:**
| Worktree | Role |
|----------|------|
| `~/dev/gallformers-code1` | Coding Agent 1 |
| `~/dev/gallformers-code2` | Coding Agent 2 |
| `~/dev/gallformers-bugfix` | Bug Fixer |
| `~/dev/gallformers` | Planner + Coordinator |

**Rules:**
- Stay in your assigned worktree
- Claim issues before working: `bd update <id> --status=in_progress`
- NEVER push to main unless explicitly told to
- Beads uses dedicated `beads-sync` branch (daemon handles sync)

## Project Philosophy

### Content Over Code
The primary value is in the **data** - gall records, images, and reference materials. Code serves to make this accessible.

### Scientific Accuracy
- Backed by scientific sources when possible
- Properly attributed
- Conservative when uncertain (mark species as "undescribed" if needed)

### Accessibility
- Fast and responsive
- Accessible to screen readers
- Usable by casual enthusiasts and professional researchers
- Mobile-friendly

### Community-Driven
- Content contributions welcomed
- Reference articles under Creative Commons
- Open source codebase

## External Services

- **Domain**: gallformers.org, gallformers.com (Namecheap)
- **Hosting**: Fly.io
- **Images**: AWS S3
- **Auth**: Auth0
- **Monitoring**: Fly.io alerts
- **SSL**: Automatic via Fly.io

## AWS Infrastructure

**Region**: `us-east-1` (N. Virginia) - matches Fly.io's `iad` datacenter.

**S3 Buckets:**
| Bucket | Access | Purpose |
|--------|--------|---------|
| `gallformers` | Public | Production images |
| `gallformers-backups` | Mixed | Litestream backups (private) + sanitized DB snapshots (public) |
| `gallformers-full-backups` | Private | Full unsanitized database backups (contains PII) |

**IAM Users:**
- `litestream-gallformers` - Used by Fly.io and GitHub Actions for database backups

See `docs/backup-setup.md` for detailed S3/IAM configuration.

## Getting Help

- Check README.md for setup issues
- Use `bd doctor` to diagnose Beads issues
- See [runbooks/](runbooks/) for operational procedures
