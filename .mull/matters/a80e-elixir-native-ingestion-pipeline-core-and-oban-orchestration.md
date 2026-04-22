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

## Design

**Architecture:** Elixir-native Oban-driven pipeline with 8 stages. Python retained only for PDF extraction via Erlang Port/named pipe. All orchestration, status transitions, duplicate decisions, and artifact management in Elixir.

**Naming Boundary:** Pipeline modules use `Gallformers.IngestionPipeline.*` (singular) to distinguish from `Gallformers.Ingestions` (plural) which owns the persisted review workflow context.

**Storage:** Leverages existing `Gallformers.Storage` at `lib/gallformers/storage.ex`. The existing `upload/3` function handles arbitrary S3 uploads. Artifacts use unified path prefix `source-ingestions/{ingestion_id}/{stage}/{filename}` under the existing images bucket. No CDN needed for JSON/text artifacts. Artifacts are first-class outputs with DB tracking.

**PubSub Progress:** New topic `ingestion:{id}` broadcasting `{:stage_complete, stage}`, `{:progress, percent}`, `{:error, stage, reason}`, `{:needs_duplicate_review, candidates}`. Uses existing `Phoenix.PubSub` infrastructure already running in the application.

**Duplicate Detection:** Implements 93b8 ladder: same-upload SHA, normalized-text SHA, bibliographic signals (DOI/title/author/year), MinHash fuzzy similarity. Auto-confirms exact DOI or exact hash with corroborating metadata. Probable matches pause at `needs_duplicate_review` state.

**Data Contract:** Data-extract stage outputs gall-level prose blocks (for `species_source.description`) with separate trait evidence phrases. Structured JSON payload that 7c67 review UI can render without re-parsing artifacts.

**Python Integration:** PDF extraction via Erlang Port to Python script (narrow, stateless). Python does not orchestrate, transition statuses, or write to Postgres.

## Implementation Plan

**Goal:** DB-backed, Oban-driven ingestion pipeline from submission through preprocessing, dedup, LLM stages, artifact production, to review-ready or duplicate-review state.

### Task 1: Ingestion artifact storage infrastructure

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/storage.ex`
- Test: `test/gallformers/ingestion_pipeline/storage_test.exs`

**Behavior:**
- `artifact_path(ingestion_id, stage, filename)` → `source-ingestions/{ingestion_id}/{stage}/{filename}`
- `upload_artifact(ingestion_id, stage, filename, content, content_type)` → uses `Gallformers.Storage.upload/3` with path from `artifact_path/3`
- `download_artifact(ingestion_id, stage, filename)` → fetches via `Req.get` from S3 or `ExAws.S3.get_object`
- `delete_artifacts_for_ingestion(ingestion_id)` → lists and deletes all objects under `source-ingestions/{id}/` prefix using `ExAws.S3.delete_multiple_objects`
- `artifact_url(ingestion_id, stage, filename)` → S3 direct URL (no CloudFront for artifacts)

Uses existing bucket from `Application.get_env(:gallformers, :images)[:bucket]` via `Gallformers.Storage.bucket/0`.

Integrates with existing `Gallformers.Ingestions.artifacts_path_for/1` convention (returns `source-ingestions/{id}`) - pipeline adds the `/{stage}/{filename}` suffix.

**Testing:**
- `artifact_path/4` generates correct S3 key structure with `source-ingestions/` prefix
- `upload_artifact/5` invokes `Storage.upload/3` with correct arguments
- `download_artifact/3` returns artifact content or {:error, :not_found}
- `delete_artifacts_for_ingestion/1` lists objects under prefix and deletes batch

---

### Task 2: PubSub progress broadcasting infrastructure

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/broadcaster.ex`
- Test: `test/gallformers/ingestion_pipeline/broadcaster_test.exs`

**Behavior:**
- `subscribe(ingestion_id)` → `Phoenix.PubSub.subscribe(Gallformers.PubSub, "ingestion:#{id}")`
- `broadcast_stage_complete(ingestion_id, stage)` → broadcasts `{:stage_complete, stage}`
- `broadcast_progress(ingestion_id, stage, percent)` → broadcasts `{:progress, stage, percent}`
- `broadcast_error(ingestion_id, stage, reason)` → broadcasts `{:error, stage, reason}`
- `broadcast_duplicate_review(ingestion_id, candidates)` → broadcasts `{:needs_duplicate_review, candidates}`
- `broadcast_review_ready(ingestion_id)` → broadcasts `{:review_ready, ingestion_id}`

