# V1 (Next.js) Documentation

This document contains V1-specific development information. For project-wide context, see the root [CLAUDE.md](../CLAUDE.md).

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

## Directory Structure

```
v1/
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
├── runbooks/           # Operational docs
├── __tests__/          # Test files
└── scripts/            # Build and utility scripts
```

## Development Workflow

### Setup
```bash
cd v1

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
make help          # Show available targets
make prod-build    # Build production Docker image (AMD64)
make local-docker  # Build and run local Docker (ARM64)
make save-image    # Create tar of image for deployment
```

For Apple Silicon Macs, ensure Docker Desktop is configured for `linux/amd64` builds.

## Conventions

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

## Finding Code

- **Species-related logic**: `libs/db/species.ts`
- **Gall-related logic**: `libs/db/gall.ts`
- **Host-related logic**: `libs/db/host.ts`
- **Taxonomy logic**: `libs/db/taxonomy.ts`
- **Search logic**: `libs/db/search.ts`
- **Image handling**: `libs/images/images.ts`
- **API utilities**: `libs/api/`

## Common Tasks

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

## Database Schema

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

- **users** - User profiles (contains PII)
  - Fields: auth0_id, display_name, nickname, profile URLs
  - See [runbooks/database-backup.md](runbooks/database-backup.md) for PII handling

See `prisma/schema.prisma` for complete schema details.

## Deployment

V1 deploys to a Digital Ocean Droplet. See [runbooks/deploy.md](runbooks/deploy.md) for procedures.

### Quick Deploy Steps
1. Build image locally: `make prod-build`
2. Save image: `make save-image`
3. Copy tar to server
4. On server: `sudo make server-deploy`

## Additional Resources

- **ref/contributing.md** - How to contribute reference articles
- **runbooks/deploy.md** - Deployment procedures
- **runbooks/database-backup.md** - Backup and recovery docs
- **prisma/schema.prisma** - Complete database schema
