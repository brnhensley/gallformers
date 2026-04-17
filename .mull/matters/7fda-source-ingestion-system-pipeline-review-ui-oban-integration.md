---
status: planned
tags: [design]
created: 2026-03-04
updated: 2026-04-15
epic: ingestion
relates: [ef0e, c836, 881c, fa48, dd3a]
needs: [881c, dd3a]
---

# Source ingestion system — pipeline, review UI, Oban integration

## Source Ingestion System — Architecture Decisions

Decisions captured from design sessions 2026-03-19 through 2026-03-23. See also: `docs/architecture/oban-background-jobs-research.md` for Oban evaluation.

### Overview

LLM-powered pipeline extracts structured gall data from scholarly sources (PDFs, URLs, text/docx files). Admin review UI for triage: match/create species, link sources, verify traits. Review-first import — nothing enters the DB without human confirmation.

### Prerequisite status

The taxonomy/API prerequisite for this work is satisfied by `881c` (unified species creation and reclassification API, done 2026-04-01). Matter `c836` was folded into `881c` and is no longer a separate open dependency.

The remaining substantive prerequisite from the original dependency set is `dd3a` (Oban infrastructure).

### Supported Input Types

- **PDF** (.pdf) — text extraction via pymupdf4llm (Python, System.cmd)
- **URL** — text extraction via trafilatura (basic HTML-to-text, not document download)
- **Plain text** (.txt) — passed directly to preprocess
- **Word** (.docx) — converted to text via pandoc or equivalent. Old .doc format not supported (users can save-as docx/PDF).

All input types feed into the same pipeline from extract onward. The entry point UI offers: URL field (paste and fetch) or file upload (accepts .pdf, .docx, .txt).

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
- `content_hashes` (text array) — hash of preprocessed text (last deterministic step, before any LLM). First element is canonical hash (S3 prefix). Additional hashes are dedup aliases added when user confirms a different input produces the same content.
- `input_type` — enum: `pdf`, `url`, `text`, `docx`
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

**Hash computed at preprocess output** — the last deterministic step. This means the same article from a URL and from a PDF produces the same hash if the text content matches. Input format doesn't affect dedup.

**Flow:**
1. `extract` (free) — input to raw text (PDF via Python, URL via trafilatura, txt passthrough, docx via pandoc)
2. `preprocess` (free, Elixir) — deterministic cleanup (boilerplate removal, line rejoining, etc.)
3. **Hash preprocessed text** — SHA-256 of the preprocessed output
4. **Duplicate check** — hash match against `source_ingestions.content_hashes`, plus heuristic title match from first ~500 chars against existing ingestion titles
5. If potential duplicate -> pause, show user the match, ask to confirm or skip
6. User confirms duplicate -> store new hash in existing record's `content_hashes` array, redirect to existing detail page
7. User says proceed -> continue to LLM steps

### S3 Storage

**Artifacts stored:** extract, preprocess, llm-clean, metadata JSON, data-extract JSON, assembled markdown. All under `sources/ingestion/{canonical_hash}/`.

**Original input files: NOT stored.** Every Source requires a URL/DOI — that's the canonical link. For public domain/CC0 sources, the assembled markdown serves as full text, which is more useful than the original format.

**Timing:** Upload to S3 after pipeline completes. Local artifacts are ephemeral.

### Auth & Access Gating

New Auth0 role (e.g., `ingestion-admin`). Initially only Jeff and Adam. The review UI checks for this role. Regular admins cannot access.

### Pipeline Stages (Oban Workers)

Each stage is an Oban job. A pipeline job enqueues stage 1, which on success enqueues stage 2, etc. Each stage is independently retryable.

1. **extract** — input to raw text (method depends on input_type)
2. **preprocess** — Elixir string manipulation (boilerplate removal, line rejoining, etc.)
3. **hash_and_dedup** — compute content hash, check DB, pause if match found (user action required)
4. **llm_clean** — HTTP to DeepInfra, chunked for large documents
5. **metadata** — HTTP to DeepInfra, extract title/authors/year/DOI
6. **data_extract** — HTTP to DeepInfra, chunked, extract species/traits/hosts
7. **assemble** — Elixir, combine cleaned text + metadata into final markdown
8. **upload** — Push all artifacts to S3

### Documentation Requirements

**MUST update when implementing:**
- Architecture docs (`docs/architecture/`) — document Oban integration, job queue patterns, when to use Oban vs GenServer
- Ops runbooks (`runbooks/`) — Oban monitoring, queue management, troubleshooting failed jobs, Oban Web access
- CLAUDE.md — add Oban patterns and conventions for the codebase
- CODING_STANDARDS.md — Oban worker patterns, testing Oban jobs, transaction boundaries

### Open Questions (Resolved)

- ~~UI deep dive~~ -> matter fa48
- ~~Non-PDF input~~ -> URL, .txt, .docx supported (2026-03-23)
- ~~Getting on main~~ -> merged, superadmin-gated
- ~~Operationalization~~ -> Oban workers, single deployment
- ~~Species creation/reclassification prerequisite~~ -> completed in 881c; c836 folded into 881c
- ~~S3 storage~~ -> artifacts only, no original files
- ~~PDF dedup~~ -> hash at preprocess step, content-based not file-based
- Future automation: pipeline design must not preclude automated discovery. Oban's scheduling and queue model supports this naturally. Not in scope now.

### Pipeline Improvement: Gall-Level Prose Extraction

The current `data-extract` step pulls a brief `description` snippet per gall-host record. The UI design (matter fa48) requires the full prose block that applies to each gall species — this becomes the `species_source.description` and is the primary reference text for the reviewer.

**What needs to change:** The extraction prompt and output format need to capture the complete prose section from the source that pertains to each gall species, not just a summary. The trait "Raw" fragments are separate — they're the specific phrases within the prose that support each trait value.

**Output structure per gall:**
- `description`: full prose block (paragraph(s) from the source about this gall)
- `traits.{trait}.original`: the specific phrase supporting the trait value (fragment within the prose)