All functions delegate to `Phoenix.PubSub` with the standard pattern already used in `Gallformers.Galls`, `Gallformers.Articles`, etc.

**Testing:**
- Subscribe isolates to ingestion-specific topic
- All broadcast functions emit expected messages to subscribers
- Multiple subscribers receive same message
- Non-subscribers do not receive messages

---

### Task 3: Oban worker foundations and orchestrator

Depends on: Task 1 (Storage), Task 2 (Broadcaster)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/worker.ex` (orchestrator)
- Create: `lib/gallformers/ingestion_pipeline/stage_worker.ex` (behaviour module)
- Modify: `config/config.exs` (add `:ingestion` queue)
- Test: `test/gallformers/ingestion_pipeline/worker_test.exs`

**Behavior:**
Orchestrator worker (`use Oban.Worker, queue: :ingestion`) spawned when ingestion created. Manages state machine:
- Fetches `SourceIngestion` record by ID from job args via `Gallformers.Ingestions.get_source_ingestion!/1`
- Determines next stage from `current_stage` field (nil → :extract, etc.)
- Spawns stage-specific worker with `oban_job_id` recorded on ingestion row
- On stage completion: updates `ingestion.status`, `current_stage`, broadcasts progress
- On failure: captures error on ingestion row (`error_stage`, `error_message`), broadcasts error
- On `needs_duplicate_review`: pauses pipeline, does not spawn next stage until reviewer resolves

StageWorker behaviour defines:
- `perform_stage(ingestion, artifacts) :: {:ok, result} | {:error, reason}` callback
- `stage_name/0` callback returning atom
- `max_attempts/0` default (3) and `backoff/1` for retry strategy

**Testing:**
- Orchestrator spawns correct next stage worker based on current state
- Stage completion advances `current_stage` field
- Failure records error fields and broadcasts via PubSub
- Duplicate-review state pauses pipeline (no new job spawned)
- Resume from duplicate-review continues to next stage
- Retry logic respects max_attempts

---

### Task 4: Python Port integration for PDF/OCR extraction

Depends on: Task 3 (Oban foundations)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/python_port.ex`
- Create: `priv/python/extraction_port.py` (narrow extraction script)
- Test: `test/gallformers/ingestion_pipeline/python_port_test.exs`

**Behavior:**
- Erlang Port spawns Python script for PDF text extraction
- Input contract: JSON via stdin `%{file_path: string, ocr_fallback: boolean}`
- Output contract: JSON via stdout `%{text: string, page_count: integer, metadata: map, error: string|null}`
- Port managed with 60-second timeout and kill switch (Port.close/1)
- Python script is stateless: receives file path, extracts via `pymupdf4llm`, optionally OCR if no text, outputs JSON, exits
- Python does not touch Postgres, does not transition statuses, does not decide duplicates
- On Python crash or timeout: returns `{:error, :extraction_failed, details}`

**Testing:**
- Port spawns Python, returns text for sample PDF fixture
- Timeout handled gracefully with `{:error, :timeout}`
- Python crash (non-zero exit) returns `{:error, :extraction_failed}` without crashing Elixir
- OCR fallback triggers when primary extraction yields empty text
- Invalid JSON from Python returns parse error

---

### Task 5: Extract and preprocess stages

