# Admin Images: V1 vs V2 Comparison

**Route**: `/admin/images`

## Executive Summary

The Admin Images page manages species image uploads, metadata editing, and S3 storage. V2 provides a complete reimplementation with significant enhancements including drag-drop reordering, improved UX, and a new Image Audit tool for orphan detection.

**Migration Status**: COMPLETE with enhancements

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Species Search** | AsyncTypeahead | Reusable `.typeahead` component | ENHANCED | V2 shows image count in results |
| **Image Display** | react-data-table | Custom grid with thumbnails | ENHANCED | V2 shows actual images instead of table rows |
| **Image Upload** | Hidden file input, axios upload | Drag-drop with JS hook | ENHANCED | V2 has progress bar, file preview |
| **Upload Progress** | ProgressBar component | Custom progress UI | ENHANCED | V2 tracks per-file progress |
| **Image Editing** | Modal with react-hook-form | Modal with LiveView form | PARITY | Same fields, better UX |
| **Source Auto-fill** | Typeahead in modal | Typeahead with auto-populate | PARITY | Both populate license/creator from source |
| **Default Image** | Checkbox in edit modal | Drag to first position | ENHANCED | V2 uses drag-reorder for default |
| **Image Reordering** | Not available | Drag-drop with SortableImages hook | NEW | V2 feature |
| **Bulk Actions** | Delete selected, Copy one to others | Delete individual images | MISSING | V2 lacks bulk copy feature |
| **Delete Confirmation** | useConfirmation hook | Modal confirmation | PARITY | |
| **License Options** | Enum in code | Licenses.all() module | ENHANCED | Centralized license management |
| **Image Sizes** | Generated server-side | Generated in background Task | PARITY | Both create small/medium/large/xlarge |
| **S3 Presigned URLs** | API route | LiveView event handler | PARITY | Same security model |
| **Image Audit** | Not available | Separate ImageAuditLive page | NEW | Find orphans, unattributed images |
| **Incomplete Warnings** | None | Orange border + warning banner | NEW | V2 highlights missing metadata |

---

## File Locations

### V1 Files

| File | Lines | Purpose |
|------|-------|---------|
| `v1/pages/admin/images.tsx` | 1-476 | Main page component |
| `v1/components/imageedit.tsx` | 1-258 | Edit modal component |
| `v1/components/addimage.tsx` | 1-225 | Upload component |
| `v1/components/imageGrid.tsx` | 1-49 | Grid for copy selection |
| `v1/components/images.tsx` | 1-302 | Public image display component |
| `v1/pages/api/images/index.tsx` | 1-67 | GET/POST/DELETE API |
| `v1/pages/api/images/upsert.ts` | 1-6 | Batch insert API |
| `v1/pages/api/images/uploadurl.ts` | 1-51 | Presigned URL API |
| `v1/libs/images/images.ts` | 1-203 | S3 operations, image processing |
| `v1/libs/db/images.ts` | 1-200 | Database operations |

### V2 Files

| File | Lines | Purpose |
|------|-------|---------|
| `lib/gallformers_web/live/admin/images_live.ex` | 1-960 | Main LiveView |
| `lib/gallformers_web/live/admin/image_audit_live.ex` | 1-1108 | Image audit LiveView |
| `lib/gallformers/images.ex` | 1-884 | Images context (S3 + DB) |
| `lib/gallformers/images/audit_cache.ex` | 1-243 | GenServer for orphan caching |
| `lib/gallformers/species/image.ex` | 1-117 | Image schema |
| `assets/js/hooks/image_upload.js` | 1-316 | Upload JS hook |
| `assets/js/hooks/sortable_images.js` | 1-98 | Drag-drop reorder hook |

---

## UI Layer Comparison

### V1 UI Architecture

The V1 implementation uses React with react-bootstrap for UI components:

**Species Selection** (`v1/pages/admin/images.tsx:391-423`):
- Uses `AsyncTypeahead` from react-bootstrap-typeahead
- Searches via `/api/species?q=` endpoint
- URL query param for deep linking (`?speciesid=123`)

**Image Table** (`v1/pages/admin/images.tsx:99-180`):
- react-data-table-component with custom formatters
- Columns: Image thumbnail, Default checkbox, Source link, Source Link, Creator, License, License Link, Attribution, Caption
- Selectable rows for bulk actions

**Edit Modal** (`v1/components/imageedit.tsx:83-254`):
- Source typeahead for auto-populating license info
- License dropdown with 3 options (Public Domain, CC-BY, All Rights Reserved)
- Form fields: sourcelink, license, licenselink, creator, attribution, caption
- Tracks dirty state with react-hook-form

