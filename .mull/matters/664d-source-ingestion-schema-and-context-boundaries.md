---
status: done
created: 2026-04-21
updated: 2026-04-21
epic: ingestion
blocks: [a80e, 7c67, 7fda]
needs: [93b8]
parent: 7fda
---

# Source ingestion schema and context boundaries

## Scope

Create the persisted ingestion domain model in the Phoenix app as the schema foundation for the rebased plan in `7fda`, using the duplicate-detection decisions now captured in `93b8`.

This matter is not a generic "add tables" task. It should concretize the production schema assumptions already captured in `7fda` so later pipeline and UI work are implementing against an intentional ingestion model rather than inventing one ad hoc.

Because `93b8` is now resolved, this matter should encode that design directly rather than merely "leaving room" for it.

## Must Reflect From `7fda` And `93b8`

This matter should carry forward these design constraints:
- production ingestion state is app-owned and Elixir-owned
- dedup happens before expensive LLM stages
- dedup is submission-centric and multi-signal, not a single canonical content-hash model
- every submission remains its own ingestion row, even when confirmed as a duplicate
- reviewer workflow is persisted in Postgres, not socket-local and not file-system-local
- the schema should support the `fa48` review flow without depending on the current PoC artifact layout
- Python must not own or write this schema

## Primary Deliverables

### 1. `source_ingestions` schema and migration

Implement a first production version of `source_ingestions` with fields shaped by `7fda` and concretized by `93b8`.

At minimum, the schema should cover:
- `input_type` with values aligned to the planned inputs: `pdf`, `url`, `text`, `docx`
- overall ingestion `status`
- `processing_stage` or equivalent stage-visibility field
- exact/fuzzy dedup signals stored on the ingestion row, including at least:
  - `raw_input_sha256`
  - `preprocessed_text_sha256`
  - `normalized_doi`
  - `normalized_title`
  - `title_fingerprint`
  - `author_fingerprint`
  - `publication_year`
  - fuzzy-text signature storage such as `minhash_signature`
- extracted and normalized source metadata needed before source mapping: title, authors, year, DOI as appropriate
- nullable `duplicate_of_source_ingestion_id` or equivalent canonical-link field for confirmed duplicates
- nullable `source_id`
- `artifacts_path` or equivalent canonical per-ingestion storage prefix
- `uploaded_by`
- error / failure fields needed for retryability and operator visibility
- timestamps

Important constraint:
- do **not** model `content_hashes` as the primary duplicate system
- if a convenience cache of alias hashes exists later, it should remain secondary to explicit stored signals and duplicate-link records

### 2. `source_ingestion_duplicate_candidates` schema and migration

Implement an explicit table for duplicate-review workflow rather than trying to encode candidate state indirectly on `source_ingestions`.

At minimum, it should cover:
- subject ingestion FK
- candidate ingestion FK
- candidate status such as `pending`, `confirmed`, `rejected`, `auto_confirmed`
- evidence payload / signal summary
- reviewer identity and review timestamps as needed
- created / updated timestamps

The purpose of this table is to make duplicate review auditable, explainable, and easy for `7c67` to render.

### 3. `source_ingestion_species` schema and migration

Implement a child table for per-gall review state.

At minimum, it should cover:
- `source_ingestion_id`
- extracted gall identity fields needed for review display
  - at least name and authority
- nullable mapped `species_id`
- per-item review `status`
- fields sufficient to support the future review UI's gall workspace
  - extracted prose block for the gall
  - structured extraction payload / review payload as needed for traits and hosts

The purpose of this table is to hold persisted reviewer-facing extraction state, not just a lossy index into raw artifact files.

### 4. Status model

Define explicit statuses rather than leaving them implicit in code.

For `source_ingestions`, the model should support at least:
- processing / in-flight
- `needs_duplicate_review`
- `needs_review`
- complete
- failed

For `source_ingestion_duplicate_candidates`, the model should support at least:
- pending
- confirmed
- rejected
- auto_confirmed if we want the audit trail to distinguish automatic exact-match resolution

For `source_ingestion_species`, the model should support at least:
- pending
- mapped
- created
- skipped
- complete if the final UI needs a separate "fully resolved" state

The exact names can change during implementation, but the state model should directly support the `7fda` flow, the `93b8` duplicate ladder, and the `fa48` reviewer workflow.

### 5. Context boundary

Add an ingestion context that owns:
- creating ingestion records as soon as a submission starts
- loading ingestion queue/detail data
- transitioning ingestion, duplicate-candidate, and per-gall statuses
- writing and reading duplicate signals on ingestion rows
- confirming/rejecting duplicate candidates and maintaining canonical links
- source-association lifecycle from the ingestion side
- artifact bookkeeping fields and accessors

This context should define the boundary between ingestion-owned state and existing domain records such as `sources` and `species_source`.

## Schema Decisions This Matter Should Nail Down

This matter should make the schema intentional in the following places:

### Dedup signal support

Do not assume a single preprocess hash is the entire cross-format duplicate story.

