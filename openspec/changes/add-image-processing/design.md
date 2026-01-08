# Design: Add Image Processing System

## Context

Gallformers needs a robust image processing system for the v2 rewrite. The v1 system has reliability issues with async Jimp processing that can fail silently. Images come from two sources:
1. Direct uploads (user's own photos)
2. iNaturalist observations (with proper attribution)

### Current State

- **S3 Bucket**: `gallformers` (dev: `gallformers-dev`) in `us-east-2`
- **CDN**: CloudFront at `https://dhz6u1p7t6okk.cloudfront.net`
- **Image Count**: 6,531 images across 2,522 species
- **Size Variants**: 5 sizes embedded in path names (`_original`, `_small`, `_medium`, `_large`, `_xlarge`)
- **Processing**: Server-side Jimp (async fire-and-forget)
- **Path Pattern**: `gall/{species_id}/{species_id}_{timestamp}_original.{ext}`

### Stakeholders
- Primary user: Project owner (admin, only person uploading images)
- End users: Anyone browsing the site (public read access)

### Constraints
- Must handle ~10,000+ images at maturity
- Must preserve originals for future re-processing
- Mobile-friendly gallery experience required
- Migration must not disrupt current v1 operation during transition

## Goals / Non-Goals

### Goals
- Enable reliable async image processing with status tracking
- Optimize images for fast mobile loading (WebP, proper sizing)
- Track full attribution for licensing compliance
- Support iNaturalist import with auto-populated metadata
- Migrate existing images to new optimized format

### Non-Goals
- User-generated content moderation (admin-only uploads)
- Image editing/cropping in-browser
- Image categories/tagging (keep simple - just species association)
- AI-based image recognition
- Video support

## Decisions

### 1. Storage: Keep Existing S3 + Optimize CloudFront

**Decision**: Keep existing S3 bucket `gallformers`, optimize CloudFront configuration.

**Rationale**: Infrastructure already exists and works. Focus on optimizing rather than replacing.

**Changes Needed**:
- Add CORS configuration for presigned URL uploads (see below)
- Ensure proper cache headers (1 year for immutable images)
- Add custom domain if desired (e.g., `images.gallformers.org`)

**S3 CORS Configuration** (for browser-based presigned URL uploads):
```json
{
  "CORSRules": [
    {
      "AllowedOrigins": [
        "https://gallformers.org",
        "https://www.gallformers.org",
        "http://localhost:5173",
        "http://localhost:3000"
      ],
      "AllowedMethods": ["PUT"],
      "AllowedHeaders": ["Content-Type", "Content-Length"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3600
    }
  ]
}
```

**Note**: Update AllowedOrigins when v2 production URL is finalized (e.g., gallformers.fly.dev during staging).

### 2. Image Processing: Lambda (Node.js + Sharp)

**Decision**: Lambda handles all image processing via two trigger paths.

**Path A: Direct Upload (user's own photos)**
```
1. Client -> API: Request upload URL for species X with MIME type (e.g., image/jpeg)
2. API -> Client: Presigned S3 URL (v2/originals/{id}.{ext}) + image ID + status: "pending"
3. Client -> S3: Direct upload (bypasses API server)
4. S3 -> Lambda: Triggered by S3 event on originals/ prefix
5. Lambda: Download from S3, detect actual format via magic bytes
6. Lambda: If format mismatch, rename S3 key to correct extension
7. Lambda: Generate sizes, upload processed versions
8. Lambda -> API: Update status to "complete" (include corrected extension if changed)
9. Client: Polls API until status is "complete"
```

**Path B: URL Import (iNaturalist, etc.)**
```
1. Client -> API: POST /api/v1/images/import-url with image URL + metadata
2. API: Create image record with ID, status "pending"
3. API -> Lambda: Direct invoke via AWS SDK with {imageUrl, imageId, apiBaseUrl}
4. Lambda: Download from URL, generate sizes, upload to S3 using imageId for keys
5. Lambda -> API: Update status to "complete" at {apiBaseUrl}/api/v1/images/{imageId}/status
6. Client: Polls API until status is "complete"
```

**Alternatives Considered**:
- Synchronous server-side: Fly.io has 10MB request limit, CPU-constrained
- Go image libraries: Sharp/libvips significantly faster than pure Go options

**Rationale**: Presigned URLs bypass API size limits. Lambda handles CPU-heavy work and scales automatically. Node.js + Sharp is proven fast (same as oaks project).

### 3. Upload Size Limit

**Decision**: 20MB maximum file size.

**Enforcement**:
- Client-side validation provides fast feedback
- Presigned URL includes `Content-Length` condition (max 20MB)
- Lambda checks `Content-Length` before downloading URLs, rejects >20MB

### 4. Image Sizes

Preserve v1 size tiers for consistency with existing usage patterns:

| Size | Longest Edge | Format | Use Case |
|------|--------------|--------|----------|
| small | 300px | WebP | Search results, grids, thumbnails |
| medium | 800px | WebP | Species page inline, admin preview |
| large | 1200px | WebP | Gallery browsing, lightbox |
| xlarge | 2000px | WebP | Full-size viewing, high-res displays |
| original | As uploaded | Original format | Archival, future reprocessing |

**Note**: HEIC not supported. Users should convert to JPEG before upload.

### 5. S3 Bucket Structure (Flat, New Pattern)

```
gallformers/
├── v2/                      # New v2 images
│   ├── originals/{id}.{ext}
│   ├── small/{id}.webp
│   ├── medium/{id}.webp
│   ├── large/{id}.webp
│   └── xlarge/{id}.webp
└── gall/                    # Legacy v1 images (keep until migration complete)
    └── {species_id}/...
```

**Rationale**: Flat structure by image ID avoids issues with species renaming. `v2/` prefix isolates from v1 images during transition.

### 6. No Image Categories

**Decision**: Keep simple - images associate with species only, no category/type metadata.

**Rationale**: Gallformers doesn't need oak-style identification categories (bark, leaves, etc.). Gall images are generally of the gall itself on the host plant. If categories are needed later, they can be added as a separate proposal.

### 7. iNaturalist Integration

**Decision**: Client-side iNat API integration. Web app calls iNat directly; Lambda downloads images.

**Workflow**:
1. User pastes observation URL (e.g., `https://www.inaturalist.org/observations/123456`)
2. Web app extracts observation ID, calls iNat API directly from browser
3. Web app displays metadata (thumbnail, photographer, license, date, location)
4. For multi-photo observations, user can select which photos to import
5. User confirms, web app sends image URL(s) + metadata to API
6. API invokes Lambda directly with URL; Lambda downloads and processes

**Rate Limits**: iNat allows ~1 req/sec, 10k/day. At our upload volume, no concern.

### 8. Lightbox Library: GLightbox

**Decision**: Use GLightbox (vanilla JS, ~10KB) for full-size image viewing.

**Rationale**: Lightweight, framework-agnostic (works with Svelte 5), well-maintained.

### 9. Database Schema

The v2 images table mirrors v1 schema with additions for async processing and new storage structure:

```sql
CREATE TABLE images (
    id TEXT PRIMARY KEY,           -- UUID (cleaner for async upload flow)
    species_id INTEGER NOT NULL,   -- FK to species.id
    source_id INTEGER,             -- FK to source.id (publications)

    -- V1 fields (preserved)
    path TEXT UNIQUE,              -- Legacy path for migration, nullable for new images
    "default" INTEGER DEFAULT 0,   -- One default per species (quoted - reserved word)
    creator TEXT NOT NULL,         -- Photographer name
    attribution TEXT NOT NULL,     -- Full attribution string
    sourcelink TEXT NOT NULL,      -- URL to original image source
    license TEXT NOT NULL,         -- License type (cc-by, cc-by-nc, cc0, etc.)
    licenselink TEXT NOT NULL,     -- URL to license text
    uploader TEXT NOT NULL,        -- Who uploaded the image
    lastchangedby TEXT NOT NULL,   -- Audit: last editor
    caption TEXT NOT NULL,         -- User notes/description

    -- V2 additions: Processing status
    status TEXT DEFAULT 'complete', -- pending, complete, failed
    error_message TEXT,             -- NULL unless status='failed'; stores failure reason

    -- V2 additions: Migration traceability
    legacy_id INTEGER,              -- v1 image ID for migrated images; NULL for new uploads

    -- V2 additions: iNaturalist import
    source_observation_id TEXT,    -- iNat observation ID if from iNat

    -- V2 additions: New storage structure
    s3_key_original TEXT,          -- v2/originals/{id}.{ext}
    s3_key_small TEXT,             -- v2/small/{id}.webp
    s3_key_medium TEXT,            -- v2/medium/{id}.webp
    s3_key_large TEXT,             -- v2/large/{id}.webp
    s3_key_xlarge TEXT,            -- v2/xlarge/{id}.webp
    original_format TEXT,          -- jpeg, png, webp (detected)
    original_width INTEGER,
    original_height INTEGER,

    -- Timestamps
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE CASCADE,
    FOREIGN KEY (source_id) REFERENCES source(id)
);

CREATE INDEX idx_images_species ON images(species_id);
CREATE INDEX idx_images_default ON images(species_id, "default");
CREATE INDEX idx_images_status ON images(status);
CREATE INDEX idx_images_source ON images(source_id);
```

### 10. API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/species/{id}/images` | List images for species |
| GET | `/api/v1/images/{id}` | Get image metadata (includes status for polling) |
| POST | `/api/v1/images/upload` | Create image record, return presigned S3 URL (requires species_id, mime_type) |
| POST | `/api/v1/images/import-url` | Import from external URL (Lambda processes) |
| PUT | `/api/v1/images/{id}` | Update metadata (caption, default) |
| DELETE | `/api/v1/images/{id}` | Delete image (removes from S3) |
| POST | `/api/v1/images/{id}/default` | Set as default image for species |
| PUT | `/api/v1/images/{id}/status` | Update status (called by Lambda callback) |

**Authentication Requirements**:

| Endpoint | Auth | Notes |
|----------|------|-------|
| `GET /api/v1/species/{id}/images` | Public | Read-only, no auth needed |
| `GET /api/v1/images/{id}` | Public | Needed for status polling during upload |
| `POST /api/v1/images/upload` | Admin (Auth0 JWT) | Creates image record |
| `POST /api/v1/images/import-url` | Admin (Auth0 JWT) | Initiates iNat import |
| `PUT /api/v1/images/{id}` | Admin (Auth0 JWT) | Edit metadata |
| `DELETE /api/v1/images/{id}` | Admin (Auth0 JWT) | Delete image + S3 objects |
| `POST /api/v1/images/{id}/default` | Admin (Auth0 JWT) | Set default for species |
| `PUT /api/v1/images/{id}/status` | Lambda key (X-Lambda-Key) | Internal callback only |

### 11. CloudFront URL Pattern

Images served at: `https://dhz6u1p7t6okk.cloudfront.net/v2/{size}/{id}.{ext}`

Examples:
- `https://dhz6u1p7t6okk.cloudfront.net/v2/small/abc123.webp`
- `https://dhz6u1p7t6okk.cloudfront.net/v2/xlarge/abc123.webp`
- `https://dhz6u1p7t6okk.cloudfront.net/v2/originals/abc123.jpg`

**URL Construction**: Database stores relative S3 keys only (e.g., `v2/small/abc123.webp`). Application constructs full URLs at runtime using `CDN_BASE_URL` environment variable. This allows switching to a custom domain (e.g., `images.gallformers.org`) without database changes.

### 12. Lambda Callback Authentication

**Decision**: Shared API key for Lambda status callbacks.

**Implementation**:
- Generate random API key (32+ characters)
- Store as `LAMBDA_CALLBACK_KEY` in both Lambda env vars and Fly.io secrets
- Lambda includes `X-Lambda-Key` header in status update requests
- Go API validates header against env var; rejects with 401 if mismatch
- Status endpoint (`PUT /api/v1/images/{id}/status`) requires this header

**Rationale**: Simple and sufficient for single Lambda. IAM signature validation adds complexity without meaningful security benefit for this use case.

### 13. Lambda Implementation

- **Runtime**: Node.js 20.x (ARM64 for cost efficiency)
- **Region**: `us-east-2` (same as S3 bucket for performance)
- **Layer**: Pre-built Sharp layer (cbschuld/sharp-aws-lambda-layer)
- **Memory**: 512MB
- **Timeout**: 60 seconds

**Environment Variables**:
| Variable | Description |
|----------|-------------|
| `S3_BUCKET` | Target bucket (`gallformers` or `gallformers-dev`) |
| `S3_REGION` | Bucket region (`us-east-2`) |
| `API_BASE_URL` | API callback URL (e.g., `https://gallformers.fly.dev`) |
| `LAMBDA_CALLBACK_KEY` | Shared secret for API authentication |

**Note**: Full environment variable management (dev/staging/prod configs, secrets rotation) deferred to overall infrastructure planning in `define-v2-foundation`.

**S3 Event Trigger Configuration**:
- Event type: `s3:ObjectCreated:*`
- Prefix filter: `v2/originals/` (outputs go to `v2/small/`, etc., so no infinite loop)
- No suffix filter needed

**Lambda Behavior**:
- **Path A (S3 trigger)**: Receives `event.Records[0].s3` with bucket/key; extracts image ID from key (`v2/originals/{id}.{ext}`)
- **Path B (direct invoke)**: Receives `{imageUrl, imageId, apiBaseUrl}`; uses imageId for S3 keys
- URL download validation: Check `Content-Type` is image/jpeg, image/png, or image/webp
- Download timeout: 30 seconds max
- Format detection: Use Sharp magic bytes; correct extension if mismatched
- Partial failure cleanup: Delete partial uploads before marking status as failed
- Status update: PUT to `{apiBaseUrl}/api/v1/images/{imageId}/status` with 3 retries, exponential backoff
- Include `X-Lambda-Key` header in all API callbacks

## Migration Plan

### Phase 1: Parallel Operation
1. Deploy new Lambda and API endpoints
2. New uploads go through v2 system
3. Legacy images continue serving from v1 paths

### Phase 2: Pre-Migration Inventory
1. **Disable v1 image uploads** - Add maintenance flag to v1 admin to prevent new uploads
2. Create inventory of all v1 images with timestamps
3. Estimate migration duration (test with 100 images, extrapolate)
4. If estimated duration > 1 day:
   - Track v1 image table changes during migration (created_at > inventory timestamp)
   - Run delta migration after main batch completes

### Phase 3: Batch Migration
1. Create migration script that:
   - Reads existing image records from v1 database
   - Generates new UUID for each image (v1 integer ID stored in legacy_id)
   - Downloads best available source (original → xlarge → large → medium → small)
   - Logs warning if falling back from original
   - Uploads to v2 S3 structure with UUID-based keys
   - Triggers Lambda for processing
   - Creates new image record in v2 schema with UUID
   - Maps v1 fields to v2 schema (preserves all metadata except ID)
   - Tracks progress (6,531 images)
2. Run migration in batches (100 at a time) with progress logging
3. If any images were added to v1 during migration, run delta migration
4. Verify migrated images display correctly

### Phase 4: Cutover
1. Re-enable image uploads (now goes to v2)
2. Update all image URLs to v2 format
3. Verify no v1 paths in use
4. Archive v1 image data (don't delete immediately)

### Fallback Strategy for Missing Originals
If original is missing or corrupted, fall back to largest available size:
- Try: original → xlarge → large → medium → small
- Log which images required fallback for audit
- If no sizes available, skip image and log error

### Rollback
- Keep v1 images in S3 until fully verified
- Migration is additive - can roll back by pointing to v1 paths
- Database migration is separate table, doesn't affect v1

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Lambda cold starts | Document expected delay in UI ("Processing may take 10-15 seconds") |
| S3 costs | At 10k images x 4 sizes x ~500KB avg = ~20GB. S3: ~$0.50/month |
| CloudFront costs | At 100GB/month transfer = ~$8.50. Acceptable. |
| iNat API changes | Only use stable v1 endpoints. Store all metadata locally. |
| Migration disruption | Parallel operation ensures v1 continues working during migration |

### 14. Species Deletion and S3 Cleanup

**Decision**: Species DELETE handler explicitly cleans up S3 objects before cascade delete.

**Flow**:
1. Query all images for the species
2. For each image, delete all S3 objects (original + small/medium/large/xlarge)
3. Delete species record (CASCADE handles image DB records)

**Orphan S3 Objects**: Possible sources of orphans:
- Abandoned uploads (presigned URL generated but never used)
- Failed processing (partial uploads cleaned up, but edge cases possible)
- Bugs in delete handler

**Mitigation**: Add optional orphan checker script (deferred) that compares S3 objects against database records and reports/cleans up orphans.

## Known Limitations

| Limitation | Rationale |
|------------|-----------|
| Stale "pending" records | If upload abandoned, record stays pending. Manual cleanup if needed. |
| Callback failure leaves pending | If Lambda processes successfully but all API callbacks fail, record stays pending with orphan S3 objects. Rare; admin re-uploads. |
| Duplicate images possible | No content hashing. Admin deletes duplicates manually. |
| Orphan S3 objects | Possible from abandoned uploads or edge cases. Orphan checker script deferred. |

## Open Questions

1. **RESOLVED**: Image categories -> Keep simple, none for now
2. **RESOLVED**: Migration scope -> All 6,531 images
3. **RESOLVED**: iNat integration -> Yes, include
4. **DEFERRED**: Custom CloudFront domain (images.gallformers.org) -> Nice to have, not required
