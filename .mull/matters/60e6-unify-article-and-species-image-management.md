---
status: planned
effort: 1 day
created: 2026-02-15
updated: 2026-02-28
epic: images
blocks: [16bb, 85c0]
---

# Unify article and species image management

## Decision: Species Images Stay Separate

Species images are deeply coupled (NOT NULL FK, S3 path format, audit system, ~2000 lines of LiveView). Folding them in would require S3 path migration for production data with no real benefit since the system works. No existing article images to migrate.

## Design

**Database:** New `content_images` table with attribution fields, nullable `article_id`/`key_id` FKs (CASCADE), CHECK constraint for exactly one owner.

**S3:** Articles: `articles/{id}/{ts}_{unique}.{ext}` (no variants). Keys: `keys/{id}/{ts}_{unique}_original.{ext}` (medium + large). Species unchanged.

**Shared modules:** `Images.Attribution` extracted from Images context. `Storage` parameterized for size variant config. Both species and content image code use these.

**Context:** New `ContentImages` context for CRUD. Cascade S3 cleanup called by Articles/Keys before delete.

**Key integration:** Couplet JSON stores `content_image_id`. Rendering resolves IDs to URLs.

**UI:** Single `ContentImageManager` LiveComponent used by both article and key forms. Handles grid, upload, metadata editing, reordering. Sends messages to parent for owner-specific behavior (insert markdown vs return ID).

## Implementation Plan

**Goal:** Unified image management for articles and keys with shared attribution, storage, and UI — without disrupting species images.

**Architecture:** Extract shared modules from the existing species image system, build a new `content_images` table and context, then build one LiveComponent that both article and key forms embed.

### Task 1: Extract Images.Attribution module

**Files:**
- Create: `lib/gallformers/images/attribution.ex`
- Modify: `lib/gallformers/images.ex` (remove attribution functions, delegate to new module)
- Test: `test/gallformers/images/attribution_test.exs`

**Behavior:**
Move `requires_attribution?/1`, `image_attributed?/1`, and the attribution field list out of the Images context into `Images.Attribution`. The Images context delegates to the new module — no public API change.

`image_attributed?/1` currently pattern-matches on `%ImageSchema{}`. Generalize it to accept any map/struct with the attribution fields (creator, license, licenselink, sourcelink, attribution). This lets ContentImages call the same function with `%ContentImage{}` structs.

**Testing:**
- `requires_attribution?/1` — public domain returns false, valid licenses return true, nil returns false, invalid string returns false
- `image_attributed?/1` — complete attribution returns true, missing creator returns false, missing license returns false, public domain with no creator returns true
- Existing `images_test.exs` tests still pass (delegates preserve behavior)

### Task 2: Parameterize Storage for size variants

**Files:**
- Modify: `lib/gallformers/storage.ex` (add `generate_size_variants/2`, `generate_content_image_path/3`, `delete_content_image/2`)
- Test: `test/gallformers/storage_test.exs`

**Behavior:**
- `generate_size_variants/2` — new arity that accepts a sizes keyword list (e.g., `[medium: 800, large: 1200]`). The existing `generate_size_variants/1` calls the new arity with the full 4-size map for backward compatibility.
- `generate_content_image_path(prefix, owner_id, extension)` — generates `{prefix}/{owner_id}/{ts}_{unique}_original.{ext}` for keys, `{prefix}/{owner_id}/{ts}_{unique}.{ext}` for articles. The `_original` suffix is included only when size variants will be generated — pass this as a flag or determine from prefix.
- `delete_content_image(path, sizes)` — deletes original + specified variant sizes. Empty sizes list means just delete the single file.

**Testing:**
- `generate_content_image_path/3` returns correct prefix/structure for articles and keys
- `generate_size_variants/2` with custom sizes only generates those sizes (mock S3)
- `delete_content_image/2` with empty sizes deletes one object, with sizes deletes original + variants
- Existing `generate_size_variants/1` behavior unchanged

**Notes:** The existing `@sizes` module attribute stays for the 1-arity default. The 2-arity version uses the passed-in config.

### Task 3: content_images migration and schema

Depends on: nothing (can run in parallel with tasks 1-2)

