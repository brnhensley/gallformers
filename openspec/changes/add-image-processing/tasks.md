# Tasks: Add Image Processing System

## Phase 1: Infrastructure Setup

- [ ] 1.1 Configure S3 bucket for us-east-1 (or verify existing bucket can serve from both regions)
- [x] 1.2 Configure S3 bucket CORS for presigned URL uploads from web app
- [ ] 1.3 Verify CloudFront distribution serves v2/ prefix correctly
- [ ] 1.4 Configure CloudFront cache TTL (1 year for v2/ images with versioned URLs)
- [ ] 1.5 Create IAM user for Fly.io with S3 presigned URL and read/write permissions
- [ ] 1.6 Store IAM credentials as Fly.io secrets
- [ ] 1.7 Ensure libvips/libheif available in Fly.io container (for Image library HEIC support)

## Phase 2: Oban Setup

- [ ] 2.1 Add Oban dependency to mix.exs
- [ ] 2.2 Configure Oban with SQLite3 (oban_sqlite) or PostgreSQL
- [ ] 2.3 Create Oban migration for jobs table
- [ ] 2.4 Configure image processing queue with concurrency: 1
- [ ] 2.5 Configure cleanup queue for scheduled maintenance job

## Phase 3: Database Schema

- [ ] 3.1 Create Ecto migration for images table with all fields
- [ ] 3.2 Add indexes for species_id, article_id, default, status, source_id
- [ ] 3.3 Create Image schema in `lib/gallformers/images/image.ex`
- [ ] 3.4 Add foreign key constraints (CASCADE for species/article, RESTRICT for source)

## Phase 4: Images Context - Core Functions

- [ ] 4.1 Create `lib/gallformers/images.ex` context module
- [ ] 4.2 Implement S3 presigned URL generation with Content-Length condition (20MB max, 1 hour expiry)
- [ ] 4.3 Implement path derivation functions (compute all S3 paths from ID + format)
- [ ] 4.4 Implement versioned URL generation (`?v={updated_at_timestamp}`)
- [ ] 4.5 Implement `create_image/1` - create pending record
- [ ] 4.6 Implement `get_image/1` - fetch single image
- [ ] 4.7 Implement `list_images_for_species/1` - with source-based ordering
- [ ] 4.8 Implement `list_images_for_article/1`
- [ ] 4.9 Implement `update_image/2` - update metadata
- [ ] 4.10 Implement `delete_image/1` - delete record + all S3 objects
- [ ] 4.11 Implement `set_default/1` - set image as default, unset previous
- [ ] 4.12 Implement `update_status/2` - update processing status
- [ ] 4.13 Implement bulk operations: `delete_images/1`, `update_images/2`

## Phase 5: Image Processing Worker

- [ ] 5.1 Create `lib/gallformers/images/processing_worker.ex` Oban worker
- [ ] 5.2 Implement S3 download of original image
- [ ] 5.3 Implement format detection via magic bytes (Image library)
- [ ] 5.4 Implement dimension extraction and small image detection
- [ ] 5.5 Implement resize to 4 WebP sizes (300, 800, 1200, 2000 longest edge)
- [ ] 5.6 Implement JPEG fallback generation (800px)
- [ ] 5.7 Implement HEIC → WebP/JPEG conversion
- [ ] 5.8 Implement S3 upload of all variants
- [ ] 5.9 Implement status update on success
- [ ] 5.10 Implement error handling with error_message storage
- [ ] 5.11 Implement PubSub broadcast on status change

## Phase 6: URL Import Worker

- [ ] 6.1 Create `lib/gallformers/images/url_import_worker.ex` Oban worker
- [ ] 6.2 Implement URL download with timeout (30 seconds)
- [ ] 6.3 Implement Content-Type validation (jpeg, png, webp, heic only)
- [ ] 6.4 Implement Content-Length check before download (reject >20MB)
- [ ] 6.5 Upload downloaded image to S3 originals/
- [ ] 6.6 Queue processing worker for variants

## Phase 7: Cleanup Worker

- [ ] 7.1 Create `lib/gallformers/images/cleanup_worker.ex` scheduled Oban worker
- [ ] 7.2 Implement abandoned upload detection (pending >24h, no S3 original)
- [ ] 7.3 Implement DB record cleanup for abandoned uploads
- [ ] 7.4 Implement stale pending retry (pending >24h, S3 original exists)
- [ ] 7.5 Configure Oban cron for daily cleanup job

## Phase 8: LiveView - Gallery Component

- [ ] 8.1 Install GLightbox dependency (npm or vendored)
- [ ] 8.2 Create `lib/gallformers_web/components/image_gallery.ex` component
- [ ] 8.3 Implement source-based ordering display
- [ ] 8.4 Implement default image prominent display
- [ ] 8.5 Integrate GLightbox for full-size viewing via JS hook
- [ ] 8.6 Implement `<picture>` element with WebP + JPEG fallback
- [ ] 8.7 Add native lazy loading (`loading="lazy"`)
- [ ] 8.8 Add no-image placeholder for species without images
- [ ] 8.9 Add alt text to images (use caption or "Photo of {species}")

## Phase 9: LiveView - Admin Upload UI

