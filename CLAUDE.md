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

## Technical Stack

### Frontend
- **Next.js 14** (React-based framework) - Server-side rendering and static generation
- **React 18** with TypeScript
- **React Bootstrap 2** - UI components and styling
- **Sass** - Custom styling

### Backend
- **Next.js API Routes** - Server-side APIs
- **Prisma** - Database ORM
- **SQLite** - Database (prod DB on mounted volume, dev DB in repo)
- **NextAuth** with Auth0 - Authentication (for admin/curation features only)

### Infrastructure
- **Docker** - Containerized deployment
- **Digital Ocean Droplet** - Production hosting
- **AWS S3** - Image storage
- **Litestream** - Database backup/replication
- **Let's Encrypt** - SSL certificates
- **AWS Lambda** - Downtime monitoring

### Development Tools
- **TypeScript** - Type safety (99%+ coverage required)
- **ESLint + Prettier** - Code quality and formatting
- **Jest + Testing Library** - Testing
- **Husky** - Git hooks
- **Beads** - Issue tracking and workflow management

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
│   ├── ref/            # Reference articles
│   └── ...
├── components/          # React components
├── layouts/            # Page layout components
├── hooks/              # Custom React hooks
├── libs/               # Core business logic
│   ├── api/           # API utilities
│   ├── db/            # Database access layer
│   ├── images/        # Image processing
│   ├── pages/         # Page helpers (markdown, etc)
│   └── utils/         # General utilities
├── prisma/             # Database schema and migrations
├── migrations/         # SQL migration scripts
├── public/             # Static assets
├── ref/                # Reference articles (markdown)
├── __tests__/          # Test files
├── scripts/            # Build and utility scripts
└── .beads/             # Beads issue tracking data
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
- Kingdom → Phylum → Class → Order → Family → Genus → Species
- The database tracks all taxonomic levels and relationships

## Database Schema Overview

Key tables and relationships:

- **species** - Gall-forming organisms
  - Links to: taxonomy, abundance, aliases, images, sources

- **gall** - Gall characteristics
  - Links to: species (many-to-many), morphology tables (shape, color, etc.)

- **host** - Host plants (uses same taxonomy structure)
  - Links to: species via gallhost table

- **taxonomy** - Taxonomic hierarchy
  - Self-referential (parent-child relationships)
  - Links to: species and hosts

- **image** - Images stored on S3
  - Links to: species, taxonomy, sources

- **source** - Scientific references and citations

See `prisma/schema.prisma` for complete schema details.

## Development Workflow

### Setup
```bash
# Install dependencies
nvm use 20
corepack enable
yarn install

# Generate Prisma client
npx prisma generate

# Run dev server
yarn dev  # http://localhost:3000
```

### Code Quality
```bash
yarn lint              # Run ESLint
yarn check-types       # TypeScript type checking
yarn type-coverage     # Verify 99%+ type coverage
yarn test              # Run tests
```

### Database Changes
1. Create migration script in `migrations/` (numbered sequentially)
2. Add `Up` and `Down` sections to migration
3. Update `prisma/schema.prisma` to match
4. Test migration on a copy of the database
5. Run `yarn migrate` to execute
6. Run `yarn generate` to regenerate Prisma client

**Note**: Temporarily add `better-sqlite3` dependencies for migrations, then remove (see README.md for details)

### Docker Builds
```bash
make build         # Build Docker image
make run-local     # Run locally in Docker
make save-image    # Create tar of image
```

For Apple Silicon Macs, ensure Docker Desktop is configured for `linux/amd64` builds.

## Important Conventions

### Type Safety
- Maintain 99%+ type coverage (enforced by CI)
- Use strict TypeScript settings
- Prefer type-safe database queries via Prisma

### Functional Programming
- Uses `fp-ts` for functional utilities
- Uses `monocle-ts` for immutable data manipulation
- Prefer immutable patterns

### API Design
- APIs are in `pages/api/`
- Use Prisma for all database access
- Validate inputs with Zod or similar
- Return consistent error formats

### Component Structure
- Place shared components in `components/`
- Page-specific components can live in `pages/[page]/`
- Use React Bootstrap components for consistency
- Prefer functional components with hooks

### Images
- All images stored on AWS S3
- Use `libs/images/images.ts` for image utilities
- Images are processed with Sharp and Jimp
- Support for uploading/managing via admin UI

