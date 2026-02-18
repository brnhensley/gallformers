---
status: raw
created: 2026-02-15
updated: 2026-02-17
epic: images
blocks: [16bb]
---

# Unify article and species image management

From bead ladz (P3).

## Problem

Article images and species images are managed separately:
- Species images: stored in image table, S3 path gall/{species_id}/
- Article images: no database tracking, S3 path articles/{article_id}/

This leads to:
1. Deleting an article orphans its S3 images (no cleanup)
2. Different code paths for image operations
3. Article images browsable but not linked to articles in DB

## Potential Approaches

1. Add article images to the image table with a nullable article_id FK
2. Create a separate article_image table
3. Keep S3-only storage for articles but add cleanup on delete

## Considerations

- Article images may be reused across articles (referenced by URL in markdown)
- Species images have attribution/licensing metadata - do article images need this?
- Impact on existing article image URLs
