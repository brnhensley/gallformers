# C2: Container Diagram

This diagram shows the major runtime containers within the Gallformers system.

```mermaid
C4Container
    title Container diagram for Gallformers

    Person(user, "User", "Public or Admin")

    System_Boundary(flyio, "Fly.io (iad region)") {
        Container(phoenix, "Phoenix Web App", "Elixir/Phoenix/LiveView", "Handles requests, serves UI, business logic")
        Container(pubsub, "Phoenix.PubSub", "GenServer", "Real-time pub/sub for LiveView updates")
        Container(auditCache, "Images.AuditCache", "GenServer", "Caches image audit data")
        ContainerDb(sqlite, "SQLite Database", "SQLite", "Stores species, hosts, galls, images, users")
        Container(litestream, "Litestream", "Backup process", "Continuous replication to S3")

        Rel(phoenix, pubsub, "Publishes/subscribes", "In-process")
        Rel(phoenix, auditCache, "Reads/writes cache", "In-process")
        Rel(phoenix, sqlite, "Reads/writes", "Ecto/SQL")
        Rel(litestream, sqlite, "Replicates", "File system")
    }

    System_Ext(auth0, "Auth0", "Authentication")
    System_Ext(s3Images, "AWS S3", "Images bucket")
    System_Ext(s3Backups, "AWS S3", "Backups bucket")

    Rel(user, phoenix, "Uses", "HTTPS")
    Rel(phoenix, auth0, "Validates tokens", "OAuth/HTTPS")
    Rel(phoenix, s3Images, "Reads/writes images", "S3 API")
    Rel(litestream, s3Backups, "Writes backups", "S3 API")
```

## Key Containers

### Phoenix Web Application
The main Elixir/Phoenix application that:
- Serves HTTP requests and LiveView connections
- Contains all business logic (Phoenix contexts)
- Handles authentication and authorization
- Manages image uploads to S3

### SQLite Database
Single-file database (`/data/gallformers.sqlite`) on persistent Fly.io volume that stores:
- Species, hosts, galls, taxonomy
- Images metadata (URLs point to S3)
- User accounts and sessions
- Articles, glossaries, sources

### GenServers

- **Phoenix.PubSub**: Enables real-time updates between LiveViews (e.g., admin changes broadcast to other admins)
- **Images.AuditCache**: Caches image audit data for orphan detection to avoid repeated S3 API calls

### Litestream
Runs alongside Phoenix on the same Fly.io machine, providing:
- Continuous replication of SQLite WAL to S3
- Point-in-time recovery capability
- Sub-second RPO (recovery point objective)

## Infrastructure

All containers run on a single Fly.io machine in the `iad` (US East) region with:
- Persistent volume mounted at `/data` for SQLite database
- Direct connection to AWS S3 in `us-east-1` (same region)
