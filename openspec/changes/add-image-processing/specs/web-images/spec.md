## ADDED Requirements

### Requirement: Image Upload via Presigned URL

The system SHALL allow authenticated users to upload images via presigned S3 URLs.

#### Scenario: Successful image upload
- **WHEN** user requests upload URL for a species or article
- **THEN** system returns presigned S3 URL with 1 hour expiry
- **AND** creates image record with status "pending"
- **AND** user can PUT file directly to S3
- **AND** Oban job is queued for processing

#### Scenario: Upload size limit enforced
- **WHEN** user attempts to upload file larger than 20MB
- **THEN** S3 rejects the upload via presigned URL Content-Length condition
- **AND** client displays appropriate error message

#### Scenario: Batch upload limit enforced
- **WHEN** user attempts to upload more than 10 files at once
- **THEN** client-side validation prevents the upload
- **AND** displays message about 10 file limit

#### Scenario: Supported formats accepted
- **WHEN** user uploads JPEG, PNG, WebP, or HEIC file
- **THEN** upload succeeds
- **AND** format is detected via magic bytes
- **AND** extension corrected if mismatched

#### Scenario: Invalid file type rejected
- **WHEN** user uploads non-image file
- **THEN** Oban worker detects invalid format
- **AND** marks image status as "failed" with reason

#### Scenario: Presigned URL expired
- **WHEN** user attempts upload after 1 hour expiry
- **THEN** S3 returns 403 Forbidden
- **AND** client displays "Upload session expired. Please try again."

### Requirement: Async Image Processing via Oban

The system SHALL process uploaded images asynchronously via Oban background jobs.

#### Scenario: Successful processing
- **WHEN** image is uploaded to S3
- **THEN** Oban worker downloads original from S3
- **AND** generates small (300px), medium (800px), large (1200px), xlarge (2000px) WebP variants
- **AND** generates medium (800px) JPEG fallback for old browsers
- **AND** uploads all variants to S3
- **AND** updates image status to "complete"
- **AND** broadcasts status via Phoenix PubSub

#### Scenario: Processing failure
- **WHEN** Oban worker encounters error during processing
- **THEN** worker updates image status to "failed" with error message
- **AND** broadcasts failure status via PubSub
- **AND** UI displays user-friendly error with expandable technical details

#### Scenario: Real-time status updates
- **WHEN** image processing completes or fails
- **THEN** Phoenix PubSub broadcasts status change
- **AND** subscribed LiveViews update automatically
- **AND** no polling required

#### Scenario: Sequential processing
- **WHEN** multiple images are queued for processing
- **THEN** Oban processes one at a time (concurrency: 1)
- **AND** UI shows queue position for pending images

#### Scenario: HEIC conversion
- **WHEN** HEIC image is uploaded
- **THEN** original is preserved as HEIC
- **AND** all size variants are WebP
- **AND** fallback is JPEG

### Requirement: Small Image Warning

The system SHALL warn when images are below minimum dimensions.

#### Scenario: Small image uploaded
- **WHEN** user uploads image with dimensions < 300x300
- **THEN** UI displays warning about small size
- **AND** upload is allowed to proceed (admin discretion)

### Requirement: iNaturalist URL Import

The system SHALL allow importing images from iNaturalist observation URLs.

#### Scenario: Single photo import
- **WHEN** user pastes iNaturalist observation URL
- **THEN** LiveView JS hook fetches observation data from iNat API
- **AND** displays photo thumbnail and attribution for confirmation
- **AND** user confirms import
- **AND** server creates image record and queues Oban job
- **AND** Oban worker downloads from iNat URL and processes

#### Scenario: Multi-photo observation
- **WHEN** user pastes iNaturalist observation URL with multiple photos
- **THEN** UI displays all photos for selection
- **AND** user can select multiple photos to import
- **AND** each selected photo creates separate image record

#### Scenario: Attribution auto-populated
- **WHEN** image is imported from iNaturalist
- **THEN** creator, license, sourcelink are auto-populated from iNat data
- **AND** source_observation_id stores the iNat observation ID

#### Scenario: iNat rate limit error
- **WHEN** iNat API returns 429 (rate limited)
- **THEN** UI displays user-friendly error
- **AND** suggests waiting before retrying

### Requirement: Image Gallery Display

The system SHALL display images for species in a responsive gallery with source-based ordering.

#### Scenario: Gallery ordering
- **WHEN** user views species detail page
- **THEN** default image is displayed first
- **AND** other images from same source as default shown next (newest first)
- **AND** remaining images grouped by source (newest first within each group)
- **AND** NULL sources treated as their own group

#### Scenario: Lightbox for full-size viewing
- **WHEN** user clicks gallery image
- **THEN** GLightbox opens with large size image
- **AND** user can navigate between images
- **AND** user can close with escape key or click outside

#### Scenario: Gallery handles no images
- **WHEN** species has no images
- **THEN** gallery shows placeholder image or message
- **AND** admin sees upload prompt

