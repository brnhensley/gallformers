# Change: Add Image Processing System

## Prerequisites

- **define-v2-foundation**: V2 directory structure and deployment pipeline must be in place
- **add-go-api**: Core Go API endpoints needed before adding image endpoints

## Why

The current v1 image system has significant reliability issues:
- Fire-and-forget Jimp processing that can fail silently
- Hardcoded CDN wait loops (100 iterations x 100ms) for cache sync
- No status tracking - clients can't know if processing succeeded
- Quality 100 output creates unnecessarily large files
- Sharp library included but unused (technical debt)

V2 needs robust, reliable image handling with proper async processing, status tracking, and optimized output formats.

## What Changes

### New Capability: Image Processing System

- **Processing**: AWS Lambda (Node.js + Sharp) for async image processing
- **Storage**: Existing S3 bucket with optimized CloudFront configuration
- **API**: New Go endpoints for upload, import, status, and management
- **Web UI**: Svelte gallery component, admin upload interface, GLightbox viewer

### Key Features

1. **Two Upload Paths**: Direct upload via presigned S3 URL, or import from iNaturalist URL via Lambda
2. **Multi-size Processing**: Generate small (300px), medium (800px), large (1200px), xlarge (2000px), preserve original
3. **Modern Formats**: WebP for served sizes (smaller, faster loading)
4. **Status Tracking**: pending, complete, failed - clients can poll for completion
5. **iNaturalist Integration**: Import images by pasting observation URL, auto-populate attribution
6. **Attribution Tracking**: Creator, license, source URL, license URL, source publication link, uploader audit trail
7. **Gallery UI**: Mobile-friendly carousel, GLightbox for full-size viewing, accessible

### Migration

Existing 6,531 images across 2,522 species will be migrated through the new Lambda pipeline to generate optimized WebP variants.

## Impact

- **New specs**: `web-images` (gallery UI, upload interface, processing pipeline)
- **Affected proposals**: `add-go-api` (new image endpoints), `add-svelte-admin` (upload UI), `add-svelte-public` (gallery)
- **Affected code**:
  - `v2/api/internal/` - new handlers, S3 client, Lambda client
  - `v2/api/internal/db/` - updated images table and queries
  - `v2/web/src/lib/components/` - gallery, upload, lightbox components
  - `v2/web/src/routes/` - admin upload integration
- **Infrastructure**:
  - AWS Lambda function for image processing
  - CloudFront distribution optimization
  - IAM credentials for API server (S3 + Lambda invoke)

## Out of Scope

- Image categories/types (keep simple - just species association)
- AI-based image recognition
- Video support
- Batch upload from folder (start with single image)
- Image editing/cropping in-browser

## Dependencies

- Requires `define-v2-foundation` to establish v2 directory structure
- Requires `add-go-api` to have core API patterns in place
- Blocks: None (this is additive functionality)

## Success Criteria

1. `POST /api/v1/images/upload` returns presigned URL; upload succeeds; Lambda processes; status becomes "complete"
2. `POST /api/v1/images/import-url` with iNat URL creates image record and triggers Lambda processing
3. Gallery displays images sorted by default flag, with lazy loading and lightbox
4. Admin can upload images, edit metadata, set default, delete
5. Migration script processes all 6,531 existing images with progress tracking
6. All served images are WebP format, significantly smaller than current JPG output
