---
status: planned
created: 2026-04-21
updated: 2026-04-21
epic: ingestion
blocks: [7c67, 7fda]
needs: [664d, 93b8]
parent: 7fda
---

# Elixir-native ingestion pipeline core and Oban orchestration

## Scope

Implement the production ingestion pipeline core in Elixir on top of the persisted ingestion model from `664d`, following the rebased architecture and stage ownership in `7fda` and the resolved duplicate strategy in `93b8`.

This matter owns stage execution, orchestration, retries, progress reporting, duplicate-check behavior, and artifact production. It does not own the final reviewer workflow UI.

Because `93b8` is now resolved, this matter should implement that duplicate path directly rather than treating dedup as still-open research.

## Must Reflect From `7fda` And `93b8`

This matter should preserve these decisions:
- production orchestration is Elixir-native and Oban-backed
- Python is retained only where it has narrow extraction leverage, not as the production orchestrator
- dedup happens before expensive LLM stages
- dedup is submission-centric and multi-signal, not a single preprocess-hash shortcut
- every submission remains its own ingestion row, even when confirmed as a duplicate
- artifacts are treated as first-class outputs with canonical **per-ingestion** storage prefixes
- the extraction contract must evolve toward gall-level prose blocks and separate trait evidence

## Stage Ownership

### Elixir-owned production stages

Implement these stages in Elixir:
1. `preprocess`
2. `hash_and_dedup`
3. `llm_clean`
4. `metadata`
5. `data_extract`
6. `assemble`
7. `upload`

Elixir also owns:
- ingestion record creation / updates
- duplicate-candidate creation / updates
- status transitions
- progress broadcasting
- artifact bookkeeping

### Python-owned narrow stages

If Python remains in the production path, keep it narrow:
- PDF extraction via `pymupdf4llm`
- optional OCR fallback if retained

Python must not:
- orchestrate the pipeline
- write to Postgres
- drive status transitions
- decide duplicate identity
- own source/species mapping logic

## Pipeline Flow

The production flow should follow this sequence:

1. create the ingestion row immediately and assign an immutable ingestion-id-based artifact prefix
2. extract raw text
3. preprocess deterministically
4. compute exact/fuzzy duplicate signals
5. evaluate duplicate candidates before expensive LLM stages
6. if duplicate handling requires reviewer confirmation, transition into `needs_duplicate_review`
7. otherwise continue into the expensive LLM stages
8. produce reviewable artifacts and transition the ingestion into normal review-ready state

The point of this matter is not just to "port code". It is to implement the actual production semantics from `7fda` and `93b8`, including the final duplicate-decision ladder.

## What This Includes

### Preprocess parity

Port the deterministic cleanup logic into Elixir with attention to the semantics already validated in the Python PoC:
- boilerplate removal
- header/footer stripping
- line rejoining
- hyphen rejoining
- plate-page handling if retained

### Dedup execution

Implement the `93b8` duplicate ladder explicitly.

That means:
- compute same-upload signal when available via `raw_input_sha256`
- compute exact normalized-text signal via `preprocessed_text_sha256`
- normalize and compare bibliographic signals such as DOI/title/author/year
- compute fuzzy text similarity using MinHash over normalized token shingles or the equivalent storage/lookup scheme chosen in `664d`
- create explicit duplicate-candidate records for reviewable matches
- auto-confirm only the safest cases:
  - exact DOI match
  - exact preprocess hash match when metadata is non-conflicting or corroborating
- send strong-but-not-certain matches into duplicate review instead of silent collapse

### Cheap metadata sniff before expensive stages

If the extraction stage does not already yield enough metadata for duplicate lookup, add a cheap metadata-sniff step before the expensive LLM stages.

That sniff may use:
- document metadata from extractors
- deterministic DOI/title/year parsing
- other cheap heuristics

It should **not** ask an LLM to judge duplicate identity.

### Later metadata enrichment

The full `metadata` stage should still write normalized DOI/title/author/year back to the ingestion row after the early duplicate pass.

That supports:
- stronger future duplicate matching for later submissions
- retrospective candidate creation if a later stage discovers a DOI or better metadata that the cheap path missed

That does not replace the pre-LLM duplicate pass.

### Duplicate outcomes

The pipeline should support three clear outcomes:
- **exact duplicate**: auto-confirm and link to canonical ingestion
- **probable duplicate**: create duplicate candidate and pause for reviewer confirmation
- **not a duplicate**: continue normally

When a duplicate is auto-confirmed:
- keep the new ingestion row for provenance
- link it to the canonical ingestion
- avoid running unnecessary expensive stages unless explicitly promoted later

### LLM stages

Port the hosted-model interaction path into Elixir for:
- llm-clean
- metadata extraction
- structured data extraction

That includes:
- prompt loading
- chunking strategy
- JSON parsing / validation
- retry/failure behavior
- token/cost-aware stage boundaries where useful

### Data-extract contract evolution

This matter should not stop at mirroring the existing PoC output if that leaves the reviewer workflow underpowered.

It must move toward the `7fda` contract needed by review:
- gall-level prose block suitable for `species_source.description`
- trait evidence phrases kept distinct from prose
- structured payload that `7c67` can render without re-parsing raw artifact files

### Oban integration

Implement Oban worker boundaries in a way that supports:
- stage retries
- stage visibility for operators and reviewers
- failure capture on the ingestion record
- duplicate-review pauses as first-class workflow states
- progress broadcasting via PubSub

### Artifact handling

Produce and track canonical artifacts for:
- extracted text
- preprocessed text
- llm-clean output
- metadata JSON
- data-extract JSON
- assembled markdown

These artifacts should align with the storage assumptions in `7fda`:
- each ingestion gets its own artifact prefix
- confirmed duplicates keep their own artifacts for provenance
- canonical ingestion is a relationship in the DB, not a storage-path convention

## Constraints

- do not shell out to the full Python pipeline from production
- do not recreate the current PoC's "local directory is the workflow database" pattern
- do not make the review UI depend on re-reading Python artifact conventions directly
- keep the production path understandable in Oban and operator tooling
- do not re-open the dedup design already decided in `93b8`
- do not use an LLM call as the duplicate judge

## Non-Goals

- final queue/detail review UI implementation
- replacing the Python research harness under `services/source-ingestion/`
- broadening the first production slice beyond what is needed to make ingestions reviewable

## Deliverable

A DB-backed, Oban-driven ingestion pipeline that takes an ingestion from creation through preprocessing, explicit duplicate detection, LLM stages, artifact production, and transition into either duplicate-review or normal review-ready state, in the architectural shape envisioned by `7fda` and concretized by `93b8`.

