# iNaturalist Image Import on Images Admin

**Date**: 2026-02-14
**Matter**: 2708
**Status**: Design approved, ready for implementation planning

## Overview

Add an iNaturalist observation image import flow to the existing Images Admin page. An admin
pastes an iNat observation URL or ID, picks photos from the observation, and imports them to S3
with auto-populated attribution metadata.

## Architecture

### Approach: LiveComponent in the upload section

The iNat import workflow lives in a dedicated LiveComponent mounted alongside the existing
drag-drop dropzone. The component owns its own state lifecycle (idle → fetching → picking →
importing → done), keeping the parent LiveView unchanged beyond mounting the component and
handling a single `inat_import_complete` message.

This follows the project's architectural principle: "if state has its own lifecycle, it's a
LiveComponent."

### New Modules

- **`Gallformers.INaturalist`** — Context module owning all iNat API interaction.
  - `fetch_observation(id_or_url)` — parses input, calls iNat v1 API, returns structured result
  - `download_photo(photo_url)` — fetches original-size image bytes from iNat CDN
  - License mapping from iNat `license_code` to Gallformers license strings

- **`Gallformers.INaturalist.Observation`** — Plain struct (not Ecto schema) for parsed API
  response. Fields: `id`, `taxon_name`, `observer_login`, `observer_name`, `url`, `photos`

- **`Gallformers.INaturalist.Photo`** — Plain struct for each photo. Fields: `id`,
  `thumbnail_url`, `original_url`, `license_code`, `mapped_license`, `all_rights_reserved?`

- **`GallformersWeb.Admin.InatImportComponent`** — LiveComponent with 5-state lifecycle

### Shared Extraction

**`Images.finalize_upload/4`** — Extracted from the current `uploads_completed` event handler
in `ImagesLive`. Creates the DB record via `Images.create_image/1` and schedules async
`Storage.generate_size_variants/1`.

Both upload paths call this:
- Existing presigned URL flow: `finalize_upload(path, species_id, uploader)`
- iNat flow: `finalize_upload(path, species_id, uploader, %{creator: ..., license: ..., ...})`

## Upload Flow Comparison

### Presigned URL flow (existing)

```
Browser has file binary
  → Server: Storage.generate_path/2 + Storage.presigned_upload_url/2
  → Browser PUTs binary to S3 via presigned URL
  → Browser notifies server with paths
  → Server: Images.finalize_upload/4
```

### iNat flow (new)

```
Server downloads photo binary from iNat CDN
  → Server: Storage.generate_path/2
  → Server: Storage.upload/3 (direct S3 PUT with AWS credentials)
  → Server: Images.finalize_upload/4 (with iNat metadata attrs)
```

### Shared between both flows

- `Storage.generate_path/2`
- `Images.finalize_upload/4` (create DB record + schedule variant generation)

### NOT shared

| Step | Presigned URL flow | iNat flow |
|---|---|---|
| Who holds the binary | Browser | Server |
| How binary reaches S3 | Browser PUT via presigned URL | Server PUT via `Storage.upload/3` |
| Metadata source | Admin fills in manually | Auto-populated from iNat API |

## Component States

### `:idle`
Text input with placeholder "iNaturalist observation URL or ID". Fetch button disabled until
input is non-empty.

### `:fetching`
Input disabled, loading spinner. Cancel button to abort and return to idle.

### `:picking`
- Header: observation info (taxon name, observer, link to observation)
- Thumbnail grid using medium-size iNat CDN URLs (no download, just `<img>` tags)
- Checkboxes on each thumbnail
- ARR photos shown with warning badge: "All Rights Reserved — requires explicit permission"
- "Import Selected (N)" button, disabled if nothing checked
- Cancel to return to idle

### `:importing`
Progress indicator: "Importing 2 of 5..."
Photos processed sequentially (~1s between requests to respect iNat rate limits).

### `:done`
Brief success message. Auto-resets to idle, parent refreshes image grid.

### Error handling
- iNat API errors (404, rate limit, network) → error message, return to idle
- Individual photo download failure → skip, show warning, continue with others
- S3 upload failure → skip, show warning, continue

## URL Parsing

Accepted formats:
- `https://www.inaturalist.org/observations/12345`
- `https://inaturalist.org/observations/12345`
- `http://www.inaturalist.org/observations/12345`
- With query strings or fragments
- Bare numeric ID: `12345`

Anything else → inline validation error.

## iNat API Usage

Single endpoint: `GET https://api.inaturalist.org/v1/observations/{id}`

- **No authentication** — public read, no auth needed
- **User-Agent**: `Gallformers/1.0 (gallformers.org)` per iNat recommended practices
- **Rate limiting**: Sequential photo downloads with ~1s delay between requests
- **HTTP client**: Req (already a project dependency)

### Response fields used

From observation:
- `id` — build canonical source URL
- `taxon.name` — display in picker header (informational)
- `user.login` — observer username
- `user.name` — observer display name (may be null)
- `photos[]` — photo list

From each photo:
- `id` — for reference
- `url` — replace `square` with `medium` for thumbnails, `original` for download
- `license_code` — map to Gallformers license

## License Mapping

| iNat `license_code` | Gallformers license |
|---|---|
| `cc0` | `"Public Domain / CC0"` |
| `cc-by` | `"CC-BY"` |
| `cc-by-sa` | `"CC-BY-SA"` |
| `cc-by-nc` | `"CC-BY-NC"` |
| `cc-by-nc-sa` | `"CC-BY-NC-SA"` |
| `cc-by-nd` | `"CC-BY-ND"` |
| `cc-by-nc-nd` | `"CC-BY-NC-ND"` |
| `null` | `"All Rights Reserved"` |

## Attribution Mapping

| Image field | Source | Example |
|---|---|---|
| `creator` | `"#{user.login} - #{user.name}"` or just `user.login` if name is nil | `"janedoe - Jane Doe"` |
| `license` | Mapped from `photo.license_code` | `"CC-BY-NC"` |
| `licenselink` | `Licenses.url(mapped_license)` | `"https://creativecommons.org/licenses/by-nc/4.0/"` |
| `sourcelink` | `"https://www.inaturalist.org/observations/#{obs.id}"` | |
| `attribution` | Not set (creator covers it) | `nil` |
| `source_id` | Not set (no publication Source record) | `nil` |
| `caption` | Not set | `nil` |
| `uploader` | Current admin's `db_display_name` | `"jeff"` |

All fields editable post-import via the existing metadata editing modal.

## Parent LiveView Changes

Minimal:
1. Mount `InatImportComponent` in the upload section template, passing `species_id` and
   `db_display_name` as assigns
2. Handle `inat_import_complete` info message to refresh the image grid

## Decisions

- **Placement**: Inside the upload section alongside the dropzone (not a separate section or modal)
- **Picker UX**: Thumbnail grid with checkboxes
- **ARR photos**: Shown with warning, selectable at admin's discretion
- **API call**: Server-side via Req
- **Metadata editing**: Post-import only, via existing edit modal
- **Photo processing**: Sequential to respect iNat rate limits