#### Scenario: Lazy loading
- **WHEN** gallery loads
- **THEN** thumbnails use native lazy loading (`loading="lazy"`)
- **AND** images load as they scroll into view

#### Scenario: Old browser compatibility
- **WHEN** browser doesn't support WebP (Safari < 14)
- **THEN** `<picture>` element serves JPEG fallback
- **AND** image displays correctly

#### Scenario: Cache-busted URLs
- **WHEN** image is displayed
- **THEN** URL includes version parameter `?v={updated_at_timestamp}`
- **AND** updated images are immediately fresh (no stale cache)

### Requirement: Admin Image Management

The system SHALL allow admins to manage images via admin interface.

#### Scenario: Upload new image
- **WHEN** admin clicks upload on species detail page
- **THEN** file picker opens (accepts JPEG, PNG, WebP, HEIC)
- **AND** admin fills attribution fields (creator, license, caption)
- **AND** upload proceeds with progress indicator
- **AND** processing status updates in real-time via PubSub

#### Scenario: Set default image
- **WHEN** admin clicks "set as default" on an image
- **THEN** image becomes default for that species
- **AND** previous default (if any) is unset
- **AND** gallery re-sorts to show new default first

#### Scenario: Edit image metadata
- **WHEN** admin edits image caption or attribution
- **THEN** changes are saved immediately
- **AND** UI reflects updated values

#### Scenario: Delete single image
- **WHEN** admin deletes an image
- **THEN** confirmation dialog is shown
- **AND** image record is removed from database
- **AND** all S3 objects (original + variants + fallback) are deleted
- **AND** gallery updates to remove image

#### Scenario: Bulk delete images
- **WHEN** admin selects multiple images and clicks delete
- **THEN** confirmation dialog shows count of selected images
- **AND** all selected image records are removed
- **AND** all S3 objects for selected images are deleted

#### Scenario: Bulk edit metadata
- **WHEN** admin selects multiple images and edits metadata
- **THEN** specified fields are updated for all selected images
- **AND** UI reflects updated values

#### Scenario: Retry failed processing
- **WHEN** admin clicks retry on a failed image
- **THEN** Oban job is re-queued for processing
- **AND** status changes to "pending"
- **AND** UI updates via PubSub when complete

### Requirement: Source Protection

The system SHALL prevent deletion of sources (publications) that have linked images.

#### Scenario: Delete source with images
- **WHEN** admin attempts to delete a source that has linked images
- **THEN** deletion is prevented (ON DELETE RESTRICT)
- **AND** error message shows which images are linked
- **AND** admin must reassign or delete images first

### Requirement: Cleanup and Maintenance

The system SHALL automatically clean up abandoned and failed uploads.

#### Scenario: Cleanup abandoned uploads
- **WHEN** scheduled Oban cleanup job runs (daily)
- **THEN** finds pending records older than 24 hours
- **AND** checks if S3 original exists
- **IF** S3 original doesn't exist
- **THEN** deletes the orphan DB record

#### Scenario: Retry stale pending
- **WHEN** scheduled Oban cleanup job runs
- **THEN** finds pending records older than 24 hours
- **AND** checks if S3 original exists
- **IF** S3 original exists
- **THEN** re-queues for processing (upload succeeded but processing failed)

#### Scenario: Orphan S3 detection (deferred)
- **WHEN** orphan detection script runs
- **THEN** compares S3 objects against DB records
- **AND** reports orphaned S3 objects for review

### Requirement: Article Image Support

The system SHALL support image uploads for articles using the same processing pipeline.

#### Scenario: Upload article image
- **WHEN** admin uploads image for an article
- **THEN** image record has article_id set (species_id is NULL)
- **AND** same processing pipeline generates all size variants
- **AND** same storage structure used

#### Scenario: Article image association
- **WHEN** image is associated with article
- **THEN** image cannot also be associated with species
- **AND** application code enforces mutual exclusivity

### Requirement: Image Migration

The system SHALL migrate existing v1 images to v2 format.

#### Scenario: Batch migration
- **WHEN** migration Mix task runs (`mix images.migrate`)
- **THEN** v1 images are read from database
- **AND** downloaded from legacy S3 paths (fallback: original → xlarge → large → medium → small)
- **AND** uploaded to v2 S3 structure in us-east-1
- **AND** processed through Oban for WebP variants + JPEG fallback
- **AND** new image records created with UUID (legacy_id preserves v1 ID)
- **AND** progress logged for monitoring

#### Scenario: Migration preserves metadata
- **WHEN** v1 image is migrated
- **THEN** creator, attribution, license, caption preserved
- **AND** species association maintained
- **AND** default flag transferred
- **AND** legacy_id stores v1 integer ID
- **AND** legacy_path stores v1 S3 path for reference

#### Scenario: Migration fallback logging
- **WHEN** original image is unavailable during migration
- **THEN** next largest size is used
- **AND** warning is logged indicating fallback was used