### Authentication
- Public site requires no auth
- Admin/curation features require Auth0 login
- Uses NextAuth for session management
- Authorization logic in API routes

## Common Tasks

### Finding Code
- **Species-related logic**: `libs/db/species.ts`
- **Gall-related logic**: `libs/db/gall.ts`
- **Host-related logic**: `libs/db/host.ts`
- **Taxonomy logic**: `libs/db/taxonomy.ts`
- **Search logic**: `libs/db/search.ts`
- **Image handling**: `libs/images/images.ts`
- **API utilities**: `libs/api/`

### Adding a New Page
1. Create page component in `pages/`
2. Use `getStaticProps` for static generation (preferred)
3. Use `getServerSideProps` only if data must be fetched per-request
4. Add navigation links if needed
5. Ensure responsive design with Bootstrap

### Adding a New API Endpoint
1. Create file in `pages/api/`
2. Export default handler function
3. Use Prisma for database queries
4. Add authentication if needed
5. Handle errors properly
6. Add TypeScript types

### Working with Reference Articles
- Articles are markdown files in `ref/`
- Must include metadata frontmatter (title, date, author, description)
- Rendered with remark/rehype
- Can include glossary terms (auto-linked)

## Beads Workflow

This project uses **Beads** for issue tracking and task management. See the session startup hook for essential commands and workflow.

Key points:
- Use `bd ready` to find available work
- Use `bd create` to create new issues (NOT TodoWrite)
- Run `bd sync` before ending sessions
- Follow the session close protocol for git commits

## Git Workflow

**IMPORTANT: Never checkout `main` directly.** The beads daemon uses a sparse worktree on `main` for auto-sync. Attempting to checkout `main` will fail.

**Push approval rules:**
| Change Type | Approval Required | Notes |
|-------------|-------------------|-------|
| Beads (`.beads/`) | No | Daemon auto-syncs to main |
| Specs (`/openspec/`) | No | But must be manually pushed to main |
| Everything else | **Yes** | Always ask user before pushing to main |

**Workflow for small work (bugs, specs, small features):**
```bash
# Start from origin/main
git fetch origin
git checkout -b fix/descriptive-name origin/main

# Do work, commit
git add <files>
git commit -m "Description"

# For specs: push to main immediately
git push origin fix/descriptive-name:main
git checkout --detach origin/main
git branch -d fix/descriptive-name

# For code: ASK USER FIRST, then push if approved
```

**Workflow for large features:**
```bash
# Create a worktree for the feature
git worktree add ../gallformers-feature-name -b feature-name origin/main

# Work in that directory until complete
# When ready to merge: ASK USER FOR APPROVAL
```

**Specs rule:** When specs in `/openspec/` are modified (even while on a feature branch), ensure they get pushed to main. Create a separate branch from `origin/main` if needed.

**Beads:** The daemon (auto-commit, auto-push, auto-pull) handles all beads sync automatically.

**Commit messages:** Present tense, imperative mood.

## Project Philosophy

### Content Over Code
The primary value is in the **data** - the gall records, images, and reference materials. Code serves to make this accessible and useful.

### Scientific Accuracy
Information should be:
- Backed by scientific sources when possible
- Properly attributed
- Conservative when uncertain (mark species as "undescribed" if needed)

### Accessibility
The site should be:
- Fast and responsive
- Accessible to screen readers and assistive tech
- Usable by both casual nature enthusiasts and professional researchers
- Mobile-friendly

### Community-Driven
- Content contributions are welcomed
- Reference articles published under Creative Commons
- Open source codebase (on GitHub)

## Additional Resources

- **README.md** - Setup and deployment instructions
- **ref/contributing.md** - How to contribute reference articles
- **runbooks/deploy.md** - Deployment procedures
- **prisma/schema.prisma** - Complete database schema
- **package.json** - Dependencies and scripts

## External Services

- **Domain**: gallformers.org, gallformers.com (Namecheap)
- **Hosting**: Digital Ocean Droplet
- **Images**: AWS S3 (personal account)
- **Auth**: Auth0
- **Monitoring**: AWS Lambda + CloudWatch + Slack
- **SSL**: Let's Encrypt (auto-renewal)

## Getting Help

- Check the README.md for setup issues
- Review the codebase documentation in this file
- Use `bd doctor` to diagnose Beads issues
- For deployment questions, see runbooks/deploy.md