Depends on: Task 4 (Python Port)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/extract.ex` (calls Python Port)
- Create: `lib/gallformers/ingestion_pipeline/stages/preprocess.ex`
- Test: `test/gallformers/ingestion_pipeline/stages/extract_test.exs`
- Test: `test/gallformers/ingestion_pipeline/stages/preprocess_test.exs`

**Behavior:**

Extract stage:
- Downloads source file from S3 (if not local) or uses local path
- Calls `PythonPort.extract_text/2` with file path
- Uploads result to `source-ingestions/{id}/extract/text.txt`
- Updates ingestion with `page_count`, `raw_text_length` via `Gallformers.Ingestions.record_duplicate_signals/2`

Preprocess stage:
- Downloads `extract/text.txt` artifact via `Storage.download_artifact/3`
- Deterministic cleanup ported from Python PoC:
  - Boilerplate removal (journal headers, footers)
  - Line rejoining (paragraphs split across lines)
  - Hyphen rejoining (words hyphenated at line breaks)
  - Plate/page reference handling
  - Bibliographic section detection (for cheap metadata sniff)
- Computes `preprocessed_text_sha256` hash
- Uploads to `source-ingestions/{id}/preprocess/text.txt`
- Updates ingestion row with hash via `Gallformers.Ingestions.record_duplicate_signals/2`

No LLM involved in either stage.

**Testing:**
- Extract stage: calls Python Port, uploads artifact, updates row
- Preprocess: boilerplate removal matches Python PoC output on sample inputs
- Line rejoining corrects hyphenated words across breaks
- SHA256 hash computed and stored
- Both artifacts exist at expected S3 paths

---

### Task 6: Hash and dedup stage (93b8 ladder)

Depends on: Task 5 (Preprocess produces hash)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/duplicate_detection.ex` (signal computation)
- Create: `lib/gallformers/ingestion_pipeline/stages/hash_and_dedup.ex`
- Test: `test/gallformers/ingestion_pipeline/duplicate_detection_test.exs`

**Behavior:**

Signal computation:
- Same-upload: `raw_input_sha256` from submission (stored on ingestion)
- Exact normalized: `preprocessed_text_sha256` from preprocess stage
- Bibliographic: normalized DOI, title, author, year from cheap metadata sniff
- Fuzzy: MinHash over normalized token shingles (using `MinHash` library or custom implementation), LSH for candidate lookup

Duplicate ladder logic:
1. **Exact DOI match** → auto-confirm, set `duplicate_of_source_ingestion_id`, skip to Task 11 (Upload)
2. **Exact preprocess hash + corroborating metadata** → auto-confirm, skip expensive stages
3. **Strong fuzzy (>0.9) + bibliographic match** → create `duplicate_candidate` records via `Gallformers.Ingestions.create_duplicate_candidate/3`, transition `needs_duplicate_review`, pause pipeline
4. **Moderate fuzzy (0.7-0.9)** → create candidates, pause for review
5. **No match** → continue to Task 7 (Cheap metadata sniff → full metadata)

All duplicate paths keep the new ingestion row. Confirmed duplicates linked via `canonical_ingestion_id` (`duplicate_of_source_ingestion_id` field).

**Testing:**
- Exact hash match creates link via `Ingestions` context, sets status to deduplicated, skips LLM stages
- Exact DOI match auto-confirms even without hash match
- Fuzzy match above 0.9 creates candidate records via context, pauses at `needs_duplicate_review`
- Auto-confirm only for exact DOI or exact hash with corroborating metadata (non-conflicting title/year)
- Probable duplicate broadcasts `{:needs_duplicate_review, candidates}` via Broadcaster
- No match continues pipeline normally

---

### Task 7: Metadata extraction stages (cheap sniff + full LLM)

Depends on: Task 6 (Dedup uses metadata for signals)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/metadata_sniff.ex` (cheap)
- Create: `lib/gallformers/ingestion_pipeline/llm_client.ex` (shared LLM interface)
- Create: `lib/gallformers/ingestion_pipeline/stages/metadata.ex` (full)
- Create: `priv/prompts/metadata_extraction.txt` (prompt template)
- Test: `test/gallformers/ingestion_pipeline/stages/metadata_sniff_test.exs`
- Test: `test/gallformers/ingestion_pipeline/stages/metadata_test.exs`

**Behavior:**

Cheap sniff (pre-LLM, runs before expensive stages):
- Deterministic regex extraction from preprocessed text header/bibliographic section:
  - DOI: `10.\\d{4,}/...` pattern
  - Title: Capitalized sentence before journal name
  - Authors: `Last, F.M.` or `F.M. Last` patterns
  - Year: 4-digit near journal or author list
- Updates ingestion row with sniffed metadata via `Gallformers.Ingestions.record_duplicate_signals/2`
- No LLM calls

Full metadata (LLM-based, after dedup passes):
- `LLMClient.completion/3` with prompt template and preprocessed text chunks
- Chunking for documents >4000 tokens
- JSON output parsing with `Jason.decode/1` and schema validation
- Retry up to 3 times on malformed JSON
- Updates ingestion with normalized DOI, title, authors (JSONB), year, journal, abstract via `Ingestions` context
- Uploads result to `source-ingestions/{id}/metadata/output.json`
- Records token usage (optional for first slice)

LLMClient:
- Configurable backend (OpenAI, Anthropic via `Req.post`)
- Timeout handling (60s default)
- Rate limiting awareness (optional)
- Retry with exponential backoff on 5xx/timeout

**Testing:**
- Sniff: DOI extracted from sample document headers
- Sniff: Title/year parsed from bibliographic block
- Full metadata: Successful extraction updates all bibliographic fields via context
- Full metadata: Malformed JSON triggers retry (max 3)
- Full metadata: Invalid JSON after retries marks stage failed with error
- LLMClient: 5xx response triggers retry, then returns error
- Artifact uploaded to expected path under `source-ingestions/`

---

### Task 8: LLM clean stage

Depends on: Task 7 (LLM client exists)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/llm_clean.ex`
- Create: `priv/prompts/llm_clean.txt`
- Test: `test/gallformers/ingestion_pipeline/stages/llm_clean_test.exs`

