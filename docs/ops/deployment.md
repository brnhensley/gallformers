## Deployment

Hosted on **Fly.io**. See `runbooks/fly-operations.md` for deploy commands, configuration, and secrets management.

**`fly logs` streams forever** — use `fly logs 2>&1 | timeout 5 cat` for a snapshot, or check request log files via SFTP.

## Application Logging

All application logs (requests, errors, Postgrex events, crash reports) are structured JSON via **LoggerJSON**. In production, logs go to both stdout and a persistent file on the volume.

- **Production file**: `/data/logs/app.log` (size-rotated, 50 MB × 20 files = 1 GB max, gzip compressed)
- **Retrieve**: `fly ssh sftp get /data/logs/app.log`
- **Format**: Structured JSON (LoggerJSON.Formatters.Basic) — includes request metadata (method, path, status, duration, client IP, user agent) alongside app errors and diagnostics
- **Dev**: Human-readable console output (no file logging)

## Fly.io Safety Rules

**Before ANY Fly.io infrastructure operation**, read `runbooks/fly-operations.md` for detailed procedures.

These rules are **non-negotiable** and exist because of a production incident:

- **STOP MEANS STOP** — if the user says "STOP", immediately cease all tool execution. No exceptions.
- **NEVER destroy machines** — causes volume attachment issues and crash loops. Use stop/update/restart.
- **NEVER use `fly machine run`** — bypasses fly.toml config. Always use `fly deploy`.
- **Always check machine state first** — `fly machine list` before SSH/SFTP operations.
- **Always get user approval** before machine stop/start/update operations.
- **Execute ONE step at a time** — verify success before proceeding to the next step.
- **NEVER query the production database directly** — no `fly ssh console` with `rpc` or `eval` for database queries. Use a local dev database and refresh with `make download-db`.

## Database Safety Rules

- **NEVER drop, reset, or recreate the `wcvp` database.** It contains 1.4M+ reference records loaded from Kew Gardens data. Restoring it takes significant time (`make wcvp-restore`). It is NOT managed by Ecto migrations and is NOT in `ecto_repos`.
- **NEVER run `dropdb`, `DROP DATABASE`, or `DROP TABLE` on any database** without explicit user approval.
- **NEVER run `mix ecto.reset`** — use `mix ecto.migrate` to apply pending migrations. If you think a reset is needed, ask first.
- **The only safe database commands** are: `mix ecto.migrate`, `mix ecto.rollback` (with user approval), and read-only queries on the dev database.
