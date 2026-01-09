# V2 API Differences from V1

This document describes intentional differences between the V1 (Next.js) and V2 (Go) APIs.

## URL Structure

| V1 Pattern | V2 Pattern | Notes |
|------------|------------|-------|
| `/api/gall` | `/api/v2/galls` | Pluralized, with version prefix |
| `/api/host` | `/api/v2/hosts` | Pluralized, with version prefix |
| `/api/species` | `/api/v2/species` | Added version prefix |
| `/api/taxonomy` | `/api/v2/taxonomy` | Added version prefix |
| `/api/source` | `/api/v2/sources` | Pluralized, with version prefix |
| `/api/glossary` | `/api/v2/glossary` | Added version prefix |
| `/api/place` | `/api/v2/places` | Pluralized, with version prefix |
| `/api/search` | `/api/v2/search` | Added version prefix |
| `/api/filterfield` | `/api/v2/filter-fields` | Renamed, pluralized, hyphenated |
| `/api/gallhost` | `/api/v2/gall-hosts` | Hyphenated for clarity |
| `/api/speciessource` | `/api/v2/species-sources` | Hyphenated for clarity |

## Response Structure

### Pagination

V2 uses a consistent paginated response format across all list endpoints:

```json
{
  "data": [...],
  "total": 123,
  "limit": 10,
  "offset": 0
}
```

**Note**: The species handler (`/api/v2/species`) does not currently support pagination parameters (`limit`, `offset`). It returns all matching results. This may be enhanced in a future update if needed for performance.

### Error Responses

V2 uses a consistent error format:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found"
  }
}
```

V1 error responses varied by endpoint.

## Query Parameters

### Galls

| V1 | V2 | Notes |
|----|-----|-------|
| `?speciesid=123` | `?species_id=123` | Snake case |
| `?q=search` | `?q=search` | Same |
| `?name=exact` | N/A | Use search instead |

### Hosts

| V1 | V2 | Notes |
|----|-----|-------|
| `?simple=true` | `?simple=true` | Same - returns simplified response |
| `?q=search` | `?q=search` | Same |

### Taxonomy

| V1 | V2 | Notes |
|----|-----|-------|
| `?id=speciesId` | `?id=speciesId` | Same - returns FGS for species |
| `?name=genus` | `?name=genus` | Same |
| `?famid=familyId` | `?famid=familyId` | Same - for genera listing |

### Sources

| V1 | V2 | Notes |
|----|-----|-------|
| `?speciesid=123` | `?species_id=123` | Snake case |
| `?q=search` | `?q=search` | Same |

## Authentication

Both V1 and V2 have the same authentication requirements:

- **Public endpoints**: All GET endpoints (read-only access)
- **Protected endpoints**: All POST, PUT, DELETE endpoints require authentication

V2 uses JWT tokens with Auth0, same as V1.

## Data Model Differences

### GallResponse

V2 includes the `gall_id` field explicitly in responses, which was implicitly derived in V1.

### FilterField Types

V2 exposes a `/api/v2/filter-fields` endpoint that lists all available filter field types:
- color
- shape
- location
- texture
- walls
- cells
- alignment
- season
- form
- abundance

V1 had these scattered across multiple endpoints.

## Search Behavior

### Global Search

V2's `/api/v2/search?q=term` returns results from all searchable entities in one response:

```json
{
  "species": [...],
  "glossary": [...],
  "sources": [...],
  "taxa": [...],
  "places": [...]
}
```

V1 required multiple endpoint calls or had different search semantics per endpoint.

## Performance Considerations

V2 improvements:
- Connection pooling for database access
- Optional pagination on most list endpoints (reduces payload size)
- More efficient queries using sqlc-generated code

## Migration Notes

When migrating from V1 to V2:

1. Update all API URL paths to include `/api/v2/` prefix
2. Use pluralized resource names where applicable
3. Use snake_case for query parameters (`species_id` instead of `speciesid`)
4. Update error handling to use the new error response format
5. Take advantage of pagination for list endpoints to reduce payload sizes
