<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

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
├── openspec/            # Change proposal system
└── v1/                  # Legacy Next.js app (see v1/CLAUDE.md)
```

## Development Commands

```bash
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

## Before Committing

Always run before committing:

```bash
mix precommit    # Runs format, credo, and tests
```

Do not commit until precommit passes.

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