**Upload Component** (`v1/components/addimage.tsx:64-169`):
- File input (max 4 files)
- Gets presigned URL from `/api/images/uploadurl`
- Uploads directly to S3 via axios PUT
- Progress bar with CDN wait hack (10 seconds)

**Copy Metadata Feature** (`v1/pages/admin/images.tsx:238-282`):
- Select one image, then select others in a grid modal
- Copies: source, sourcelink, license, licenselink, creator, attribution, caption
- Uses ImageGrid component for selection

### V2 UI Architecture

V2 uses Phoenix LiveView with custom components:

**Species Selection** (`lib/gallformers_web/live/admin/images_live.ex:85-103`):
- Reusable `.typeahead` component
- Shows image count in search results
- URL query param for deep linking (`?species_id=123`)

**Image Grid** (`lib/gallformers_web/live/admin/images_live.ex:149-216`):
- Custom grid layout with 192x192 thumbnails
- Default image highlighted with maroon ring
- Incomplete images highlighted with orange ring
- Hover overlay with view/edit/delete buttons
- Drag-drop reordering via SortableImages hook

**Edit Modal** (`lib/gallformers_web/live/admin/images_live.ex:274-500`):
- Two-column layout (thumbnail + form)
- Source typeahead with auto-populate
- License dropdown from `Licenses.all()`
- Dynamic license link behavior (readonly for CC licenses)
- Dirty state tracking for save button enable/disable

**Upload Section** (`lib/gallformers_web/live/admin/images_live.ex:219-270`):
- Drag-drop dropzone
- File previews before upload
- Per-file progress tracking
- ImageUpload JS hook handles client-side logic

**Warning Banner** (`lib/gallformers_web/live/admin/images_live.ex:135-147`):
- Shows when any images lack creator or license
- Orange border on individual incomplete images

---

## Business Logic Comparison

### Image Upload Flow

**V1 Flow**:
1. User selects files (max 4) via file input
2. For each file, request presigned URL from `/api/images/uploadurl`
3. Upload to S3 via axios PUT with progress tracking
4. POST to `/api/images/upsert` to create DB records
5. Wait 10 seconds for CDN propagation
6. Trigger `createOtherSizes()` via Jimp for resizing

**V2 Flow**:
1. User drops files or selects via input (max 4)
2. JS hook validates file types, shows previews
3. Send `request_presigned_urls` event with file info
4. LiveView generates presigned URLs via ExAws
5. JS hook uploads to S3 with XHR progress
6. Send `uploads_completed` event with paths
7. LiveView creates DB records
8. Background Task generates size variants after 5s delay

### Image Metadata

Both track the same core fields:
- `creator` - Image author/photographer
- `attribution` - Additional attribution notes
- `license` - License type (CC0, CC-BY, All Rights Reserved)
- `licenselink` - URL to license
- `sourcelink` - URL to original source (iNaturalist, publication)
- `caption` - Image caption
- `source_id` - FK to sources table (for publication images)

**V2 Additions**:
- `sort_order` - For drag-drop reordering (default is sort_order=0)

### Source Auto-fill

Both implementations auto-populate fields when a source is selected:
- License from source
- License link from source
- Creator from source author

**V1** (`v1/components/imageedit.tsx:135-145`):
```typescript
onChange={(o) => {
  const s = o[0] as SourceWithSpeciesSourceApi;
  setSelected({
    ...selected,
    source: s,
    license: s ? asImageLicense(s.license) : '',
    licenselink: s ? s.licenselink : '',
    creator: s ? s.author : '',
  });
}}
```

**V2** (`lib/gallformers_web/live/admin/images_live.ex:803-818`):
```elixir
updated_image = %{
  socket.assigns.editing_image
  | source_id: source.id,
    license: source.license,
    licenselink: source.licenselink,
    creator: source.author
}
```

### Default Image Handling

**V1**: Uses a checkbox in the edit modal. When checked, triggers a transaction that:
1. Sets current image as default
2. Clears default from all other images for that species

**V2**: Uses drag-drop reordering. First image in sort order is the default:
- `sort_order = 0` is the default
- `reorder_images/2` updates sort_order for all images in transaction

### Image Deletion

**V1** (`v1/libs/db/images.ts:186-200`):
- Gets image paths from DB
- Deletes all size variants from S3
- Deletes DB records

