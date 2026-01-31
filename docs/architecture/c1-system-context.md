# C1: System Context Diagram

This diagram shows Gallformers as a system and its external dependencies.

```mermaid
C4Context
    title System Context diagram for Gallformers

    Person(publicUser, "Public User", "Browses gall database, uses identification tools")
    Person(admin, "Administrator", "Manages content, uploads images, edits data")

    System(gallformers, "Gallformers", "Phoenix/LiveView application providing gall identification and reference")

    System_Ext(auth0, "Auth0", "Authentication and authorization service")
    System_Ext(s3Images, "AWS S3", "Image storage (gallformers bucket)")
    System_Ext(s3Backups, "AWS S3", "Database backups (gallformers-backups bucket)")

    Rel(publicUser, gallformers, "Uses", "HTTPS")
    Rel(admin, gallformers, "Manages", "HTTPS")
    Rel(admin, auth0, "Authenticates with")
    Rel(gallformers, auth0, "Validates tokens", "HTTPS/OAuth")
    Rel(gallformers, s3Images, "Reads/writes images", "HTTPS/S3 API")
    Rel(gallformers, s3Backups, "Writes backups via Litestream", "HTTPS/S3 API")
```

## Key External Systems

- **Auth0**: Provides OAuth authentication for administrators
- **AWS S3 (gallformers)**: Stores all images referenced by the application
- **AWS S3 (gallformers-backups)**: Stores continuous database backups via Litestream

## Users

- **Public Users**: Can browse all content, search, use identification tools (no login required)
- **Administrators**: Can edit content, upload images, manage data (requires Auth0 login)
