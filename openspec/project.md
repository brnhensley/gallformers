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

### Frontend
- **Next.js 14** - React-based framework with server-side rendering and static generation
- **React 18** with TypeScript
- **React Bootstrap 2** - UI components and styling
- **Sass** - Custom styling

### Backend
- **Next.js API Routes** - Server-side APIs
- **Prisma** - Database ORM
- **SQLite** - Database (prod DB on mounted volume, dev DB in repo)
- **NextAuth** with Auth0 - Authentication (admin/curation features only)

### Infrastructure
- **Docker** - Containerized deployment
- **Digital Ocean Droplet** - Production hosting
- **AWS S3** - Image storage
- **Litestream** - Database backup/replication
- **Let's Encrypt** - SSL certificates

### Development Tools
- **TypeScript** - Type safety (99%+ coverage required)
- **ESLint + Prettier** - Code quality and formatting
- **Jest + Testing Library** - Testing
- **Husky** - Git hooks
- **Beads** - Issue tracking and workflow management

## Project Conventions

### Code Style
- **TypeScript everywhere**: Maintain 99%+ type coverage (enforced by CI)
- **Strict TypeScript settings**: Use type-safe database queries via Prisma
- **ESLint + Prettier**: Run `yarn lint` before committing
- **Functional programming**: Uses `fp-ts` for functional utilities, `monocle-ts` for immutable data manipulation
- **Prefer immutable patterns**: Avoid mutation where possible
- **Functional components**: Use React hooks, avoid class components

### Architecture Patterns
- **Pages Router**: Routes defined in `pages/` directory
- **API Routes**: Server-side APIs in `pages/api/`
- **Static Generation**: Prefer `getStaticProps` for static pages
- **Server-Side Rendering**: Use `getServerSideProps` only when data must be fetched per-request
- **Data Access Layer**: All database access through Prisma in `libs/db/`
- **Component Structure**: Shared components in `components/`, page-specific can live in page directories
- **Images**: All images stored on AWS S3, processed with Sharp and Jimp

### Testing Strategy
- **Jest + Testing Library** for unit and integration tests
- **Run tests**: `yarn test`
- **Type checking**: `yarn check-types`
- **Type coverage**: `yarn type-coverage` (must maintain 99%+)

### Git Workflow
- **Beads** for issue tracking (use `bd` commands, not markdown TODOs)
- **Husky** for pre-commit hooks
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

See `prisma/schema.prisma` for complete schema.

## Important Constraints

### Technical Constraints
- **99%+ type coverage** - Enforced by CI, non-negotiable
- **SQLite limitations** - Single-writer, no concurrent writes
- **Static generation preferred** - Most pages should be statically generated
- **Docker builds** - Must build for `linux/amd64` (even on Apple Silicon)

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

| Service | Purpose | Account |
|---------|---------|---------|
| **AWS S3** | Image storage | Personal AWS account |
| **Auth0** | Authentication (admin only) | Auth0 account |
| **Digital Ocean** | Production hosting (Droplet) | DO account |
| **Namecheap** | Domain (gallformers.org, .com) | Namecheap |
| **Let's Encrypt** | SSL certificates | Auto-renewal |
| **AWS Lambda** | Downtime monitoring | Personal AWS |
| **CloudWatch + Slack** | Alerts | AWS + Slack |

## Key File Locations

| Purpose | Location |
|---------|----------|
| Species logic | `libs/db/species.ts` |
| Gall logic | `libs/db/gall.ts` |
| Host logic | `libs/db/host.ts` |
| Taxonomy logic | `libs/db/taxonomy.ts` |
| Search logic | `libs/db/search.ts` |
| Image handling | `libs/images/images.ts` |
| API utilities | `libs/api/` |
| Database schema | `prisma/schema.prisma` |
| Reference articles | `ref/` (markdown) |