**V2** (`lib/gallformers/images.ex:190-199`):
- Deletes all size variants from S3 first
- Then deletes DB record
- Rolls back if S3 deletion fails

---

## Data Layer Comparison

### V1 Data Layer

Uses Prisma ORM with fp-ts for functional error handling:

**Database Operations** (`v1/libs/db/images.ts`):
- `addImages()` - Batch insert with transaction
- `updateImage()` - Update + handle default switching
- `getImages()` - List images for species with source join
- `deleteImages()` - Delete from S3 then DB

**S3 Operations** (`v1/libs/images/images.ts`):
- `getPresignedUrl()` - S3RequestPresigner for upload URLs
- `createOtherSizes()` - Jimp-based resizing
- `deleteImagesByPaths()` - Batch delete from S3

**Image Sizes**:
```typescript
const sizes = new Map([
  [SMALL, 300],
  [MEDIUM, 800],
  [LARGE, 1200],
  [XLARGE, 2000],
]);
```

### V2 Data Layer

Uses Ecto with standard Elixir patterns:

**Images Context** (`lib/gallformers/images.ex`):
- `create_image/1` - Insert with auto sort_order
- `update_image/2` - Update with default handling
- `delete_image/1` - S3 delete then DB delete
- `list_images_for_species/1` - List with source preload
- `reorder_images/2` - Update sort_order in transaction
- `presigned_upload_url/2` - ExAws presigned URLs
- `generate_size_variants/1` - Image library resizing

**Image Sizes**:
```elixir
@sizes %{
  small: 300,
  medium: 800,
  large: 1200,
  xlarge: 2000
}
```

**AuditCache** (`lib/gallformers/images/audit_cache.ex`):
- GenServer for caching S3 orphan scan results
- 1 hour TTL
- Background async scanning

---

## New V2 Features

### Image Audit Page

V2 includes a separate Image Audit LiveView (`lib/gallformers_web/live/admin/image_audit_live.ex`) with:

**Orphan Detection**:
- Lists S3 images with no DB record
- Caches results in AuditCache GenServer
- Options: Delete from S3, Assign to species

**Unattributed Images**:
- Lists images missing creator or license
- Quick edit to add metadata

### Incomplete Image Warnings

V2 highlights images that need attention:
- Orange border on thumbnails
- Warning banner with count and instructions
- `image_incomplete?/1` helper checks for missing creator/license

### Drag-Drop Reordering

V2 uses SortableImages JS hook for intuitive reordering:
- Native HTML5 drag-drop
- Visual feedback during drag
- Persists order to DB on drop

---

## Missing V2 Features

### Bulk Copy Metadata

V1 has a "Copy One to Others" feature for batch metadata updates:
1. Select one image with complete metadata
2. Open copy modal, select target images in grid
3. Copy all metadata fields to selected images

This is not implemented in V2. Workaround: Edit each image individually.

---

## Recommendations

1. **Consider Adding Bulk Copy**: For species with many images from the same source, bulk copy saves significant time.

2. **Image Audit Integration**: Consider linking from the main Images page to the Audit page when incomplete images are detected.

3. **CDN Wait Time**: V2 uses a 5-second delay; V1 used 10 seconds. Monitor for CDN propagation issues.

4. **Orphan Prevention**: V2's orphan detection is reactive. Consider adding validation to prevent orphans (e.g., transaction on upload).

---

## References

- V1 Main Page: `/Users/jeff/dev/gallformers/v1/pages/admin/images.tsx`
- V1 Edit Modal: `/Users/jeff/dev/gallformers/v1/components/imageedit.tsx`
- V1 Upload: `/Users/jeff/dev/gallformers/v1/components/addimage.tsx`
- V1 S3 Ops: `/Users/jeff/dev/gallformers/v1/libs/images/images.ts`
- V1 DB Ops: `/Users/jeff/dev/gallformers/v1/libs/db/images.ts`
- V2 LiveView: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/images_live.ex`
- V2 Audit: `/Users/jeff/dev/gallformers/lib/gallformers_web/live/admin/image_audit_live.ex`
- V2 Context: `/Users/jeff/dev/gallformers/lib/gallformers/images.ex`
- V2 Schema: `/Users/jeff/dev/gallformers/lib/gallformers/species/image.ex`
- V2 Upload Hook: `/Users/jeff/dev/gallformers/assets/js/hooks/image_upload.js`
- V2 Sortable Hook: `/Users/jeff/dev/gallformers/assets/js/hooks/sortable_images.js`