**Files:**
- Create: `priv/repo/migrations/{timestamp}_create_content_images.exs`
- Create: `lib/gallformers/content_images/content_image.ex`
- Test: `test/gallformers/content_images/content_image_test.exs`

**Behavior:**
Migration creates `content_images` table with: `path` (text, not null), `sort_order` (integer, default 0), `creator`, `attribution`, `license`, `licenselink`, `sourcelink`, `caption`, `uploader`, `lastchangedby` (all text, nullable). `article_id` FK to articles (nullable, CASCADE), `key_id` FK to keys (nullable, CASCADE), `source_id` FK to source (nullable, SET NULL). Timestamps. CHECK constraint: exactly one of article_id/key_id is non-null. Unique index on path. Indexes on (article_id, sort_order) and (key_id, sort_order).

Schema module: `Gallformers.ContentImages.ContentImage`. `belongs_to :article`, `belongs_to :key`, `belongs_to :source`. Changeset validates required fields (path), validates exactly-one-owner at changeset level too (defense in depth), casts attribution fields.

**Testing:**
- Changeset with article_id and no key_id is valid
- Changeset with key_id and no article_id is valid
- Changeset with both article_id and key_id is invalid
- Changeset with neither is invalid
- Path is required

### Task 4: ContentImages context

Depends on: Task 1 (Attribution), Task 2 (Storage), Task 3 (schema)

**Files:**
- Create: `lib/gallformers/content_images.ex`
- Test: `test/gallformers/content_images_test.exs`

**Behavior:**
- `list_images_for_article(article_id)` — ordered by sort_order, preloads source
- `list_images_for_key(key_id)` — same
- `get_image(id)` — with source preload
- `get_image!(id)` — raises
- `finalize_upload(path, owner_type, owner_id, uploader, extra_attrs \\ %{})` — creates record, schedules size variants based on owner_type (:article = none, :key = [medium: 800, large: 1200]). Calls `Storage.generate_size_variants/2` for keys, skips for articles.
- `update_image(image, attrs)` — metadata updates
- `delete_image(image)` — deletes DB record + S3 (original + variants based on owner type)
- `delete_images(owner_type, owner_id, image_ids)` — batch delete with owner validation
- `delete_images_from_s3_for_article(article_id)` — query all content_images for article, delete each from S3
- `delete_images_from_s3_for_key(key_id)` — same for keys
- `reorder_images(owner_type, owner_id, ordered_ids)` — update sort_order
- `copy_metadata(source_id, target_ids, updated_by)` — copies attribution fields
- `image_attributed?/1` — delegates to `Images.Attribution`

**Testing:**
- CRUD operations for article-owned images
- CRUD operations for key-owned images
- `finalize_upload` with :article owner creates record, does not schedule variants
- `finalize_upload` with :key owner creates record, schedules variants
- `delete_image` removes from DB and S3
- Reorder updates sort_order correctly
- Copy metadata propagates fields
- Owner validation — can't delete images belonging to a different owner

### Task 5: Wire cascade deletion into Articles and Keys

Depends on: Task 4

**Files:**
- Modify: `lib/gallformers/articles.ex` (`delete_article/1`)
- Modify: `lib/gallformers/keys.ex` (`delete_key/1`)
- Test: `test/gallformers/articles_test.exs` (add cascade test)
- Test: `test/gallformers/keys_test.exs` (add cascade test)

**Behavior:**
Before `Repo.delete`, call `ContentImages.delete_images_from_s3_for_article/1` or `delete_images_from_s3_for_key/1`. DB records cascade-delete via FK. This mirrors the existing pattern in species/gall/host deletion.

**Testing:**
- Deleting an article with content_images cleans up S3 (mock)
- Deleting a key with content_images cleans up S3 (mock)
- DB records are gone after delete (CASCADE)

### Task 6: ContentImageManager LiveComponent

Depends on: Task 4

**Files:**
- Create: `lib/gallformers_web/live/admin/content_image_manager.ex`
- Create: `assets/js/hooks/content_image_upload.js` (or extend existing)
- Test: `test/gallformers_web/live/admin/content_image_manager_test.exs`

**Behavior:**
Shared LiveComponent accepting `owner_type` (:article | :key), `owner_id`, `current_user`.

