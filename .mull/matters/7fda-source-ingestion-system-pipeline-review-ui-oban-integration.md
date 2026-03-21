---
status: planned
tags: [design]
created: 2026-03-04
updated: 2026-03-21
epic: ingestion
relates: [ef0e]
---

# Source ingestion system — pipeline, review UI, Oban integration

## Source Ingestion System — Architecture Decisions

Decisions captured from design sessions 2026-03-19 through 2026-03-21. See also: `docs/architecture/oban-background-jobs-research.md` for Oban evaluation.

### Overview

LLM-powered pipeline extracts structured gall data from scholarly PDFs. Admin review UI for triage: match/create species, link sources, verify traits. Review-first import — nothing enters the DB without human confirmation.

### Architecture: Oban + BEAM, No Separate Service

**Decision:** Port the Python processing pipeline to Elixir. Run as Oban workers in the existing Phoenix app. No separate Python service on Fly.

**Why:** The pipeline is IO-bound (waiting on LLM HTTP responses), not CPU-bound. A GenServer waiting on DeepInfra uses negligible resources. Eliminates: second Fly app, service networking, secrets duplication, scale-to-zero complexity, deployment coordination. If the server needs more capacity, bump the machine size.

**What stays in Python:** PDF text extraction only (pymupdf4llm via System.cmd). Everything else — preprocessing heuristics, LLM calls (HTTP to DeepInfra OpenAI-compatible API), JSON parsing, chunking — ports to Elixir.

**Oban specifics:**
- OSS tier only (Apache 2.0), no Pro needed
- Dedicated `extraction` queue with concurrency limit (1-2) to control LLM spend
- Transactional enqueue: create `source_ingestion` record + enqueue job atomically
- PubSub for real-time progress from worker to LiveView
- Oban Web (also Apache 2.0 since Jan 2025) for monitoring

### DB Schema

**`source_ingestions` table:**
- `id` (PK)
- `pdf_hashes` (text array) — first element is canonical hash (S3 prefix). Additional hashes are dedup aliases added when user confirms a different PDF is a duplicate.
- `status` — enum: `processing`, `ready`, `complete`
- `title`, `authors`, `year` — from metadata extraction
- `source_id` — FK to sources, nullable until mapped
- `artifacts_path` — S3 prefix to pipeline outputs
- `uploaded_by` / timestamps

**`source_ingestion_species` junction:**
- `source_ingestion_id` FK
- `extracted_name` — what the LLM found
- `species_id` — FK, nullable until mapped
- `status` — `pending`, `mapped`, `created`, `skipped`

### Deduplication: Cost-Driven Early Exit

**Decision:** Pipeline pauses BEFORE any LLM calls to check for duplicates. LLM processing costs real money.

**Flow:**
1. `extract` (free, local Python) — PDF to raw text
2. `preprocess` (free, Elixir) — clean up boilerplate
3. **Duplicate check** — hash match against `source_ingestions.pdf_hashes`, plus heuristic title match from preprocessed text first ~500 chars against existing ingestion titles
4. If potential duplicate → pause, show user the match, ask to confirm or skip
5. User confirms duplicate → store new hash in existing record's `pdf_hashes` array, redirect to existing detail page
6. User says proceed → continue to LLM steps

Cannot assume all papers come from BHL — pipeline handles arbitrary PDFs.

### S3 Storage

**Artifacts stored:** extract, preprocess, llm-clean, metadata JSON, data-extract JSON, assembled markdown. All under `sources/ingestion/{canonical_hash}/`.

**Original PDF: NOT stored.** Every Source requires a URL/DOI — that's the canonical link. For public domain/CC0 sources, the assembled markdown serves as full text, which is more useful than the PDF.

**Timing:** Upload to S3 after pipeline completes. Local artifacts are ephemeral.

### Auth & Access Gating

New Auth0 role (e.g., `ingestion-admin`). Initially only Jeff and Adam. The review UI checks for this role. Regular admins cannot access.

### Pipeline Stages (Oban Workers)

Each stage is an Oban job. A pipeline job enqueues stage 1, which on success enqueues stage 2, etc. Each stage is independently retryable.

1. **extract** — Python PDF-to-text via System.cmd (pymupdf4llm)
2. **preprocess** — Elixir string manipulation (boilerplate removal, line rejoining, etc.)
3. **duplicate_check** — DB lookup, pauses pipeline if match found (user action required)
4. **llm_clean** — HTTP to DeepInfra, chunked for large documents
5. **metadata** — HTTP to DeepInfra, extract title/authors/year/DOI
6. **data_extract** — HTTP to DeepInfra, chunked, extract species/traits/hosts
7. **assemble** — Elixir, combine cleaned text + metadata into final markdown
8. **upload** — Push all artifacts to S3

### Open Questions (Still TBD)

- UI deep dive: modal-per-gall vs current all-on-one-page, interaction design for the mapping/creation workflow
- Non-PDF input: should we handle URLs, plain text? Probably not initially.
- Getting current PoC work onto main: the service is standalone, UI can be gated behind Auth0 role. Need to decide when.
- Future automation: pipeline design must not preclude automated discovery of new papers to process. Oban's scheduling and queue model supports this naturally.

### Documentation Requirements

**MUST update when implementing:**
- Architecture docs (`docs/architecture/`) — document Oban integration, job queue patterns, when to use Oban vs GenServer
- Ops runbooks (`runbooks/`) — Oban monitoring, queue management, troubleshooting failed jobs, Oban Web access
- CLAUDE.md — add Oban patterns and conventions for the codebase
- CODING_STANDARDS.md — Oban worker patterns, testing Oban jobs, transaction boundaries
