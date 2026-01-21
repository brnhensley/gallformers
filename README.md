# Gallformers

The gallformers.org website - a comprehensive database and reference guide for galls.

## Quick Start

```bash
# Install Elixir dependencies
mix setup

# Start the dev server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) in your browser.

## Prerequisites

- **Elixir 1.19+** and **OTP 28+**
- **Node.js 20+** (for asset compilation)
- **SQLite** (bundled via ecto_sqlite3)

### Installing Elixir

The easiest way on macOS:

```bash
brew install elixir
```

Or use [asdf](https://asdf-vm.com/) for version management:

```bash
asdf plugin add elixir
asdf plugin add erlang
asdf install erlang 28.0
asdf install elixir 1.19.0-otp-28
```

## Database Setup

The database file is not committed. To get started:

```bash
# Download from S3 (recommended - daily snapshot from production)
make download-db

# Or copy from V1 if you have it locally
cp v1/prisma/gallformers.sqlite priv/gallformers.sqlite
```

## Development

```bash
mix phx.server          # Start dev server
mix test                # Run tests
mix format              # Format code
mix credo --strict      # Code quality
mix precommit           # Run all checks (do this before committing)
```

## Project Structure

```
gallformers/
├── lib/                 # Elixir application code
├── assets/              # Frontend (JS, CSS, Tailwind)
├── priv/                # Static files, migrations, database
├── test/                # Tests
├── config/              # Phoenix configuration
├── services/            # Auxiliary services (tileserver, usda_plants)
└── v1/                  # Legacy Next.js app (see v1/README.md)
```

## Legacy V1

The original Next.js implementation is in `v1/`. It runs on Digital Ocean and is in maintenance mode (bug fixes only). See [v1/README.md](v1/README.md) for V1-specific documentation.

## Deployment

Production runs on Fly.io:

```bash
fly deploy              # Deploy to production
fly logs                # View logs
fly status              # Check status
```

See [runbooks/](runbooks/) for operational procedures.

## Backup Strategy

The database is backed up using two complementary approaches:

1. **Litestream** - Continuous replication to S3 (near real-time)
2. **Daily snapshots** - GitHub Actions workflow creating point-in-time snapshots

Daily snapshots are stored in two locations:
- **Public** (`s3://gallformers-backups/public/`) - Sanitized, PII removed
- **Private** (`s3://gallformers-full-backups/`) - Full backup with PII

See [docs/backup-setup.md](docs/backup-setup.md) for complete backup documentation.

## PII Handling

The `users` table contains personally identifiable information:

| Field | Description |
|-------|-------------|
| `auth0_id` | Unique identifier from Auth0 |
| `display_name` | User's chosen display name |
| `nickname` | Fallback name from Auth0 |
| `inaturalist_url` | Link to iNaturalist profile |
| `social_url` | Link to social media |
| `personal_url` | Link to personal website |

**Public database downloads are sanitized** - all PII fields are set to NULL and auth0_id is replaced with a placeholder.

## Authentication

- Public site requires no authentication
- Admin/curation features require Auth0 login
- User management is handled via Auth0 console

## External Resources

- **Production**: [gallformers.org](https://gallformers.org)
- **Images**: AWS S3
- **Auth**: Auth0
- **Domains**: Namecheap (gallformers.org, gallformers.com)

## Contributing

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.