**Image grid:** Displays all images for the owner, ordered by sort_order. Each tile shows thumbnail, attribution status badge (warning if incomplete). Actions: edit metadata, delete.

**Upload:** Presigned-URL flow. User selects files → component requests presigned URLs from Storage → JS hook uploads directly to S3 → component calls `ContentImages.finalize_upload/5` → sends `{:image_uploaded, %ContentImage{}}` to parent.

**Metadata editing:** Modal with source typeahead, license dropdown, creator, attribution, caption. Uses `Images.Attribution` for validation. Same field set as species image editing.

**Delete:** Confirmation modal, calls `ContentImages.delete_image/1`, sends `{:image_deleted, image_id}` to parent.

**Reordering:** Drag-drop via sortable hook (reuse pattern from species ImagesLive).

**Parent communication:** All mutations notify the parent via `send(self(), msg)`:
- `{:image_uploaded, %ContentImage{}}` — parent decides next step
- `{:image_deleted, image_id}` — parent cleans up references
- `{:images_reordered, ordered_ids}` — parent can react if needed

**Testing:**
- Renders image grid for article owner
- Renders image grid for key owner
- Upload flow creates content_image record
- Metadata edit updates record
- Delete removes record and notifies parent
- Attribution badge shows for incomplete images

### Task 7: Article form integration

Depends on: Task 6

**Files:**
- Modify: `lib/gallformers_web/live/admin/article_live/form.ex` (replace S3 image browser with ContentImageManager)
- Modify or remove: `assets/js/hooks/article_image_upload.js` (may be replaced by content_image_upload.js)
- Test: `test/gallformers_web/live/admin/article_live/form_test.exs`

**Behavior:**
Remove the existing S3-only image browser (open_image_browser, filter_images_by_article, select_image, insert_image, delete_image events, and the image browser modal markup). Replace with `ContentImageManager` component.

Handle `{:image_uploaded, %ContentImage{}}` message: show the existing insert-into-markdown modal (alt text, caption, size preset) but now using the content_image's CloudFront URL. Push `insert_image_markdown` event to JS hook as before.

Handle `{:image_deleted, image_id}` message: optionally warn if image URL appears in article markdown content.

The "Save article first" guard stays — component needs `owner_id`.

**Testing:**
- Article form renders ContentImageManager when article is saved
- Image upload creates content_image with article_id FK
- Insert-into-markdown flow generates correct HTML with content_image URL
- Delete warns if image referenced in markdown
- Component hidden for unsaved articles

### Task 8: Key form integration

Depends on: Task 6

**Files:**
- Modify: `lib/gallformers_web/live/admin/key_live/form.ex` (add ContentImageManager, handle image_uploaded for couplet JSON)
- Test: `test/gallformers_web/live/admin/key_live/form_test.exs`

**Behavior:**
Add ContentImageManager to key form. When `{:image_uploaded, %ContentImage{}}` is received, display the image ID and path so the admin can reference it in couplet JSON. For now this is a manual step — the admin copies the ID into the JSON. A more integrated couplet editor is future work (85c0 scope).

Handle `{:image_deleted, image_id}` message: warn if the image ID appears in the key's couplet JSON.

**Testing:**
- Key form renders ContentImageManager when key is saved
- Image upload creates content_image with key_id FK
- Delete warns if image ID referenced in couplets
- Component hidden for unsaved keys

**Notes:** Full couplet-image integration (picker inside couplet editor) is 85c0 territory. This task just provides the upload/manage/reference mechanism.

### Task 9: Key rendering — resolve content_image IDs to URLs

Depends on: Task 3

**Files:**
- Modify: key rendering code (find where couplets are rendered to HTML/LiveView)
- Test: alongside existing key rendering tests

**Behavior:**
When rendering a key's couplets, collect all `content_image_id` values, bulk-load the content_images, and resolve each to its CloudFront URL. If an ID doesn't resolve (deleted image), render a placeholder or broken-image indicator.

**Testing:**
- Couplet with valid content_image_id renders image URL
- Couplet with deleted/invalid content_image_id renders placeholder
- Multiple couplets with images bulk-load efficiently (1 query, not N)

