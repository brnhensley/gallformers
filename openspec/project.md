# Project Context

## Purpose

**Gallformers** (gallformers.org) is a comprehensive online database and reference guide for **galls** - abnormal plant growths caused by insects, mites, and other organisms. The site serves as a resource for:

- **Identification**: Helping users identify galls by their characteristics (shape, color, texture, location on host plant)
- **Taxonomy**: Documenting gall-forming species and their relationships
- **Host Plants**: Cataloging which plants are affected by which gall-formers
- **Education**: Providing guides, keys, and reference materials about galls
- **Research**: Serving as a data repository for researchers and naturalists

The primary value is in the **data** - the gall records, images, and reference materials. Code serves to make this accessible and useful.

## Tech Stack

### Full-Stack Framework
- **Phoenix 1.8** with LiveView - Elixir-based web framework with real-time capabilities
- **Ecto** - Database ORM with composable queries
- **SQLite** via ecto_sqlite3 - Lightweight, file-based database

### Frontend
- **Phoenix LiveView** - Server-rendered interactive UI without JavaScript
- **Tailwind CSS v4** - Utility-first styling with custom Gallformers theme colors
- **HEEx Templates** - HTML + Elixir templating

### Infrastructure
- **Fly.io** - Production hosting (region: us-east-1/iad)
- **AWS S3** - Image storage
- **Litestream** - Database backup/replication to S3
- **Auth0** - Authentication (admin/curation features only)

### Development Tools
- **Mix** - Elixir build tool and task runner
- **Credo** - Static code analysis and style enforcement
- **ExUnit** - Testing framework
- **Beads** - Issue tracking and workflow management

### Legacy V1
The original Next.js implementation is archived in `v1/`. See `v1/CLAUDE.md` for V1-specific documentation.

## Project Conventions

### Code Style
- **Elixir idioms**: Follow community conventions and OTP patterns
- **mix format**: Auto-format all code before committing
- **Credo strict**: Run `mix credo --strict` for code quality
- **Pattern matching**: Prefer pattern matching over conditionals
- **Pipelines**: Use pipe operator for data transformations
- **Documentation**: Document public functions with `@doc` and `@moduledoc`

### Architecture Patterns
- **Phoenix Contexts**: Business logic organized into bounded contexts (e.g., `Gallformers.Species`, `Gallformers.Hosts`)
- **LiveView**: Interactive pages use LiveView for real-time updates
- **PubSub**: Real-time updates broadcast via Phoenix PubSub
- **Ecto Schemas**: Database schemas in context modules
- **Changesets**: All data validation through Ecto changesets
- **Router**: Routes defined in `lib/gallformers_web/router.ex`
- **Images**: All images stored on AWS S3

### Testing Strategy
- **ExUnit** for unit and integration tests
- **Run tests**: `mix test`
- **Code quality**: `mix credo --strict`
- **Precommit**: `mix precommit` (format + credo + tests)

### Git Workflow
- **Beads** for issue tracking (use `bd` commands, not markdown TODOs)
- **Session close protocol**: Always run `bd sync` and push changes before ending sessions
- **Main branch**: `main`

## Domain Context

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

Each species has taxonomy, abundance, range, aliases, and source references.

### Hosts
Plants that galls form on, with taxonomy, common names, geographic range, and associated galls.

### Taxonomy
Standard biological classification: Kingdom → Phylum → Class → Order → Family → Genus → Species. The database tracks all taxonomic levels and relationships via self-referential parent-child structure.

### Key Database Tables
- **species** - Gall-forming organisms (links to taxonomy, abundance, aliases, images, sources)
- **gall** - Gall characteristics (links to species, morphology tables)
- **host** - Host plants (links to species via gallhost table)
- **taxonomy** - Taxonomic hierarchy (self-referential)
- **image** - Images stored on S3
- **source** - Scientific references and citations

Database migrations are in `priv/repo/migrations/`.

## Important Constraints

### Technical Constraints
- **SQLite compatibility** - No PostgreSQL-specific features (no `ilike`, no `DISTINCT ON`)
- **SQLite limitations** - Single-writer, no concurrent writes
- **Precommit required** - Run `mix precommit` before every commit
- **LiveView patterns** - Use streams for large lists, PubSub for real-time updates

### Content Constraints
- **Scientific accuracy** - Information must be backed by scientific sources when possible
- **Proper attribution** - All content properly attributed
- **Conservative uncertainty** - Mark species as "undescribed" when uncertain

### Accessibility Constraints
- **Fast and responsive** - Optimize for performance
- **Screen reader accessible** - Support assistive technology
- **Mobile-friendly** - Responsive design required
- **Usable by all** - Both casual enthusiasts and professional researchers

## External Dependencies

| Service | Purpose | Notes |
|---------|---------|-------|
| **Fly.io** | Production hosting | Region: iad (US East) |
| **AWS S3** | Image storage | Buckets: gallformers, gallformers-backups |
| **Auth0** | Authentication (admin only) | OAuth2 integration |
| **Namecheap** | Domain (gallformers.org, .com) | DNS managed there |
| **Litestream** | Database replication | Streams to S3 |

## Key File Locations

| Purpose | Location |
|---------|----------|
| Phoenix application | `lib/gallformers/` |
| Web layer (LiveViews) | `lib/gallformers_web/` |
| Router | `lib/gallformers_web/router.ex` |
| Database schemas | `lib/gallformers/` (per context) |
| Migrations | `priv/repo/migrations/` |
| Static assets | `priv/static/` |
| CSS/JS source | `assets/` |
| Tests | `test/` |
| Configuration | `config/` |
| Documentation | `docs/` |
| Runbooks | `runbooks/` |
| Legacy V1 code | `v1/` |

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
└── v1/                  # Legacy Next.js app
```
