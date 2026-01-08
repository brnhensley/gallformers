# Tasks: Add Image Processing System

## Phase 1: Infrastructure Setup

- [ ] 1.1 Configure S3 bucket CORS for presigned URL uploads from web app
- [ ] 1.2 Verify CloudFront distribution serves v2/ prefix correctly
- [ ] 1.3 Configure CloudFront cache TTL (1 year for v2/ images)
- [ ] 1.4 Create IAM role for Lambda with S3 read/write permissions
- [ ] 1.5 Create IAM user for API server with S3 presigned URL, read permissions, and Lambda invoke permission
- [ ] 1.6 Store API server IAM credentials as Fly.io secrets
- [ ] 1.7 Store LAMBDA_CALLBACK_KEY as Fly.io secret (same value as Lambda env var)
- [ ] 1.8 Configure S3 event trigger for Lambda on `v2/originals/` prefix
- [ ] 1.9 Document Lambda ARN in Fly.io secrets for API server direct invoke

## Phase 2: Database Schema

- [ ] 2.1 Add `images` table migration to v2 API server (uses sqlc, includes status field)
- [ ] 2.2 Create indexes for species_id, is_default, and status queries
- [ ] 2.3 Add image repository/queries in `v2/api/internal/db/`
- [ ] 2.4 Generate sqlc code for image queries

## Phase 3: AWS Lambda - Image Processing (Node.js + Sharp)

- [ ] 3.1 Create Lambda function project (Node.js 20.x, ARM64)
- [ ] 3.2 Configure Sharp Lambda layer (cbschuld/sharp-aws-lambda-layer, pin version ARN)
- [ ] 3.3 Configure Lambda environment variables (S3_BUCKET, S3_REGION, API_BASE_URL, LAMBDA_CALLBACK_KEY)
- [ ] 3.4 Generate Lambda callback API key (32+ chars) for LAMBDA_CALLBACK_KEY
- [ ] 3.5 Set up SAM CLI for local Lambda testing
- [ ] 3.6 Implement two trigger paths: S3 event handler + direct invoke handler
- [ ] 3.7 Implement URL download with Content-Type validation (jpeg, png, webp only)
- [ ] 3.8 Implement Content-Length check before download (reject >20MB)
- [ ] 3.9 Implement download timeout (30 seconds max)
- [ ] 3.10 Implement image download from S3 originals/ (for S3 trigger path)
- [ ] 3.11 Implement format detection using Sharp magic bytes
- [ ] 3.12 Implement S3 key rename if detected format differs from client-provided extension
- [ ] 3.13 Implement resize to 4 sizes using Sharp (300px, 800px, 1200px, 2000px longest edge)
- [ ] 3.14 Implement WebP encoding using Sharp
- [ ] 3.15 Implement upload of processed images to S3
- [ ] 3.16 Implement partial upload cleanup on failure (delete small/medium/large/xlarge before marking failed)
- [ ] 3.17 Implement API callback to update image status (with retry logic, 3 retries exponential backoff)
- [ ] 3.18 Include corrected extension in status update if format was mismatched
- [ ] 3.19 Add error handling and status update on failure (with failure reason)
- [ ] 3.20 Configure Lambda: 512MB memory, 60s timeout
- [ ] 3.21 Deploy Lambda and test with S3 trigger
- [ ] 3.22 Test Lambda with direct invoke (URL import path)

## Phase 4: Go API - Core Image Endpoints

- [ ] 4.1 Add S3 client wrapper in `v2/api/internal/storage/` (presigned URLs with Content-Length condition, 1 hour expiry)
- [ ] 4.2 Add Lambda client wrapper in `v2/api/internal/lambda/` (direct invoke for URL imports)
- [ ] 4.3 Implement `GET /api/v1/species/{id}/images` - list images (sorted: default first, then by created_at)
- [ ] 4.4 Implement `GET /api/v1/images/{id}` - get single image metadata (includes status)
- [ ] 4.5 Implement `POST /api/v1/images/upload` - create record, return presigned URL
- [ ] 4.6 Implement `PUT /api/v1/images/{id}` - update metadata
- [ ] 4.7 Implement `DELETE /api/v1/images/{id}` - delete image and S3 objects
- [ ] 4.8 Implement `POST /api/v1/images/{id}/default` - set default image
- [ ] 4.9 Implement `PUT /api/v1/images/{id}/status` - update status (validate X-Lambda-Key header against LAMBDA_CALLBACK_KEY)
- [ ] 4.10 Update species DELETE handler: query images, delete all S3 objects, then delete species (CASCADE handles DB)
- [ ] 4.11 Update `GET /api/v1/species/{id}` to include images array