**Behavior:**
- Downloads `preprocess/text.txt` artifact via `Storage.download_artifact/3`
- Calls `LLMClient.completion/3` with clean prompt and text chunks
- Removes remaining artifacts (page numbers, running headers, OCR noise)
- Normalizes formatting (paragraph breaks, citation format)
- Uploads cleaned text to `source-ingestions/{id}/llm_clean/text.txt`
- Records completion metadata

**Testing:**
- Input text cleaned of remaining artifacts (sample-based)
- Chunking handles documents >4000 tokens
- Artifact uploaded to expected S3 path
- Stage completion recorded

---

### Task 9: Data extract stage (7fda contract)

Depends on: Task 8 (LLM clean output)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/data_extract.ex`
- Create: `lib/gallformers/ingestion_pipeline/data_contract.ex` (validation)
- Create: `priv/prompts/data_extract.txt`
- Test: `test/gallformers/ingestion_pipeline/stages/data_extract_test.exs`

**Behavior:**
- Downloads `llm_clean/text.txt` artifact via `Storage.download_artifact/3`
- Calls `LLMClient.completion/3` with extraction prompt
- Output contract (JSON schema validated by `DataContract`):
  ```json
  {
    "galls": [
      {
        "prose": "string suitable for species_source.description",
        "traits": [
          {"name": "trait_name", "evidence": "verbatim phrase supporting trait"}
        ],
        "species_mentions": [{"name": "Genus species", "context": "..."}]
      }
    ],
    "source_metadata": {...}
  }
  ```
- Gall-level prose blocks distinct from trait evidence phrases
- Trait evidence kept verbatim for reviewer verification
- Uploads to `source-ingestions/{id}/data_extract/output.json`
- Schema validation errors mark stage failed with `{:error, :invalid_contract, details}`

DataContract module:
- `validate/1` checks required fields and types
- `gall_entries/1` extracts gall list
- `prose_for_gall/2` returns prose block
- `traits_for_gall/2` returns trait list

**Testing:**
- Prose and trait evidence correctly separated in output
- Schema validation catches missing required fields
- Invalid trait structure returns validation error
- 7c67-compatible payload structure (can be rendered without file parsing)
- Artifact uploaded to expected path under `source-ingestions/`

---

### Task 10: Assemble stage

Depends on: Task 9 (Data extract output)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/assemble.ex`
- Test: `test/gallformers/ingestion_pipeline/stages/assemble_test.exs`

**Behavior:**
- Downloads `data_extract/output.json` and `metadata/output.json` artifacts via `Storage.download_artifact/3`
- Resolves species mentions against database (exact match on canonical name)
- Assembles reviewable markdown:
  - Frontmatter with metadata (title, authors, year, DOI)
  - Per-gall sections with prose and trait table
  - Unresolved species mentions flagged for reviewer
- Produces `source-ingestions/{id}/assemble/output.md`
- Updates ingestion with `assembled_at` timestamp via `Ingestions` context

**Testing:**
- Markdown generated with correct structure (headings, tables)
- Species references resolved where confident (exact match)
- Unresolved mentions flagged with `[?]` or similar
- Artifact uploaded to expected path

---

### Task 11: Upload stage (finalization)