- [ ] 9.1 Create/update `lib/gallformers_web/live/admin/images_live.ex`
- [ ] 9.2 Implement file picker with drag-drop (JS hook)
- [ ] 9.3 Implement client-side validation (10 file limit, 20MB max, accepted formats)
- [ ] 9.4 Implement presigned URL request flow
- [ ] 9.5 Implement direct S3 upload with progress indicator
- [ ] 9.6 Implement PubSub subscription for real-time status updates
- [ ] 9.7 Implement processing status display (pending, complete, failed)
- [ ] 9.8 Implement error display (user-friendly + expandable technical details)
- [ ] 9.9 Implement retry button for failed images
- [ ] 9.10 Implement small image warning display

## Phase 10: LiveView - Admin Image Management

- [ ] 10.1 Implement image metadata edit form
- [ ] 10.2 Implement set default button
- [ ] 10.3 Implement single image delete with confirmation
- [ ] 10.4 Implement multi-select UI for images
- [ ] 10.5 Implement bulk delete with confirmation
- [ ] 10.6 Implement bulk metadata edit

## Phase 11: LiveView - iNaturalist Import

- [ ] 11.1 Create JS hook for iNat API calls (`assets/js/hooks/inat_import.js`)
- [ ] 11.2 Implement observation URL parsing
- [ ] 11.3 Implement iNat API fetch (client-side)
- [ ] 11.4 Implement photo thumbnail and metadata preview
- [ ] 11.5 Implement multi-photo selection UI
- [ ] 11.6 Implement import confirmation flow
- [ ] 11.7 Handle 429 rate limit errors gracefully
- [ ] 11.8 Auto-populate attribution fields from iNat data

## Phase 12: Species Integration

- [ ] 12.1 Add image gallery to species detail LiveView
- [ ] 12.2 Add upload button (admin-only) to species page
- [ ] 12.3 Update species list to show default image thumbnails
- [ ] 12.4 Ensure species deletion cleans up all S3 objects

## Phase 13: Source Integration

- [ ] 13.1 Implement ON DELETE RESTRICT handling for source deletion
- [ ] 13.2 Show linked images when source deletion is attempted
- [ ] 13.3 Add image carousel to Source public page (see bead gallformers-2ci8)

## Phase 14: Testing

- [ ] 14.1 Write unit tests for path derivation functions
- [ ] 14.2 Write unit tests for S3 presigned URL generation
- [ ] 14.3 Write unit tests for image ordering query
- [ ] 14.4 Write integration tests for processing worker (mocked S3)
- [ ] 14.5 Write integration tests for upload flow (mocked S3)
- [ ] 14.6 Write LiveView tests for gallery component
- [ ] 14.7 Write LiveView tests for upload UI
- [ ] 14.8 Test mobile gallery experience
- [ ] 14.9 Test lightbox on mobile (touch gestures)
- [ ] 14.10 Test HEIC upload and conversion
- [ ] 14.11 Test JPEG fallback in old browser (or simulated)

## Phase 15: Migration

### Pre-Migration
- [ ] 15.1 Add maintenance flag to v1 admin to disable image uploads
- [ ] 15.2 Create inventory script to snapshot v1 image table with timestamps
- [ ] 15.3 Test migration on 100 images and verify output

### Migration Script
- [ ] 15.4 Create `lib/mix/tasks/images.migrate.ex` Mix task
- [ ] 15.5 Implement v1 image record reading
- [ ] 15.6 Implement fallback download (original → xlarge → large → medium → small)
- [ ] 15.7 Log warnings for images requiring fallback from original
- [ ] 15.8 Implement upload to v2 S3 structure in us-east-1
- [ ] 15.9 Implement Oban job queuing for each migrated image
- [ ] 15.10 Create v2 image records with new UUID (map all v1 fields, store v1 ID in legacy_id)
- [ ] 15.11 Add progress tracking and logging (6,531 images)
- [ ] 15.12 Implement batch queuing (100 at a time)
- [ ] 15.13 Implement delta migration for images added during long-running migration

### Execution
- [ ] 15.14 Disable v1 image uploads (set maintenance flag)
- [ ] 15.15 Run inventory snapshot
- [ ] 15.16 Run full migration (`mix images.migrate`)
- [ ] 15.17 Run delta migration if needed
- [ ] 15.18 Verify all images display correctly
- [ ] 15.19 Re-enable image uploads (now routes to v2)
- [ ] 15.20 Update any hardcoded v1 image paths to v2

## Phase 16: Article Images (After Requirements Defined)

- [ ] 16.1 Define article image requirements (sizes, hero images, etc.)
- [ ] 16.2 Add article_id column handling in Images context
- [ ] 16.3 Create article image upload UI
- [ ] 16.4 Integrate images into article display

## Phase 17: Documentation

- [ ] 17.1 Update CLAUDE.md with image system overview
- [ ] 17.2 Document S3/CloudFront configuration for future reference
- [ ] 17.3 Document image upload workflow for admin use
- [ ] 17.4 Document Fly.io machine sizing requirements (1GB RAM minimum)

## Phase 18: Future/Deferred (Optional)

- [ ] 18.1 Create orphan S3 object checker script (compare S3 vs DB, report orphans)
- [ ] 18.2 Add cleanup mode to orphan checker (delete confirmed orphans)
- [ ] 18.3 Add custom CloudFront domain (images.gallformers.org) if desired
