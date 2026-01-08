## ADDED Requirements

### Requirement: Image Upload via Presigned URL

The system SHALL allow authenticated users to upload images via presigned S3 URLs.

#### Scenario: Successful image upload
- **WHEN** user requests upload URL for a species
- **THEN** system returns presigned S3 URL with 1 hour expiry
- **AND** creates image record with status "pending"
- **AND** user can PUT file directly to S3
- **AND** S3 event triggers Lambda processing

#### Scenario: Upload size limit enforced
- **WHEN** user attempts to upload file larger than 20MB
- **THEN** S3 rejects the upload via presigned URL Content-Length condition
- **AND** client displays appropriate error message

#### Scenario: Invalid file type rejected
- **WHEN** user uploads non-image file (not JPEG, PNG, or WebP)
- **THEN** Lambda detects invalid format via magic bytes
- **AND** marks image status as "failed" with reason

### Requirement: Async Image Processing

The system SHALL process uploaded images asynchronously via AWS Lambda.

#### Scenario: Successful processing
- **WHEN** image is uploaded to S3 originals/ prefix
- **THEN** Lambda is triggered via S3 event
- **AND** Lambda generates small (300px), medium (800px), large (1200px), xlarge (2000px) WebP variants
- **AND** Lambda uploads variants to S3
- **AND** Lambda updates image status to "complete" via API callback

#### Scenario: Processing failure
- **WHEN** Lambda encounters error during processing
- **THEN** Lambda cleans up any partial uploads
- **AND** Lambda updates image status to "failed" with error reason
- **AND** client can display error to user

#### Scenario: Client polls for completion
- **WHEN** user uploads image
- **THEN** client polls GET /api/v1/images/{id} for status
- **AND** displays processing indicator while status is "pending"
- **AND** displays image when status is "complete"

### Requirement: iNaturalist URL Import

The system SHALL allow importing images from iNaturalist observation URLs.

#### Scenario: Single photo import
- **WHEN** user pastes iNaturalist observation URL
- **THEN** web app fetches observation data from iNat API
- **AND** displays photo thumbnail and attribution for confirmation
- **AND** user confirms import
- **AND** API creates image record and invokes Lambda with photo URL
- **AND** Lambda downloads, processes, and uploads to S3

#### Scenario: Multi-photo observation
- **WHEN** user pastes iNaturalist observation URL with multiple photos
- **THEN** web app displays all photos for selection
- **AND** user can select multiple photos to import
- **AND** each selected photo creates separate image record

#### Scenario: Attribution auto-populated
- **WHEN** image is imported from iNaturalist
- **THEN** creator, license, source_url, and location are auto-populated from iNat data
- **AND** source_observation_id stores the iNat observation ID

### Requirement: Image Gallery Display

The system SHALL display images for species in a responsive gallery.

#### Scenario: Gallery shows images sorted by default
- **WHEN** user views species detail page
- **THEN** default image is displayed prominently
- **AND** other images shown in grid/carousel below
- **AND** images sorted with default first, then by created_at

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

### Requirement: Admin Image Management

The system SHALL allow admins to manage images via admin interface.

#### Scenario: Upload new image
- **WHEN** admin clicks upload on species detail page
- **THEN** file picker opens (accepts JPEG, PNG, WebP)
- **AND** admin fills attribution fields (creator, license, caption)
- **AND** upload proceeds with progress indicator
- **AND** processing status shown until complete

#### Scenario: Set default image
- **WHEN** admin clicks "set as default" on an image
- **THEN** image becomes default for that species
- **AND** previous default (if any) is unset
- **AND** gallery re-sorts to show new default first

#### Scenario: Edit image metadata
- **WHEN** admin edits image caption or attribution
- **THEN** changes are saved immediately
- **AND** UI reflects updated values

#### Scenario: Delete image
- **WHEN** admin deletes an image
- **THEN** image record is removed from database
- **AND** all S3 objects (original + variants) are deleted
- **AND** gallery updates to remove image

### Requirement: Image Status Tracking

The system SHALL track image processing status for reliability.

#### Scenario: Status transitions
- **WHEN** image is created
- **THEN** status is "pending"
- **WHEN** Lambda completes successfully
- **THEN** status is "complete"
- **WHEN** Lambda encounters error
- **THEN** status is "failed" with error message

#### Scenario: Lambda callback with retry
- **WHEN** Lambda finishes processing
- **THEN** Lambda calls API to update status
- **AND** retries up to 3 times with exponential backoff on failure

### Requirement: Image Migration

The system SHALL migrate existing v1 images to v2 format.

#### Scenario: Batch migration
- **WHEN** migration script runs
- **THEN** v1 images are downloaded from legacy S3 paths
- **AND** uploaded to v2 S3 structure
- **AND** processed through Lambda for WebP variants
- **AND** new image records created in v2 schema
- **AND** progress logged for monitoring

#### Scenario: Migration preserves metadata
- **WHEN** v1 image is migrated
- **THEN** creator, attribution, license, caption preserved
- **AND** species association maintained
- **AND** default flag transferred
- **AND** v1 integer ID stored in legacy_id for traceability
