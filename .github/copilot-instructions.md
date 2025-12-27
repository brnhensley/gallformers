# GitHub Copilot Instructions for Gallformers

## Project Overview

**Gallformers** (gallformers.org) is a comprehensive online database and reference guide for galls - abnormal plant growths caused by insects, mites, and other organisms. The site serves researchers, naturalists, and nature enthusiasts.

**Key Features:**
- Species identification and taxonomy
- Host plant cataloging
- Educational resources and reference articles
- Data repository for research

## Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript, React Bootstrap 2, Sass
- **Backend**: Next.js API Routes, Prisma ORM, SQLite
- **Auth**: NextAuth with Auth0 (admin features only)
- **Infrastructure**: Docker, Digital Ocean, AWS S3, Litestream
- **Development**: TypeScript (99%+ coverage), ESLint, Prettier, Jest, Husky
- **Issue Tracking**: Beads (bd)

## Coding Guidelines

### Type Safety
- Maintain 99%+ type coverage (enforced by CI)
- Use strict TypeScript settings
- Prefer type-safe database queries via Prisma
- Run `yarn check-types` and `yarn type-coverage` before committing

### Code Style
- Run `yarn lint` before committing
- Follow existing patterns in the codebase
- Use functional programming patterns (fp-ts, monocle-ts)
- Prefer immutable data structures

### Testing
- Write tests for new features
- Use Jest + Testing Library
- Run `yarn test` before committing
- Test database migrations on a copy first

### Git Workflow
- Always commit `.beads/issues.jsonl` with code changes
- Run `bd sync` at end of work sessions
- Follow the session close protocol (see below)

## Issue Tracking with bd

**CRITICAL**: This project uses **bd (beads)** for ALL task tracking. Do NOT create markdown TODO lists.

### Essential Commands

```bash
# Find work
bd ready --json                    # Unblocked issues
bd list --status open --json       # All open issues

# Create and manage
bd create "Title" -t bug|feature|task -p 0-4 --json
bd create "Subtask" --parent <epic-id> --json  # Hierarchical subtask
bd update <id> --status in_progress --json
bd close <id> --reason "Done" --json

# Search
bd show <id> --json

# Sync (CRITICAL at end of session!)
bd sync  # Force immediate export/commit/push
```

### Workflow

1. **Check ready work**: `bd ready --json`
2. **Claim task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** `bd create "Found bug" -p 1 --deps discovered-from:<parent-id> --json`
5. **Complete**: `bd close <id> --reason "Done" --json`
6. **Sync**: `bd sync` (flushes changes to git immediately)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

## Project Structure

```
gallformers/
├── pages/               # Next.js pages (routes)
│   ├── admin/          # Admin UI for data curation
│   ├── api/            # API routes
│   ├── gall/           # Gall species pages
│   ├── host/           # Host plant pages
│   ├── family/         # Taxonomic family pages
│   ├── genus/          # Taxonomic genus pages
│   └── ref/            # Reference articles
├── components/          # React components
├── layouts/            # Page layout components
├── hooks/              # Custom React hooks
├── libs/               # Core business logic
│   ├── api/           # API utilities
│   ├── db/            # Database access layer
│   ├── images/        # Image processing
│   ├── pages/         # Page helpers
│   └── utils/         # General utilities
├── prisma/             # Database schema and migrations
├── migrations/         # SQL migration scripts
├── public/             # Static assets
├── ref/                # Reference articles (markdown)
├── __tests__/          # Test files
├── scripts/            # Build and utility scripts
└── .beads/             # Beads issue tracking data
    ├── beads.db        # SQLite database (DO NOT COMMIT)
    └── issues.jsonl    # Git-synced issue storage
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
See `prisma/schema.prisma` for complete schema. Key tables:
- `species` - Gall-forming organisms
- `gall` - Gall characteristics
- `host` - Host plants
- `taxonomy` - Taxonomic hierarchy
- `image` - Images (stored on S3)
- `source` - Scientific references

## Common Development Tasks

### Finding Code
- Species logic: `libs/db/species.ts`
- Gall logic: `libs/db/gall.ts`
- Host logic: `libs/db/host.ts`
- Taxonomy: `libs/db/taxonomy.ts`
- Search: `libs/db/search.ts`
- Images: `libs/images/images.ts`
- APIs: `libs/api/`

### Adding a Page
1. Create in `pages/`
2. Use `getStaticProps` (preferred) or `getServerSideProps`
3. Ensure responsive design with Bootstrap

### Adding an API
1. Create in `pages/api/`
2. Use Prisma for DB queries
3. Add auth if needed
4. Add TypeScript types
5. Handle errors properly

### Database Migrations
1. Create numbered script in `migrations/`
2. Add `Up` and `Down` sections
3. Update `prisma/schema.prisma`
4. Test on DB copy
5. Run `yarn migrate`
6. Run `yarn generate`

## Session Close Protocol

**CRITICAL**: Before saying "done" or "complete", you MUST:

```
[ ] 1. git status              (check what changed)
[ ] 2. git add <files>         (stage code changes)
[ ] 3. bd sync                 (commit beads changes)
[ ] 4. git commit -m "..."     (commit code)
[ ] 5. bd sync                 (commit any new beads changes)
[ ] 6. git push                (push to remote)
```

**NEVER skip this.** Work is not done until pushed.

## CLI Help

Run `bd <command> --help` to see all available flags for any command.
For example: `bd create --help` shows `--parent`, `--deps`, `--assignee`, etc.

## Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Run `bd sync` at end of sessions
- ✅ Maintain 99%+ type coverage
- ✅ Test before committing
- ✅ Run `bd <cmd> --help` to discover available flags
- ✅ Commit `.beads/issues.jsonl` with code changes
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT commit `.beads/beads.db`
- ❌ Do NOT skip the session close protocol
- ❌ Do NOT create new files unless necessary (prefer editing existing)

---

**For detailed workflows and advanced features, see [AGENTS.md](../AGENTS.md) and [CLAUDE.md](../CLAUDE.md)**
