## Database

- **Local dev**: PostgreSQL running locally (see README.md for setup)
- **Production**: Fly Postgres (managed by Fly.io)

### Getting the Database

```bash
# Download a pg_dump from S3 and restore locally (recommended)
make download-db
```

### Table Naming: Use snake_case

Table names use **snake_case** (e.g., `species_source`, `gall_traits`, `host_range`).
**When writing raw SQL in migrations, always check the Ecto schema's
`schema "table_name"` declaration for the correct table name.**
