---
status: raw
created: 2026-04-25
updated: 2026-04-25
epic: source-ingestion
---

# Storage and module reorg follow-up for source artifact publishing

## Scope
Follow-up work from PR #540 review around storage/module organization, especially after introducing `Gallformers.Storage.SourceArtifacts` and moving source-publication logic into a neutral bridge module.

## Motivation
The current code works, but storage-related responsibilities are now spread across several places:
- `Gallformers.Storage`
- `Gallformers.Storage.SourceArtifacts`
- `Gallformers.S3`
- source-publication bridge code
- ingestion-pipeline storage helpers

This is a reasonable intermediate state, but it should be reviewed as a cohesive module organization problem rather than continuing to accrete one-off modules.

## Follow-up work
1. Review whether additional S3/storage helpers currently living outside `Gallformers.Storage.*` should move under a more coherent storage namespace.
2. Decide whether `Gallformers.S3` should remain a thin low-level request wrapper at top level or move under a storage-focused namespace.
3. Review naming and ownership of source-publication related modules now that the publication bridge no longer lives under `Ingestions`.
4. Check whether ingestion-pipeline storage helpers and source-artifact publishing helpers should share additional abstractions or remain intentionally separate.

## Open questions
- What is the long-term intended boundary between low-level S3 access, generic storage helpers, ingestion artifact storage, and public source publishing?
- Which modules should be top-level contexts/helpers versus nested under `Gallformers.Storage`?
- Is there a cleaner public-source publishing namespace than the current bridge/helper split?

## Notes
- This matter is about organization and ownership, not immediate behavior changes.
- Avoid turning this into an abstract cleanup. Any reorg should make boundaries clearer and reduce confusion about where new storage-related code belongs.