This matter should support the `93b8` model directly:
- same-upload signal via raw-input hash where available
- exact normalized-text matching via deterministic preprocess hash
- stronger bibliographic identity signals like normalized DOI/title/author/year
- fuzzy deterministic similarity storage via MinHash or equivalent
- explicit duplicate-review workflow and canonical-link semantics

### Canonical-link semantics

Confirmed duplicates should remain separate ingestion rows linked to a chosen canonical ingestion.

That means the schema should make it straightforward to represent:
- "this ingestion is canonical"
- "this ingestion is confirmed duplicate of canonical ingestion X"
- the possibility that a reviewer/operator may later choose a different canonical ingestion

### Artifact bookkeeping

The schema should assume artifacts live under a canonical **per-ingestion** prefix, not only in local PoC output directories and not under hash-based paths.

The schema/context should be able to point to persisted artifacts for:
- extracted text
- preprocessed text
- llm-clean output
- metadata JSON
- data-extract JSON
- assembled markdown

### Reviewer lock/unlock dependency on duplicate disposition and source mapping

The schema/context should make it straightforward for the review UI to enforce:
- duplicate-review disposition must be resolved before normal source/gall review begins
- source section must be resolved before gall-review work begins
- ingestion completion derives from all ingestion-species items being resolved

### Gall-level prose support

The schema must leave room for the extraction contract change already called out in `7fda`:
- each gall needs a full prose block suitable to become `species_source.description`
- trait evidence phrases should remain separately representable

Do not design the schema around the current morphology-only PoC `description` field if that would make the later review UI awkward.

## Non-Goals

- implementing the Oban pipeline itself
- building the review LiveView
- revisiting the dedup algorithm chosen by `93b8`
- keeping fidelity to the current local file layout as if it were canonical
- broad experimentation around alternative ingestion architectures

## Deliverable

A production-ready ingestion schema and context boundary that faithfully encodes `7fda` and the resolved duplicate model from `93b8`: persisted ingestion records, per-gall review state, explicit duplicate signals, explicit duplicate-candidate workflow, canonical-link support, artifact bookkeeping, and statuses that later pipeline and UI work can directly build on.

Implemented the first persisted ingestion domain model in the Phoenix app.

Key schema decisions landed:
- Added `source_ingestions` with explicit string-constrained `input_type`, `status`, and `processing_stage` fields.
- Kept dedup submission-centric: every submission is its own row, with `duplicate_of_source_ingestion_id` as an explicit canonical link rather than collapsing rows or using `content_hashes` as identity.
- Stored duplicate signals directly on the ingestion row: `raw_input_sha256`, `preprocessed_text_sha256`, `doi`, `normalized_doi`, `title`, `authors`, `normalized_title`, `title_fingerprint`, `author_fingerprint`, `publication_year`, and `minhash_signature`.
- Added per-ingestion artifact bookkeeping with immutable `source-ingestions/<id>` prefixes via `artifacts_path`; storage semantics are ingestion-ID based, not hash-based.
- Added `source_ingestion_duplicate_candidates` with persisted evidence JSON, review status (`pending`, `confirmed`, `rejected`, `auto_confirmed`), reviewer, and review timestamp.
- Added `source_ingestion_species` as persisted gall-level review items with explicit status (`pending`, `mapped`, `created`, `skipped`, `complete`), extracted name/authority, `description_prose`, and structured `extraction_payload` / `review_payload`.
- Used DB constraints and schema validations for all explicit status models and self-link protections.

Context boundary landed in `Gallformers.Ingestions`:
- ingestion creation immediately creates the row and assigns the canonical per-ingestion artifact prefix
- queue/detail loading helpers
- ingestion status transitions
- duplicate signal persistence
- duplicate candidate creation/listing/confirm/reject operations
- canonical-link maintenance that resolves through existing duplicate chains
- source association from the ingestion side
- gall-item creation/listing/status transitions
- workflow helpers for duplicate gating, source gating, artifact path resolution, and gall completion checks

Assumptions this enables downstream:
- `a80e` can write pipeline stages against DB-backed ingestions, persist dedup signals onto the ingestion row, create duplicate candidates before expensive stages, and use `artifacts_path` as the canonical artifact prefix.
- `7c67` can assume duplicate review is persisted, normal review is blocked until duplicate disposition is resolved, source association gates gall review, and gall work items live in `source_ingestion_species` with prose + structured payloads available from Postgres rather than raw PoC files.

Intentional deviations / clarifications:
- Added a raw `doi` field alongside `normalized_doi` so later stages can retain extracted metadata while still indexing the normalized dedup signal explicitly.
- Named the post-dedup terminal duplicate ingestion status `duplicate_confirmed` to keep confirmed duplicates legible instead of overloading `complete`.
- Kept host/trait review details inside structured payload fields on `source_ingestion_species` rather than locking the table to the current PoC JSON shape.

Verification:
- `make test-db`
- `mix test test/gallformers/ingestions_test.exs`
- `mix compile --warnings-as-errors`