## Phase 5: Go API - iNaturalist Import

- [ ] 5.1 Implement `POST /api/v1/images/import-url` endpoint
- [ ] 5.2 Create image record with status "pending"
- [ ] 5.3 Invoke Lambda directly with image URL (Lambda downloads and processes)
- [ ] 5.4 Return image ID for client polling

## Phase 6: Go API - Testing & Deployment

- [ ] 6.1 Write unit tests for presigned URL generation
- [ ] 6.2 Write unit tests for S3 operations (mocked)
- [ ] 6.3 Write integration tests for image endpoints
- [ ] 6.4 Update API documentation
- [ ] 6.5 Deploy API to Fly.io

## Phase 7: Svelte - Gallery Component

- [ ] 7.1 Install GLightbox dependency
- [ ] 7.2 Create `ImageGallery.svelte` component
- [ ] 7.3 Create `ImageCard.svelte` for individual image display
- [ ] 7.4 Implement default image display (larger, prominent)
- [ ] 7.5 Integrate GLightbox for full-size viewing
- [ ] 7.6 Add no-image placeholder for species without images
- [ ] 7.7 Add native lazy loading to thumbnails (`loading="lazy"`)
- [ ] 7.8 Integrate gallery into species detail page

## Phase 8: Svelte - Admin Upload UI

- [ ] 8.1 Create `ImageUpload.svelte` component (file picker, presigned URL upload)
- [ ] 8.2 Create `ImageMetadataForm.svelte` (attribution fields)
- [ ] 8.3 Implement upload flow: get presigned URL -> upload to S3 -> poll for status
- [ ] 8.4 Add upload progress indicator and processing status display
- [ ] 8.5 Add iNat API client in `v2/web/src/lib/inatClient.ts`
- [ ] 8.6 Create `INatImport.svelte` component (URL input, API call, metadata preview)
- [ ] 8.7 Implement multi-photo selection for iNat observations
- [ ] 8.8 Implement iNat import flow (paste URL -> client fetches iNat -> preview -> confirm -> send to API)
- [ ] 8.9 Add upload button to species detail page (admin-only)
- [ ] 8.10 Add image management UI (edit metadata, delete, set default)
- [ ] 8.11 Add processing delay notice in UI ("Processing may take 10-15 seconds")

## Phase 9: Svelte - Testing & Polish

- [ ] 9.1 Write component tests for gallery
- [ ] 9.2 Write component tests for upload flow
- [ ] 9.3 Test mobile gallery experience
- [ ] 9.4 Test lightbox on mobile (touch gestures)
- [ ] 9.5 Verify admin-only access controls
- [ ] 9.6 Add alt text to images (use caption or "Photo of {species}")
- [ ] 9.7 Ensure gallery keyboard navigation (arrow keys, tab)
- [ ] 9.8 Deploy web app

## Phase 10: Migration

### Pre-Migration
- [ ] 10.1 Add maintenance flag to v1 admin to disable image uploads
- [ ] 10.2 Create inventory script to snapshot v1 image table with timestamps
- [ ] 10.3 Test migration on 100 images and estimate total duration

### Migration Script
- [ ] 10.4 Create migration script to read v1 image records
- [ ] 10.5 Implement fallback download (original → xlarge → large → medium → small)
- [ ] 10.6 Log warnings for images requiring fallback from original
- [ ] 10.7 Implement upload to v2 S3 structure
- [ ] 10.8 Implement Lambda invoke for each migrated image
- [ ] 10.9 Create v2 image records with new UUID (map all v1 fields, store v1 ID in legacy_id)
- [ ] 10.10 Add progress tracking and logging (6,531 images)
- [ ] 10.11 Implement delta migration for images added during long-running migration

### Execution
- [ ] 10.12 Disable v1 image uploads (set maintenance flag)
- [ ] 10.13 Run inventory snapshot
- [ ] 10.14 Run full migration in batches (100 at a time)
- [ ] 10.15 Run delta migration if needed (images added during migration)
- [ ] 10.16 Verify all images display correctly
- [ ] 10.17 Re-enable image uploads (now routes to v2)
- [ ] 10.18 Update any hardcoded v1 image paths to v2

## Phase 11: Documentation

- [ ] 11.1 Update v2/CLAUDE.md with image system overview
- [ ] 11.2 Document S3/CloudFront/Lambda setup for future reference
- [ ] 11.3 Document image upload workflow for admin use

## Phase 12: Future/Deferred (Optional)

- [ ] 12.1 Create orphan S3 object checker script (compare S3 vs DB, report orphans)
- [ ] 12.2 Add cleanup mode to orphan checker (delete confirmed orphans)
