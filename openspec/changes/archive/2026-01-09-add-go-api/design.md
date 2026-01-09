# Design: Go API Server

## Context

Gallformers v2 replaces the Next.js/Prisma backend with a Go API server. This document captures technical decisions that affect all subsequent v2 backend work.

### Reference Implementation

The [oaks project](https://github.com/jeffdc/oaks) provides a working reference:
- `api/` directory structure
- chi router with middleware
- SQLite database access
- Fly.io deployment

Gallformers v2 follows the same patterns with additions for OpenAPI docs and sqlc.

---

## Decision 1: Project Structure

### Chosen: Standard Go Layout

```
v2/api/
├── cmd/
│   └── server/
│       └── main.go           # Entry point
├── internal/
│   ├── handlers/             # HTTP handlers by domain
│   │   ├── gall.go
│   │   ├── host.go
│   │   ├── taxonomy.go
│   │   ├── source.go
│   │   ├── glossary.go
│   │   ├── place.go
│   │   ├── gallhost.go
│   │   ├── speciessource.go
│   │   ├── filterfield.go
│   │   ├── search.go
│   │   └── health.go
│   ├── middleware/           # Auth, logging, CORS
│   │   ├── auth.go
│   │   ├── logging.go
│   │   └── cors.go
│   ├── db/                   # Database layer
│   │   ├── queries/          # sqlc SQL files
│   │   │   ├── gall.sql
│   │   │   ├── host.sql
│   │   │   └── ...
│   │   ├── sqlc.yaml         # sqlc config
│   │   └── generated/        # sqlc output (gitignored)
│   └── models/               # Shared types (if needed beyond sqlc)
├── api/
│   └── openapi.yaml          # OpenAPI 3.0 spec
├── go.mod
├── go.sum
└── Makefile
```

**Rationale**: Matches oaks pattern, standard Go conventions, clear separation of concerns.

---

## Decision 2: Database Access

### Chosen: sqlc

**Why sqlc over alternatives**:

| Option | Pros | Cons |
|--------|------|------|
| **sqlc** | Type-safe, compile-time checked, fast, no runtime reflection | Learning curve, SQL-first |
| Raw SQL | Simple, no dependencies | No type safety, runtime errors |
| GORM | ORM familiarity | Prisma-like abstraction leakage |
| sqlx | Minimal overhead | Still needs manual mapping |

**sqlc workflow**:
1. Write SQL queries in `internal/db/queries/*.sql`
2. Run `sqlc generate`
3. Use generated Go functions in handlers

**Example query file** (`internal/db/queries/gall.sql`):
```sql
-- name: GetGallByID :one
SELECT g.*, s.name as species_name
FROM gall g
JOIN species s ON g.species_id = s.id
WHERE g.id = ?;

-- name: ListGalls :many
SELECT g.*, s.name as species_name
FROM gall g
JOIN species s ON g.species_id = s.id
ORDER BY s.name;

-- name: SearchGalls :many
SELECT g.*, s.name as species_name
FROM gall g
JOIN species s ON g.species_id = s.id
WHERE s.name LIKE ?
ORDER BY s.name;
```

**sqlc.yaml configuration**:
```yaml
version: "2"
sql:
  - engine: "sqlite"
    queries: "internal/db/queries"
    schema: "schema.sql"
    gen:
      go:
        package: "db"
        out: "internal/db/generated"
        emit_json_tags: true
        emit_empty_slices: true
```

**Schema source**: Export directly from SQLite database:
```bash
sqlite3 ../prisma/gallformers.sqlite .schema > internal/db/schema.sql
```
This ensures sqlc sees the exact schema the database uses, avoiding drift from Prisma's DSL.

---

## Decision 3: Router

### Chosen: chi

**Why chi**:
- Lightweight, stdlib `http.Handler` compatible
- Built-in middleware support
- URL parameter extraction
- Used successfully in oaks

**Route registration pattern**:
```go
func RegisterRoutes(r chi.Router, db *sql.DB, queries *db.Queries) {
    r.Route("/api/v2", func(r chi.Router) {
        // Public endpoints
        r.Get("/health", handlers.Health)

        // Domain routes
        r.Route("/galls", func(r chi.Router) {
            r.Get("/", handlers.ListGalls(queries))
            r.Get("/{id}", handlers.GetGall(queries))

            // Protected routes
            r.Group(func(r chi.Router) {
                r.Use(middleware.RequireAuth)
                r.Post("/", handlers.CreateGall(queries))
                r.Put("/{id}", handlers.UpdateGall(queries))
                r.Delete("/{id}", handlers.DeleteGall(queries))
            })
        })
        // ... more domains
    })
}
```

---

## Decision 4: Authentication

### Chosen: Auth0 JWT with Roles Claim

**Current v1 behavior**: NextAuth with Auth0 provider, session stored in JWT, Super Admin via hardcoded allowlist.

**v2 approach**:
- Direct Auth0 JWT validation
- Roles included in JWT claims (configured in Auth0)
- Token stored in **httpOnly cookie** (not localStorage) for security
- `/api/v2/me` endpoint for client to fetch current user info
- User info included in login response body

**Auth0 Configuration Required**:
1. Add "roles" to JWT claims via Auth0 Rules or Actions
2. Define roles: `admin`, `superadmin`
3. Assign roles to users in Auth0 dashboard
4. Use same Auth0 application as v1 (avoids user re-authentication at cutover)

**Token Storage**:
```
# Login flow:
1. Client redirects to Auth0
2. Auth0 redirects back with code
3. API exchanges code for tokens
4. API sets httpOnly cookie with JWT
5. API returns user info in response body

# Subsequent requests:
- Browser automatically sends cookie
- API validates JWT from cookie

# Token refresh:
- POST /api/v2/auth/refresh with valid (but possibly expired) token
- Returns new token if refresh token is valid
- Sets new httpOnly cookie

# Logout:
- POST /api/v2/auth/logout
- Clears the auth_token cookie (no server-side token invalidation)
```

**Cookie Security Settings**:
```go
http.Cookie{
    Name:     "auth_token",
    Value:    token,
    HttpOnly: true,                    // Prevent JS access
    Secure:   env != "development",    // HTTPS only in prod
    SameSite: http.SameSiteLaxMode,    // CSRF protection
    Path:     "/",                     // Available to all paths
    MaxAge:   int(tokenExpiry.Seconds()),
}
```

**Middleware implementation**:
```go
func RequireAuth(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Extract from httpOnly cookie
        cookie, err := r.Cookie("auth_token")
        if err != nil {
            RespondError(w, 401, "UNAUTHORIZED", "No auth token")
            return
        }

        claims, err := validateAuth0JWT(cookie.Value)
        if err != nil {
            RespondError(w, 401, "UNAUTHORIZED", "Invalid token")
            return
        }

        ctx := context.WithValue(r.Context(), userContextKey, claims)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func RequireSuperAdmin(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        claims := r.Context().Value(userContextKey).(*Claims)
        if !slices.Contains(claims.Roles, "superadmin") {
            RespondError(w, 403, "FORBIDDEN", "Super admin required")
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

**Environment variables**:
- `AUTH0_DOMAIN`: e.g., `gallformers.us.auth0.com`
- `AUTH0_AUDIENCE`: e.g., `https://api.gallformers.org`
- `AUTH0_CLIENT_ID`: OAuth client ID
- `AUTH0_CLIENT_SECRET`: OAuth client secret

**Role hierarchy**:
- `admin` - Can create/edit/delete most entities
- `superadmin` - Additional access to taxonomy, places, filter fields, direct species edit

---

## Decision 5: API Versioning

### Chosen: URL Prefix `/api/v2/`

**Rationale**:
- Clear separation from any v1 endpoints
- Easy to add v3 later if needed
- No header-based versioning complexity

**URL structure**:
```
/api/v2/galls
/api/v2/galls/{id}
/api/v2/hosts
/api/v2/taxonomy/families
/api/v2/taxonomy/genera
/api/v2/search?q=...
/api/docs  (OpenAPI UI, unversioned)
/health    (health check, unversioned)
```

---

## Decision 6: OpenAPI Documentation

### Chosen: Hand-written spec + Swagger UI

**Why hand-written over generated**:
- Full control over documentation quality
- No annotation bloat in handlers
- Spec can be reviewed before implementation
- Contract-first development

**Serving Swagger UI**:
- Embed `api/openapi.yaml` in binary
- Serve Swagger UI static files at `/api/docs`
- Use go-swagger or scalar for UI

**Example spec snippet**:
```yaml
openapi: 3.0.3
info:
  title: Gallformers API
  version: 2.0.0
  description: REST API for gallformers.org

paths:
  /api/v2/galls:
    get:
      summary: List or search galls
      parameters:
        - name: q
          in: query
          description: Search term
          schema:
            type: string
      responses:
        '200':
          description: List of galls
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Gall'
```

---

## Decision 7: Error Handling

### Chosen: Consistent JSON Error Response

**Format**:
```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Gall with ID 123 not found"
  }
}
```

**HTTP status codes**:
- 200: Success
- 201: Created
- 400: Bad Request (validation errors)
- 401: Unauthorized (no/invalid token)
- 403: Forbidden (valid token, insufficient permissions)
- 404: Not Found
- 500: Internal Server Error

**Helper functions**:
```go
func RespondJSON(w http.ResponseWriter, status int, data any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(data)
}

func RespondError(w http.ResponseWriter, status int, code, message string) {
    RespondJSON(w, status, map[string]any{
        "error": map[string]string{
            "code":    code,
            "message": message,
        },
    })
}
```

---

## Decision 8: Logging

### Chosen: slog (stdlib)

As specified in `rewrite-gallformers-v2` proposal:
- `log/slog` (Go stdlib, no dependencies)
- JSON format in production, text in development
- Request context: request_id, user_id, method, path, status, duration_ms

**Middleware implementation**:
```go
func Logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        requestID := uuid.New().String()

        ctx := context.WithValue(r.Context(), requestIDKey, requestID)
        ww := &responseWriter{ResponseWriter: w}

        next.ServeHTTP(ww, r.WithContext(ctx))

        slog.Info("request",
            "request_id", requestID,
            "method", r.Method,
            "path", r.URL.Path,
            "status", ww.status,
            "duration_ms", time.Since(start).Milliseconds(),
        )
    })
}
```

---

## Decision 9: Search Implementation

### Chosen: SQL LIKE (defer FTS5)

**Current v1 behavior**: SQL LIKE queries for search.

**v2 approach**: Match current behavior first, evaluate FTS5 post-cutover if performance warrants.

**Rationale**:
- Parity with v1 is the goal
- Dataset is small (~3000 species, ~7000 hosts)
- LIKE is sufficient for current scale
- FTS5 adds complexity (index maintenance, different query syntax)

**Future consideration**: If search latency > 100ms on typical queries, implement FTS5.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| sqlc learning curve | Start with simple queries, reference oaks patterns |
| Auth0 JWT validation | Test thoroughly with v1 tokens before cutover |
| Schema drift | Generate sqlc from same schema v1 uses |
| Missing endpoints | Integration tests compare v1 and v2 responses |

---

## Decision 10: CORS Configuration

### Chosen: Environment Variable

**Configuration**:
```bash
CORS_ORIGINS=http://localhost:5173,https://gallformers.fly.dev,https://gallformers.org
```

**Rationale**:
- Development: `localhost:5173` (Svelte dev server)
- Staging: `gallformers.fly.dev` (v2 on Fly.io before cutover)
- Production: `gallformers.org` (after cutover)

Environment variable allows flexibility without code changes.

---

## Decision 11: SQLite Concurrent Write Handling

### Chosen: WAL Mode with Busy Timeout

**Configuration**:
- Enable WAL (Write-Ahead Logging) mode for better concurrent access
- Set busy timeout to 5 seconds
- Return 503 Service Unavailable if database is still busy after timeout

**Implementation**:
```go
db, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_busy_timeout=5000")
```

**Error handling**: If a write operation fails due to database contention after the busy timeout, return:
```json
{
  "error": {
    "code": "SERVICE_UNAVAILABLE",
    "message": "Database is busy, please retry"
  }
}
```

---

## Decision 12: Graceful Shutdown

### Chosen: 30-Second Timeout

**Behavior**:
- On SIGTERM/SIGINT, stop accepting new connections
- Wait up to 30 seconds for in-flight requests to complete
- Close database connections cleanly
- Exit with appropriate status code

**Implementation**:
```go
func main() {
    srv := &http.Server{Addr: ":8080", Handler: router}

    go func() {
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            slog.Error("server error", "err", err)
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        slog.Error("shutdown error", "err", err)
    }
}
```

---

## Decision 13: Input Validation

### Chosen: Struct Tags with go-playground/validator

**Approach**:
- Use `go-playground/validator` for declarative validation
- Validation rules defined via struct tags
- Consistent error messages for validation failures

**Example**:
```go
type CreateGallRequest struct {
    Name        string `json:"name" validate:"required,min=1,max=255"`
    Description string `json:"description" validate:"max=5000"`
    HostIDs     []int  `json:"host_ids" validate:"required,min=1"`
}

func validateRequest(v *validator.Validate, req any) error {
    if err := v.Struct(req); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }
    return nil
}
```

---

## Decision 14: Request Size Limits

### Chosen: 1MB Maximum

**Configuration**:
- Maximum request body size: 1MB (1,048,576 bytes)
- Applies to all non-image endpoints
- Image uploads handled separately by `add-image-processing` spec

**Implementation**:
```go
func MaxBodySize(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB
        next.ServeHTTP(w, r)
    })
}
```

---

## Decision 15: Audit Fields

### Chosen: Standard Audit Columns

**All entities include**:
- `created_at` - Timestamp when record was created
- `updated_at` - Timestamp when record was last modified
- `created_by` - User ID who created the record
- `updated_by` - User ID who last modified the record

**Implementation**:
- `created_at` and `created_by` set on INSERT
- `updated_at` and `updated_by` set on every UPDATE
- For unauthenticated creates (if any), use system user ID

---

## Decision 16: Delete Strategy

### Chosen: Hard Deletes

**Behavior**:
- All DELETE operations permanently remove records from the database
- No soft-delete / "deleted" flag
- Cascading deletes where referential integrity requires

**Rationale**:
- Simpler implementation
- No accumulation of deleted records
- Backups provide recovery if needed

---

## Decision 17: Pagination

### Chosen: Optional Offset-Based Pagination

**Parameters**:
- `limit` - Maximum number of results to return (optional)
- `offset` - Number of results to skip (optional, default 0)

**Behavior**:
- If neither provided, return all results (v1 parity)
- If `limit` provided, return at most that many results
- Response includes total count for client pagination UI

**Example**:
```
GET /api/v2/galls?limit=50&offset=100
```

**Response format**:
```json
{
  "data": [...],
  "total": 3000,
  "limit": 50,
  "offset": 100
}
```

---

## Decision 18: Species Data Model

### Chosen: Shared Species Table

**Background**: Both galls and hosts are species with shared common data (name, taxonomy, aliases, etc.) plus type-specific attributes.

**Approach**:
- Single `species` table with a `type` field (gall vs plant/host)
- Gall endpoints manage gall-type species
- Host endpoints manage host-type species
- Aliases are nested in gall/host request/response payloads
- Internal implementation handles the shared species data

**Example payload** (gall with aliases):
```json
{
  "id": 123,
  "name": "Quercus lobata gall",
  "aliases": ["Valley oak gall", "Q. lobata gall"],
  "taxonomy_id": 456,
  ...
}
```

---

## Resolved Questions

1. **Auth0 configuration**: ✅ Use same Auth0 application as v1 (avoids user re-authentication at cutover)
