# GitHub Copilot Instructions for Gallformers

## Project Overview

**Gallformers** (gallformers.org) is a comprehensive online database and reference guide for galls - abnormal plant growths caused by insects, mites, and other organisms. The site serves researchers, naturalists, and nature enthusiasts.

**Key Features:**
- Species identification and taxonomy
- Host plant cataloging
- Educational resources and reference articles
- Data repository for research

## Tech Stack

- **Framework**: Phoenix 1.8 with LiveView
- **Database**: PostgreSQL via Ecto/Postgrex (WCVP secondary repo uses SQLite)
- **Styling**: Tailwind CSS v4
- **Auth**: Auth0 (admin features only)
- **Infrastructure**: Fly.io, AWS S3
- **Development**: Elixir, Mix, ExUnit, Credo

## Coding Guidelines

### Code Quality
- Run `mix precommit` before committing (format, credo, tests)
- Use `mix compile --warnings-as-errors` (CI enforces this)
- Follow existing patterns in the codebase
- Keep solutions simple and focused

### Testing
- Write tests for new features
- Use ExUnit with Ecto SQL Sandbox
- Run `make test` before committing
- E2E tests use Wallaby with Chrome

### Git Workflow
- Run `mix precommit` before committing
- Follow the session close protocol (see below)

## Project Structure

```
gallformers/
├── lib/                     # Elixir application code
│   ├── gallformers/        # Business logic (contexts)
│   └── gallformers_web/    # Web layer (LiveViews, controllers)
├── assets/                  # Frontend assets (JS, CSS, Tailwind)
├── config/                  # Phoenix configuration
├── priv/                    # Static files, database, migrations
├── test/                    # Tests
├── docs/                    # Documentation
├── runbooks/               # Operational runbooks
├── services/               # Auxiliary services (tileserver, usda_plants)
└── .github/                # CI workflows
```

## Key Domain Concepts

### Galls
Abnormal plant growths with properties:
- Morphology (shape, color, texture, alignment, walls, cells)
- Location (leaf, stem, bud, etc.)
- Seasonality, detachability
- Host associations

### Species
Gall-forming organisms (insects, mites, etc.) with:
- Taxonomy (family, genus, species)
- Abundance, range, aliases
- Scientific references

### Hosts
Plants that galls form on with:
- Taxonomy
- Common names
- Geographic range
- Associated galls

### Database Schema
See `lib/gallformers/` for Ecto schemas. Key modules:
- `Gallformers.Taxa` - Species, galls, hosts, taxonomy
- `Gallformers.Sources` - Scientific references
- `Gallformers.Content` - Glossary, reference articles
- `Gallformers.Places` - Geographic locations

## Common Development Tasks

### Finding Code
- Contexts: `lib/gallformers/`
- LiveViews: `lib/gallformers_web/live/`
- Components: `lib/gallformers_web/components/`
- Controllers: `lib/gallformers_web/controllers/`

### Adding a Page
1. Create LiveView in `lib/gallformers_web/live/`
2. Add route in `lib/gallformers_web/router.ex`
3. Use existing components from `core_components.ex`

### Database Migrations
1. Run `mix ecto.gen.migration migration_name`
2. Edit the generated migration file
3. Run `mix ecto.migrate`
4. Run `mix ecto.migrate` to apply

## Important Rules

- Run `mix precommit` before committing
- Test before committing
- Do NOT create new files unless necessary (prefer editing existing)

---

**For detailed workflows and advanced features, see [CLAUDE.md](../CLAUDE.md)**
