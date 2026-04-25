---
status: done
created: 2026-02-14
updated: 2026-02-15
blocks: [8ba0]
docket: false
---

# iNat image import on Images Admin

Proof-of-concept iNat integration on the Images Admin screen.

Workflow:
1. Admin pastes an iNat observation URL or ID into a new input field
2. We fetch the observation via iNat API (using the skill/docs from 1f5f)
3. Display an image picker showing all photos from that observation
4. Admin selects which images to import
5. For each selected image: fetch the original-size image from iNat, upload to S3
6. Prepopulate and save all attribution info from the iNat observation (photographer, license, source URL, etc.)

Key considerations:
- Parse both URL formats (e.g. inaturalist.org/observations/12345 and just the ID)
- Handle observations with no photos or all-rights-reserved photos gracefully
- Attribution must match what iNat/CC licenses require
- Should feel integrated into the existing image upload flow, not a separate page

Depends on: 1f5f (iNat API skill) being done first so we have solid API knowledge.
Upstream of: 8ba0 (broader iNat integration).

Design approved and committed: docs/plans/2026-02-14-inat-image-import-design.md. Approach A (LiveComponent) with shared finalize_upload extraction. Ready for implementation planning.

Implementation plan committed: docs/plans/2026-02-14-inat-image-import-plan.md (7 tasks). Ready for execution in parallel session.

Implementation complete. 4 commits on main:
- Extract Images.finalize_upload/4 from uploads_completed handler
- Add INaturalist context with structs, license mapping, and API integration
- Add InatImportComponent with full import workflow (idle/fetching/picking/importing/done)
- Use standard component styling (gf-input, gf-checkbox, .button)

Manual testing passed. Full flow working: paste iNat URL → fetch observation → pick photos → import to S3 with attribution metadata.