Depends on: Task 10 (Assemble complete) or Task 6 (dedup auto-confirmed)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/upload.ex`
- Test: `test/gallformers/ingestion_pipeline/stages/upload_test.exs`

**Behavior:**
- Compiles artifact manifest: list of all S3 paths produced under `source-ingestions/{id}/`
- Updates ingestion status via `Gallformers.Ingestions.transition_source_ingestion_status/3`:
  - `:review_ready` if normal completion
  - `:needs_duplicate_review` if held at Task 6
  - `:duplicate_confirmed` if auto-confirmed at Task 6
- Records `completed_at` timestamp
- Broadcasts `{:review_ready, ingestion_id}` or `{:duplicate_review, ingestion_id, candidates}` via Broadcaster
- Optional: cleanup of intermediate artifacts (configurable, default keep all)

**Testing:**
- Status transitions to `:review_ready` on normal completion
- Status `:duplicate_confirmed` set on auto-confirm path
- Manifest lists all artifact paths (extract, preprocess, llm_clean, metadata, data_extract, assemble)
- PubSub completion message broadcast

---

### Task 12: Duplicate review resolution

Depends on: Task 6 (Hash and dedup creates candidates)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/duplicate_resolution.ex`
- Test: `test/gallformers/ingestion_pipeline/duplicate_resolution_test.exs`

**Behavior:**
- Thin adapter over `Gallformers.Ingestions` context for pipeline-specific duplicate operations:
  - `confirm_duplicate(candidate_id, reviewed_by_id)` → calls `Ingestions.confirm_duplicate_candidate/2`, then resumes pipeline to Task 11
  - `reject_duplicate(candidate_id, reviewed_by_id)` → calls `Ingestions.reject_duplicate_candidate/2`, continues pipeline from current stage
  - `promote_to_unique(ingestion_id)` → rejects all candidates via context, continues pipeline from current stage
- Resuming pipeline spawns orchestrator job to continue from `current_stage`

**Testing:**
- Confirm duplicate links ingestion via context, marks status, continues to Upload
- Reject duplicate removes candidate via context, continues pipeline
- Promote to unique rejects all via context, continues pipeline
- Resume correctly determines next stage from `current_stage` field

---

### Task 13: Integration and end-to-end tests

Depends on: All previous tasks

**Files:**
- Create: `test/gallformers/ingestion_pipeline/full_pipeline_test.exs` (integration)
- Create: `test/support/ingestion_pipeline_fixtures.ex` (factories)

**Behavior:**
End-to-end flows:
1. **Normal path:** Submit → Extract → Preprocess → Dedup (no match) → Sniff → Metadata → LLM Clean → Data Extract → Assemble → Upload → `:review_ready`
2. **Exact duplicate path:** Submit → Extract → Preprocess → Dedup (exact hash match) → auto-confirm → `:duplicate_confirmed` with link
3. **Probable duplicate path:** Submit → ... → Dedup (fuzzy match) → create candidates → `:needs_duplicate_review` → (reviewer confirms) → `:duplicate_confirmed`
4. **Retry path:** Submit → ... → Metadata (LLM error) → retry 3x → mark failed with error

All flows verify:
- All artifacts exist at expected S3 paths under `source-ingestions/{id}/`
- PubSub messages received in expected order
- Ingestion row status transitions correct via `Ingestions` context
- Duplicate candidates created/managed correctly via context

**Testing:**
- Each flow completes within test timeout (60s per stage)
- Artifacts retrievable from S3 after completion
- Failed stage records error fields
- Resume from failure point works correctly

---

### Task 14: Terraform S3 configuration for ingestion prefix

Depends on: Task 1 (path structure finalized)

**Files:**
- Modify: `infra/s3.tf` (add lifecycle rules for `source-ingestions/` prefix)

**Behavior:**
Add to existing `gallformers-images-us-east-1` bucket:
- Lifecycle rule for `source-ingestions/` prefix:
  - Expire incomplete multipart uploads after 7 days (cleanup orphaned upload parts from failed pipeline runs)

No separate bucket needed. The `source-ingestions/` prefix provides logical separation from images at `gall/` and `articles/`.

Cost optimization rules (version transitions, delete marker expiry) are intentionally omitted—the data volume is small and indefinite retention is acceptable.

**IAM policy check:**
- Verify app IAM role can read/write/delete under `source-ingestions/*`
- Already covered by existing bucket policy if app has full bucket access

**Testing:**
- Tofu plan shows no destructive changes to existing bucket
- Lifecycle rule targets only `source-ingestions/` prefix
- App can upload/download/delete under `source-ingestions/` prefix in staging