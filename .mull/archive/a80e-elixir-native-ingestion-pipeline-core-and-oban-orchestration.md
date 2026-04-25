---
status: done
created: 2026-04-21
updated: 2026-04-25
epic: ingestion
relates: [db32]
blocks: [7c67, 7fda]
needs: [664d, 93b8, e3c3]
parent: 7fda
---

# Elixir-native ingestion pipeline core and Oban orchestration

## User Workflow

This is the end-to-end flow from a user's perspective. Implementing agents must keep this in mind when building any stage.

1. **User submits a PDF** via the ingestion UI (out of scope for this matter — `7c67` owns the UI). The UI calls `Gallformers.Ingestions.create_source_ingestion/1`, which creates a `SourceIngestion` row with `status: "processing"` and `processing_stage: "submitted"`. The UI then enqueues the orchestrator Oban job by calling `Gallformers.IngestionPipeline.Worker.enqueue/1` with the ingestion ID.

2. **Extract** — The orchestrator detects `processing_stage: "submitted"` and spawns the extract stage worker. PDF text is pulled out via an Erlang Port to a narrow Python script. Result is uploaded as an S3 artifact.

3. **Preprocess** — Deterministic text normalization (5 regex steps ported from Python PoC). Computes `preprocessed_text_sha256`. Cheap bibliographic sniff (DOI/title/author/year via regex) runs here as well, and any found signals are persisted immediately. Result uploaded as S3 artifact.

4. **Hash and Dedup** — Uses all signals now on the ingestion row (sha256 hashes, sniffed DOI/title/year, MinHash) to run the duplicate ladder. Three outcomes:
   - **Auto-confirmed duplicate** — pipeline skips to Upload stage, sets `status: "duplicate_confirmed"`.
   - **Probable duplicate** — creates `DuplicateCandidate` records, sets `status: "needs_duplicate_review"`, broadcasts, **stops**. Pipeline resumes only when a human reviewer acts (confirm/reject) via `DuplicateResolution`.
   - **No match** — pipeline continues.

5. **LLM Clean** — LLM-based OCR/formatting cleanup of the preprocessed text. Chunked and parallelized. Result uploaded as S3 artifact.

6. **Metadata** — Full LLM-based bibliographic metadata extraction (title, authors, DOI, year). Persists results to the ingestion row via `record_duplicate_signals/2`. Result uploaded as S3 artifact.

7. **Data Extract** — LLM-based structured extraction of gall records (gall species, host species, traits, prose, species mentions). Result uploaded as S3 artifact.

8. **Assemble** — Combines metadata and data extract artifacts into a reviewable Markdown document. Resolves species mentions against the DB (by canonical name and aliases). Unresolved mentions flagged. Result uploaded as S3 artifact.

9. **Upload (finalize)** — Compiles artifact manifest, transitions ingestion to `status: "needs_review"` / `processing_stage: "review"`. Broadcasts `{:review_ready, ingestion_id}`. The ingestion is now ready for the human reviewer in `7c67`.

**Human reviewer actions (out of scope for this matter, owned by `7c67`):**
- Duplicate review: confirm/reject candidates → pipeline resumes to Upload or continues
- Source review: map or create a `Source` record
- Gall review: approve/correct per-gall extractions, map species

## Design

**Architecture:** Elixir-native Oban-driven pipeline with 8 processing stages. Python retained only for PDF extraction via Erlang Port (narrow, stateless). All orchestration, status transitions, duplicate decisions, and artifact management in Elixir.

**Naming Boundary:** Pipeline modules use `Gallformers.IngestionPipeline.*` (singular) to distinguish from `Gallformers.Ingestions` (plural) which owns the persisted review workflow context.

**Storage:** Leverages existing `Gallformers.Storage` at `lib/gallformers/storage.ex`. Artifacts use unified path prefix `source-ingestions/{ingestion_id}/{stage}/{filename}` under the existing images bucket. No CDN needed for JSON/text artifacts. `IngestionPipeline.Storage` already exists and is fully implemented — do not recreate it.

**PubSub Progress:** Topic `ingestion:{id}` broadcasts `{:stage_complete, stage}`, `{:progress, stage, percent}`, `{:error, stage, reason}`, `{:needs_duplicate_review, candidates}`, `{:review_ready, ingestion_id}`. `IngestionPipeline.Broadcaster` already exists and is fully implemented — do not recreate it.

**Duplicate Detection:** Implements 93b8 ladder: same-upload SHA, normalized-text SHA, bibliographic signals (DOI/title/author/year), MinHash fuzzy similarity. Auto-confirms exact DOI or exact preprocessed-text SHA with corroborating metadata. Probable matches pause at `needs_duplicate_review`. Cheap bibliographic sniff is part of the Preprocess stage (regex only, no LLM), results persisted immediately so dedup can use them.

**Data Contract:** Data-extract stage outputs gall-level prose blocks (for `species_source.description`) with separate trait evidence phrases. Structured JSON payload that `7c67` review UI can render without re-parsing artifacts.

**Python Integration:** PDF extraction via Erlang Port to Python script at `priv/python/extraction_port.py` (standalone, invoked via `uv run` from the `priv/python/` directory which has its own `pyproject.toml` with `pymupdf4llm` as a dependency). Python receives file path + options via stdin JSON, outputs result via stdout JSON, then exits. Python does not orchestrate, transition statuses, or write to Postgres.

**LLM Provider:** DeepInfra, using the OpenAI-compatible API at `https://api.deepinfra.com/v1/openai`. API key read from the `DEEPINFRA_API_KEY` environment variable (runtime config). Model is runtime-configurable per stage via application config key `{:gallformers, :ingestion_pipeline, :models}` — a map of `stage_atom => model_string`, e.g. `%{llm_clean: "deepseek-ai/DeepSeek-V3-0324", metadata: "deepseek-ai/DeepSeek-V3-0324", data_extract: "deepseek-ai/DeepSeek-V3-0324"}`. Default models must be set in `config/config.exs`. Model strings use the DeepInfra model name format (e.g. `"deepseek-ai/DeepSeek-V3-0324"`).

**Oban Queue:** Use the existing `:extraction` queue (configured at concurrency 2). Do not create a new queue. All ingestion pipeline workers use `queue: :extraction`.

**Processing Stage Order** (as defined in `SourceIngestion` schema — do not deviate):
`submitted → extract → preprocess → hash_and_dedup → duplicate_review → llm_clean → metadata → data_extract → assemble → upload → review → complete → failed`

**Pipeline Entry Point:** `Gallformers.IngestionPipeline.Worker.enqueue/1` accepts an ingestion ID and inserts an Oban job onto the `:extraction` queue. This is called by the UI after `create_source_ingestion/1` succeeds. The worker reads the current `processing_stage` from the DB to determine what to do next, so it is idempotent and resumable.

**Species Resolution (Assemble stage):** Use `Gallformers.Species.search_species_by_name/3` (searches `species.name`) and `Gallformers.Species.find_species_with_alias/1` (searches the `alias` table via the `alias_species` join). Merge and deduplicate by `species_id`. Both galls (`taxoncode: "gall"`) and hosts (`taxoncode: "plant"`) are stored in the `species` table. Pass the appropriate `taxoncode` when calling `search_species_by_name/3`.

**Prompts:** Elixir-side LLM prompts live in `priv/prompts/`. Port them from the Python PoC at `services/source-ingestion/prompts/` (three files: `cleanup.md`, `metadata.md`, `data-extract.md`). Adapt them as needed for the Elixir implementation but preserve the core instructions.

**MinHash:** Implement directly in Elixir — no external library. Use 5-token shingles over normalized text tokens. 128 hash functions. The `minhash_signature` field on `SourceIngestion` is `{:array, :integer}` and accepts the 128-integer signature.

**Test Isolation:** All tests use the mock S3 backend (`s3_enabled: false` in test config). `IngestionPipeline.Storage` uses a behaviour-based backend — pass the mock backend in tests. No real S3 connections in any test.

## What Is Already Implemented (Do Not Recreate)

The following modules are complete and tested. Agents must use them, not reimplement them:

- `lib/gallformers/ingestion_pipeline/storage.ex` — `artifact_path/3`, `upload_artifact/5`, `download_artifact/3`, `delete_artifacts_for_ingestion/1`, `artifact_url/3`, behaviour-based backend for test isolation.
- `lib/gallformers/ingestion_pipeline/broadcaster.ex` — `subscribe/1`, `broadcast_stage_complete/2`, `broadcast_progress/3`, `broadcast_error/3`, `broadcast_duplicate_review/2`, `broadcast_review_ready/1`.
- `lib/gallformers/ingestions.ex` — full context with `create_source_ingestion/1`, `get_source_ingestion!/1`, `transition_source_ingestion_status/3`, `record_duplicate_signals/2`, `create_duplicate_candidate/3`, `confirm_duplicate_candidate/2`, `reject_duplicate_candidate/2`, `artifacts_path_for/1`, `artifact_path/2`, all status predicates.
- `lib/gallformers/storage.ex` — `upload/3` and `bucket/0`.

## Implementation Plan

**Goal:** DB-backed, Oban-driven ingestion pipeline from submission through preprocessing, dedup, LLM stages, artifact production, to review-ready or duplicate-review state.

---

### Task 1: Oban worker foundations and orchestrator

**Status: Done**

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/worker.ex` (orchestrator + `enqueue/1` entry point)
- Create: `lib/gallformers/ingestion_pipeline/stage_worker.ex` (behaviour module)
- Test: `test/gallformers/ingestion_pipeline/worker_test.exs`

**Behavior:**

`enqueue/1`:
- Accepts `ingestion_id`
- Inserts an Oban job: `%{ingestion_id: ingestion_id} |> Worker.new() |> Oban.insert()`
- Returns `{:ok, job}` or `{:error, changeset}`

Orchestrator worker (`use Oban.Worker, queue: :extraction, max_attempts: 3`):
- `perform/1` fetches `SourceIngestion` by `args["ingestion_id"]` via `Gallformers.Ingestions.get_source_ingestion!/1`
- Dispatches to the appropriate stage module based on current `processing_stage`:
  - `"submitted"` → `Stages.Extract`
  - `"extract"` → `Stages.Preprocess`
  - `"preprocess"` → `Stages.HashAndDedup`
  - `"hash_and_dedup"` → `Stages.LLMClean` (only if not paused for duplicate review)
  - `"duplicate_review"` → check status; if `"needs_duplicate_review"` do nothing (paused); if `"processing"` → `Stages.LLMClean`
  - `"llm_clean"` → `Stages.Metadata`
  - `"metadata"` → `Stages.DataExtract`
  - `"data_extract"` → `Stages.Assemble`
  - `"assemble"` → `Stages.Upload`
  - `"upload"` / `"review"` / `"complete"` / `"failed"` → no-op, return `:ok`
- After a stage returns `{:ok, updated_ingestion}`, re-enqueues itself (inserts a new orchestrator job) to continue to the next stage
- After a stage returns `{:error, reason}`, calls `transition_source_ingestion_status/3` to `"failed"` with `error_stage` and `error_message` attrs, broadcasts error via `Broadcaster`, returns `{:error, reason}` (Oban will retry up to `max_attempts`)
- Does NOT re-enqueue after transitioning to `"needs_duplicate_review"` — pipeline is paused

StageWorker behaviour:
- `@callback perform_stage(SourceIngestion.t()) :: {:ok, SourceIngestion.t()} | {:error, reason}`
- `@callback stage_name() :: atom()`
- Default `max_attempts: 3` documented in moduledoc

Each stage module does its own `processing_stage` transition via `transition_source_ingestion_status/3` before returning `{:ok, updated_ingestion}`.

**Testing:**
- `enqueue/1` inserts an Oban job with correct args
- Orchestrator dispatches to `Stages.Extract` when `processing_stage` is `"submitted"`
- Orchestrator re-enqueues itself after a successful stage
- Orchestrator does NOT re-enqueue when stage returns `needs_duplicate_review`
- Failed stage transitions status to `"failed"`, sets `error_stage` and `error_message`
- No-op for terminal stages (`"complete"`, `"failed"`, `"review"`)

---

### Task 2: Python Port integration for PDF/OCR extraction

**Status: Done**

**Depends on:** Task 1

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/python_port.ex`
- Create: `priv/python/extraction_port.py`
- Create: `priv/python/pyproject.toml` (declares `pymupdf4llm` dependency; use `uv` as package manager)
- Test: `test/gallformers/ingestion_pipeline/python_port_test.exs`

**Behavior:**

`python_port.ex`:
- `extract_text(file_path, opts \\ [])` where `opts` can include `ocr_fallback: boolean`
- Opens an Erlang Port: `Port.open({:spawn_executable, System.find_executable("uv")}, [:binary, :exit_status, :stderr_to_stdout, args: ["run", "extraction_port.py"], cd: priv_python_dir()])`
  - `priv_python_dir/0` returns `:code.priv_dir(:gallformers) |> Path.join("python") |> to_string()`
- Sends JSON via Port: `Port.command(port, Jason.encode!(%{file_path: file_path, ocr_fallback: Keyword.get(opts, :ocr_fallback, false)}))`
- Collects all stdout into a buffer until `{:exit_status, code}` is received
- Timeout: 120 seconds (large PDFs take time); kills port with `Port.close/1` on timeout
- On exit code 0: parses stdout as JSON → `{:ok, %{text: string, page_count: integer, metadata: map}}`
- On exit code non-0 or timeout: `{:error, :extraction_failed, details}`
- On unparseable JSON: `{:error, :invalid_response, raw_output}`

`extraction_port.py`:
- Reads one line of JSON from stdin: `{"file_path": "...", "ocr_fallback": bool}`
- Calls `pymupdf4llm.to_markdown(file_path)` to extract text
- If `ocr_fallback` is true and extracted text is empty or very short (<100 chars after strip), falls back to extracting raw text via `pymupdf` page iteration
- Outputs JSON to stdout: `{"text": "...", "page_count": N, "metadata": {...}, "error": null}` on success, or `{"text": null, "page_count": 0, "metadata": {}, "error": "message"}` on failure
- Exits with code 0 on success, code 1 on failure
- Does not write to Postgres, does not manage state

**Testing:**
- Port spawns Python, returns `{:ok, %{text: ..., page_count: ..., metadata: ...}}` for a sample PDF fixture
- Timeout handled gracefully: `{:error, :extraction_failed, _}` returned, port killed
- Python non-zero exit returns `{:error, :extraction_failed, _}` without crashing Elixir process
- OCR fallback triggered when primary extraction yields empty text
- Invalid JSON from Python returns `{:error, :invalid_response, _}`

---

### Task 3: Extract stage

**Status: Done**

**Depends on:** Tasks 1 and 2

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/extract.ex`
- Test: `test/gallformers/ingestion_pipeline/stages/extract_test.exs`

**Behavior:**
- Implements `StageWorker` behaviour; `stage_name/0` returns `:extract`
- `perform_stage/1` receives a `SourceIngestion` struct
- Determines the source file location: the ingestion row has an `input_type` field (`"pdf"`, `"url"`, `"text"`, `"docx"`). For this implementation, handle only `"pdf"` — return `{:error, :unsupported_input_type}` for others (future tasks can extend)
- For PDF: the source file path must come from an S3 download. The file was uploaded to S3 by the UI before `create_source_ingestion/1` was called. The artifact key is `artifact_path(ingestion, "input/source.pdf")` using the existing `Ingestions.artifact_path/2`. Download via `IngestionPipeline.Storage.download_artifact/3` with stage `"input"` and filename `"source.pdf"`. Write to a temp file.
- Calls `PythonPort.extract_text(temp_file_path, ocr_fallback: false)`
- Uploads result text to `source-ingestions/{id}/extract/text.txt` via `IngestionPipeline.Storage.upload_artifact/5` with content type `"text/plain"`
- Logs `page_count` and text length via `Logger`
- Calls `transition_source_ingestion_status(ingestion, "processing", %{processing_stage: "extract"})` and returns `{:ok, updated_ingestion}`
- On `PythonPort` error: returns `{:error, reason}`

**Testing:**
- Happy path: PythonPort mock returns text, artifact uploaded to correct S3 path, `processing_stage` updated to `"extract"`
- PythonPort failure returns `{:error, _}` without updating DB
- Unsupported input type returns `{:error, :unsupported_input_type}`

---

### Task 4: Preprocess stage (includes cheap bibliographic sniff)

**Status: Done**

**Depends on:** Task 3

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/preprocess.ex`
- Create: `lib/gallformers/ingestion_pipeline/text_processing.ex` (pure functions, no side effects)
- Test: `test/gallformers/ingestion_pipeline/stages/preprocess_test.exs`
- Test: `test/gallformers/ingestion_pipeline/text_processing_test.exs`

**Behavior:**

`text_processing.ex` — pure transformation functions (port faithfully from `services/source-ingestion/src/ingest/preprocess.py`):
- `preprocess(text)` — runs all 5 steps in order:
  1. `strip_bhl_boilerplate(text)` — detect `"biodiversitylibrary.org"` in first 500 chars; strip everything before `"This page intentionally left blank."` or a `"Generated ... PM/AM"` line
  2. `strip_plate_pages(text)` — state machine to drop plate-image sections (lines starting with `PLATE I.`, `PLATE II.` etc.), dropping all-caps running headers and OCR junk lines within them
  3. `strip_page_headers(text)` — regex removal of running headers and standalone page numbers; collapse 3+ blank lines to 2
  4. `rejoin_hyphenated(text)` — regex `(\w)-\s*\n+\s*([a-z])` → join words hyphenated across line breaks (lowercase continuation only)
  5. `rejoin_lines(text)` — split on double-newline paragraph boundaries, merge continuation paragraphs, collapse internal newlines to space; see Python PoC for full continuation heuristic

- `cheap_sniff(text)` — regex-only extraction, no LLM, returns `%{doi: nil | string, title: nil | string, authors: [] | [string], year: nil | integer}`:
  - DOI: `~r/10\.\d{4,}\/[^\s]+/` in first 2000 chars; normalize to lowercase, strip trailing punctuation
  - Year: 4-digit number `1800-2099` near the start of the document (first 1000 chars)
  - Title: heuristic — first line of the document that is ≥20 chars, not all-caps, not a page number, not DOI
  - Authors: look for `Last, F.M.` or `F.M. Last` patterns in first 1000 chars; return as list of strings. Empty list if none found.
  - Returns map with all four keys; any unfound field is `nil` (or `[]` for authors)

- `compute_sha256(text)` — returns hex string of SHA-256 of the UTF-8 binary

`preprocess.ex`:
- Implements `StageWorker`; `stage_name/0` returns `:preprocess`
- Downloads `source-ingestions/{id}/extract/text.txt` artifact
- Calls `TextProcessing.preprocess(text)` → cleaned text
- Calls `TextProcessing.cheap_sniff(cleaned_text)` → `%{doi:, title:, authors:, year:}`
- Calls `TextProcessing.compute_sha256(cleaned_text)` → hash
- Calls `Ingestions.record_duplicate_signals/2` with `%{preprocessed_text_sha256: hash, doi: doi, normalized_doi: normalize_doi(doi), title: title, normalized_title: normalize_title(title), title_fingerprint: title_fingerprint(title), authors: authors, author_fingerprint: author_fingerprint(authors), publication_year: year}` — only non-nil values passed, using the signal field whitelist. `normalize_doi/1`, `normalize_title/1`, `title_fingerprint/1`, and `author_fingerprint/1` are private helpers.
- Uploads cleaned text to `source-ingestions/{id}/preprocess/text.txt`
- Calls `transition_source_ingestion_status` to `processing_stage: "preprocess"`
- Returns `{:ok, updated_ingestion}`

**Testing:**
- `TextProcessing.preprocess/1`: each of the 5 steps tested with sample inputs matching Python PoC behavior
- `TextProcessing.cheap_sniff/1`: DOI extracted from BHL-style header; year and title parsed; authors found in `Last, F.M.` format
- `TextProcessing.compute_sha256/1`: produces 64-char hex string
- Preprocess stage: downloads artifact, applies processing, persists sniffed signals, uploads artifact, updates stage
- `record_duplicate_signals/2` called with correct map (nil values excluded)

---

### Task 5: Hash and dedup stage (93b8 ladder)

**Status: Done**

**Depends on:** Task 4 (preprocess persists signals; dedup reads them from ingestion row)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/minhash.ex` (custom implementation)
- Create: `lib/gallformers/ingestion_pipeline/duplicate_detection.ex` (ladder logic)
- Create: `lib/gallformers/ingestion_pipeline/stages/hash_and_dedup.ex`
- Test: `test/gallformers/ingestion_pipeline/minhash_test.exs`
- Test: `test/gallformers/ingestion_pipeline/duplicate_detection_test.exs`
- Test: `test/gallformers/ingestion_pipeline/stages/hash_and_dedup_test.exs`

**Behavior:**

`minhash.ex`:
- `compute_signature(text)` → 128-element list of non-negative integers
- Algorithm:
  1. Normalize text: lowercase, strip punctuation, split on whitespace
  2. Generate 5-token shingles (sliding window over token list)
  3. Hash each shingle with each of 128 hash functions: use `h_i(shingle) = (a_i * hash(shingle) + b_i) mod large_prime` where `a_i`, `b_i` are pre-seeded constants (define as module-level `@hash_params` list of 128 `{a, b}` tuples, seeded deterministically)
  4. For each of the 128 hash functions, take the minimum hash value across all shingles
  5. Returns the 128-element list
- `similarity(sig1, sig2)` → float 0.0–1.0 — count equal elements at same positions, divide by 128
- Signature must be deterministic for the same input across restarts

`duplicate_detection.ex`:
- `run_ladder(ingestion, candidates)` where `candidates` is the list of all other `SourceIngestion` rows with signals to compare against
- Implements the 93b8 ladder in order:
  1. **Exact `raw_input_sha256` match** — same file uploaded twice; auto-confirm, return `{:exact_duplicate, candidate}`. Query via `Repo` (not through Ingestions context) for performance: `from s in SourceIngestion, where: s.raw_input_sha256 == ^hash and s.id != ^id`
  2. **Exact `preprocessed_text_sha256` match with non-conflicting metadata** — check that sniffed `normalized_doi` or `publication_year` does not directly contradict the candidate; auto-confirm, return `{:exact_duplicate, candidate}`
  3. **Exact `normalized_doi` match** — DOI is the strongest bibliographic key; auto-confirm, return `{:exact_duplicate, candidate}`
  4. **Strong bibliographic match** (`title_fingerprint` match AND (`author_fingerprint` match OR `publication_year` match)) — return `{:probable_duplicate, candidate, evidence_map}` where `evidence_map` describes which signals matched
  5. **High MinHash similarity** (≥ 0.9) — return `{:probable_duplicate, candidate, evidence_map}`
  6. **Moderate MinHash similarity** (0.7–0.9) — return `{:probable_duplicate, candidate, evidence_map}`
  7. **No signal** — return `:no_match`
- Returns the highest-confidence result found (exact > probable > no match)
- Candidate fetching: load all ingestions with a non-nil signal (by joining on any populated signal field) — this is a DB query inside `duplicate_detection.ex` using `Repo` directly, scoped to exclude the current ingestion and terminal-status ingestions (`duplicate_confirmed`, `failed`)

`stages/hash_and_dedup.ex`:
- Implements `StageWorker`; `stage_name/0` returns `:hash_and_dedup`
- Loads current ingestion (with all signal fields populated from preprocess stage)
- Computes `minhash_signature` from the preprocessed text (downloads `preprocess/text.txt`, calls `MinHash.compute_signature/1`)
- Persists `minhash_signature` via `record_duplicate_signals/2`
- Calls `DuplicateDetection.run_ladder/2`
- On `{:exact_duplicate, candidate}`:
  - Calls `Ingestions.create_duplicate_candidate/3` to record the link with `status: "auto_confirmed"`
  - Calls `Ingestions.confirm_duplicate_candidate/2` on that candidate with system attrs
  - Transitions ingestion to `status: "duplicate_confirmed"` via `transition_source_ingestion_status/3` (this auto-sets `processing_stage: "duplicate_review"`)
  - Broadcasts `{:stage_complete, :hash_and_dedup}` and `{:review_ready, ingestion_id}` (auto-confirms skip to done)
  - Returns `{:ok, updated_ingestion}`
- On `{:probable_duplicate, candidate, evidence}`:
  - Calls `Ingestions.create_duplicate_candidate/3` with `%{evidence: evidence}` for each probable match
  - Transitions to `status: "needs_duplicate_review"` via `transition_source_ingestion_status/3` (auto-sets `processing_stage: "duplicate_review"`)
  - Broadcasts `{:needs_duplicate_review, candidates}`
  - Returns `{:ok, updated_ingestion}` — orchestrator sees `needs_duplicate_review` status and does NOT re-enqueue
- On `:no_match`:
  - Transitions `processing_stage` to `"hash_and_dedup"` via `transition_source_ingestion_status/3`
  - Broadcasts `{:stage_complete, :hash_and_dedup}`
  - Returns `{:ok, updated_ingestion}` — orchestrator re-enqueues for `llm_clean`

**Testing:**
- `MinHash.compute_signature/1`: 128-element list; identical inputs produce identical signatures; similar texts produce similarity > 0.9; dissimilar texts produce similarity < 0.5; deterministic across calls
- `MinHash.similarity/2`: 1.0 for identical signatures, 0.0 for completely different
- `DuplicateDetection.run_ladder/2`: exact SHA match returns `{:exact_duplicate, _}`; exact DOI match returns `{:exact_duplicate, _}`; high MinHash returns `{:probable_duplicate, _, _}`; no signals returns `:no_match`
- Stage: auto-confirm path sets `duplicate_confirmed` status and creates `auto_confirmed` candidate record
- Stage: probable match creates candidate records, sets `needs_duplicate_review`, does not continue pipeline
- Stage: no match continues to `hash_and_dedup` processing_stage

---

### Task 6: LLM client

**Status: Done**

**Depends on:** Task 1

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/llm_client.ex`
- Test: `test/gallformers/ingestion_pipeline/llm_client_test.exs`

**Behavior:**

`llm_client.ex`:
- `completion(stage, system_prompt, user_text, opts \\ [])` where `stage` is an atom like `:llm_clean`, `:metadata`, `:data_extract`
- Reads model for the stage from `Application.get_env(:gallformers, :ingestion_pipeline, %{}) |> get_in([:models, stage])`. Falls back to `"deepseek-ai/DeepSeek-V3-0324"` if not configured.
- Reads API key from `System.fetch_env!("DEEPINFRA_API_KEY")`
- Base URL: `"https://api.deepinfra.com/v1/openai/chat/completions"`
- Makes a `Req.post/2` call with:
  ```json
  {
    "model": "<model>",
    "messages": [
      {"role": "system", "content": "<system_prompt>"},
      {"role": "user", "content": "<user_text>"}
    ],
    "max_tokens": <max_tokens>
  }
  ```
  Headers: `Authorization: Bearer <api_key>`, `Content-Type: application/json`
- `opts` supports: `max_tokens: integer` (default 8192), `merge_prompt: boolean` (default false — when true, merges system and user content into a single user message, needed for data_extract)
- Returns `{:ok, response_text, %{prompt_tokens: n, completion_tokens: n}}` on HTTP 200
- Returns `{:error, :rate_limited}` on HTTP 429
- Returns `{:error, :server_error, status}` on HTTP 5xx
- Returns `{:error, :timeout}` on `Req` timeout (configure `receive_timeout: 120_000`)
- Retries up to 3 times with exponential backoff (1s, 2s, 4s) on 5xx and timeout; does NOT retry on 429 (caller decides)

`chunk_text(text, max_chars)` — helper to split text on `"\n\n"` paragraph boundaries into chunks of at most `max_chars` characters. Returns list of strings. Used by stage modules, not by `LLMClient` directly.

**Config (add to `config/config.exs`):**
```elixir
config :gallformers, :ingestion_pipeline,
  models: %{
    llm_clean: "deepseek-ai/DeepSeek-V3-0324",
    metadata: "deepseek-ai/DeepSeek-V3-0324",
    data_extract: "deepseek-ai/DeepSeek-V3-0324"
  }
```

**Testing:**
- Uses `Req.Test` or a mock — do NOT make real HTTP calls in tests
- Successful 200 response returns `{:ok, text, usage}`
- 429 returns `{:error, :rate_limited}` with no retry
- 5xx triggers retry up to 3 times then returns `{:error, :server_error, status}`
- Timeout returns `{:error, :timeout}`
- `merge_prompt: true` sends single user message with combined content
- `chunk_text/2`: chunks respect paragraph boundaries; no chunk exceeds max_chars; very long paragraphs not split mid-paragraph (accepted as oversized chunk)

---

### Task 7: LLM Clean stage

**Status: Done**

**Depends on:** Tasks 5 and 6

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/llm_clean.ex`
- Create: `priv/prompts/llm_clean.txt` (port from `services/source-ingestion/prompts/cleanup.md`)
- Test: `test/gallformers/ingestion_pipeline/stages/llm_clean_test.exs`

**Behavior:**
- Implements `StageWorker`; `stage_name/0` returns `:llm_clean`
- Downloads `source-ingestions/{id}/preprocess/text.txt` via `Storage.download_artifact/3`
- Loads prompt from `priv/prompts/llm_clean.txt` via `File.read!/1` using `:code.priv_dir(:gallformers)`
- Chunks text into 6000-char chunks via `LLMClient.chunk_text/2`
- For each chunk, calls `LLMClient.completion(:llm_clean, prompt, chunk)` with `max_tokens: 8192`
- Processes up to 4 chunks in parallel using `Task.async_stream/3` with `max_concurrency: 4`
- Concatenates results in order with `"\n\n"` separator
- On any chunk error: returns `{:error, reason}` immediately (does not partial-upload)
- Uploads concatenated result to `source-ingestions/{id}/llm_clean/text.txt`
- Transitions `processing_stage` to `"llm_clean"`
- Broadcasts `{:stage_complete, :llm_clean}`
- Returns `{:ok, updated_ingestion}`

**Prompt** (`priv/prompts/llm_clean.txt`): Port faithfully from `services/source-ingestion/prompts/cleanup.md`. System role: scholarly document formatter. Task: clean OCR/PDF-extracted text to well-formatted Markdown. Rules: fix OCR artifacts, preserve text faithfully (no paraphrasing), apply markdown formatting, italicize Latin binomials, return only cleaned markdown.

**Testing:**
- LLMClient mock returns cleaned text for each chunk
- Multiple chunks concatenated in order
- Artifact uploaded to correct path
- Chunk error propagates as stage error
- `processing_stage` transitions to `"llm_clean"`

---

### Task 8: Metadata stage

**Status: Done**

**Depends on:** Tasks 6 and 7

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/metadata.ex`
- Create: `priv/prompts/metadata.txt` (port from `services/source-ingestion/prompts/metadata.md`)
- Test: `test/gallformers/ingestion_pipeline/stages/metadata_test.exs`

**Behavior:**
- Implements `StageWorker`; `stage_name/0` returns `:metadata`
- Downloads `source-ingestions/{id}/llm_clean/text.txt`
- Loads prompt from `priv/prompts/metadata.txt`
- Truncates input to 24000 chars (metadata is near the start of documents) before passing to LLM
- Calls `LLMClient.completion(:metadata, prompt, truncated_text, max_tokens: 1024)`
- Parses JSON response with `Jason.decode/1`; handles fenced markdown code blocks (strip ` ```json ... ``` ` wrapper if present)
- Retries up to 3 times on unparseable JSON (Oban's own retry is for transient errors; these 3 retries are within a single `perform` call for JSON parse failures)
- Expected JSON shape: `%{"title" => string | nil, "authors" => [string], "year" => integer | nil, "doi" => string | nil}`
- On successful parse:
  - Calls `Ingestions.record_duplicate_signals/2` with normalized values: `%{title: title, normalized_title: normalize_title(title), authors: authors, publication_year: year, doi: doi, normalized_doi: normalize_doi(doi)}`
  - Uploads raw JSON response to `source-ingestions/{id}/metadata/output.json`
  - Transitions `processing_stage` to `"metadata"`
  - Broadcasts `{:stage_complete, :metadata}`
  - Returns `{:ok, updated_ingestion}`
- On JSON parse failure after 3 retries: returns `{:error, :invalid_json}`

**Prompt** (`priv/prompts/metadata.txt`): Port from `services/source-ingestion/prompts/metadata.md`. System role: bibliographic metadata extractor. Task: extract title, authors, year, doi. Return ONLY valid JSON with those four keys. Use null for missing fields, empty list for unknown authors.

**Testing:**
- Valid JSON response parsed and persisted via `record_duplicate_signals/2`
- Fenced JSON block (` ```json\n...\n``` `) unwrapped correctly
- Malformed JSON triggers retry; after 3 failures returns `{:error, :invalid_json}`
- Artifact uploaded to correct path
- Normalized DOI and title stored

---

### Task 9: Data extract stage

**Status: Done**

**Depends on:** Tasks 6 and 7

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/data_extract.ex`
- Create: `priv/prompts/data_extract.txt` (port from `services/source-ingestion/prompts/data-extract.md`)
- Test: `test/gallformers/ingestion_pipeline/stages/data_extract_test.exs`

**Behavior:**

`data_extract.ex`:
- Implements `StageWorker`; `stage_name/0` returns `:data_extract`
- Downloads `source-ingestions/{id}/llm_clean/text.txt` (reads from llm_clean, not metadata)
- Loads prompt from `priv/prompts/data_extract.txt`
- Chunks text into 3000-char chunks via `LLMClient.chunk_text/2`
- For each chunk, calls `LLMClient.completion(:data_extract, prompt, chunk, max_tokens: 6000, merge_prompt: true)` — `merge_prompt: true` mirrors the Python PoC behavior (system + user merged into user message)
- Processes up to 4 chunks in parallel via `Task.async_stream/3`
- Parses each chunk response as a JSON array; on parse error, retries chunk up to 3 times within the call
- Merges all per-chunk record arrays in order
- Validates merged result via `Schema.validate/1`
- On valid contract: uploads to `source-ingestions/{id}/data_extract/output.json`; transitions `processing_stage` to `"data_extract"`; broadcasts `{:stage_complete, :data_extract}`; returns `{:ok, updated_ingestion}`
- On invalid contract: returns `{:error, :invalid_contract, details}`

**Prompt** (`priv/prompts/data_extract.txt`): Port faithfully from `services/source-ingestion/prompts/data-extract.md`. This is the most complex prompt (~150 lines). Preserve all controlled vocabulary lists, confidence scale, and extraction rules verbatim.

**Testing:**
- Valid records pass `Schema.validate/1`
- Missing required field returns `{:error, :invalid_contract, _}`
- Chunk results merged in order
- `merge_prompt: true` passed to `LLMClient.completion/5`
- Artifact at correct S3 path
- `processing_stage` transitions to `"data_extract"`

---

### Task 10: Assemble stage

**Status: Done**

**Depends on:** Tasks 8 and 9

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/assemble.ex`
- Test: `test/gallformers/ingestion_pipeline/stages/assemble_test.exs`

**Behavior:**
- Implements `StageWorker`; `stage_name/0` returns `:assemble`
- Downloads `source-ingestions/{id}/data_extract/output.json` and `source-ingestions/{id}/metadata/output.json`
- Parses both as JSON
- **Species resolution:** for each gall record's `gall_species.name` and `host_species.name`:
  - Call `Gallformers.Species.search_species_by_name(name, taxoncode, 5)` (taxoncode `"gall"` for gall species, `"plant"` for host species)
  - Call `Gallformers.Species.find_species_with_alias(name)` for alias lookup
  - Merge and deduplicate results by `species_id`
  - If exactly one match found: mark as resolved with `species_id`
  - If zero or multiple matches: mark as unresolved, flag for reviewer
- Assembles a Markdown document:
  - YAML frontmatter block: `title`, `authors`, `year`, `doi` from metadata
  - Per-record sections: `## <gall_species.name>` heading; prose `description` block; traits table (trait name | original text | suggested value); host species line; resolved/unresolved species note; `confidence` noted
  - Unresolved species mentions flagged with `<!-- UNRESOLVED: <name> -->` HTML comment
- Uploads to `source-ingestions/{id}/assemble/output.md` with content type `"text/markdown"`
- Transitions `processing_stage` to `"assemble"`
- Broadcasts `{:stage_complete, :assemble}`
- Returns `{:ok, updated_ingestion}`

**Testing:**
- Markdown generated with correct frontmatter and per-record sections
- Resolved species noted; unresolved flagged with comment
- Exact match (one result) resolves; zero matches flags as unresolved; multiple matches flags as unresolved
- Artifact at correct S3 path

---

### Task 11: Upload stage (finalization)

**Status: Done**

**Depends on:** Task 10

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/stages/upload.ex`
- Test: `test/gallformers/ingestion_pipeline/stages/upload_test.exs`

**Behavior:**
- Implements `StageWorker`; `stage_name/0` returns `:upload`
- Lists all objects under `source-ingestions/{id}/` prefix via `IngestionPipeline.Storage` backend to compile artifact manifest (list of S3 keys)
- Calls `transition_source_ingestion_status(ingestion, "needs_review", %{processing_stage: "review"})` — this is the correct terminal state for a normal pipeline run; the ingestion is now ready for human review in `7c67`
- Broadcasts `{:review_ready, ingestion_id}` via `Broadcaster.broadcast_review_ready/1`
- Returns `{:ok, updated_ingestion}`

Note on status/stage semantics: `status: "needs_review"` means the ingestion is complete and awaiting a human reviewer. `processing_stage: "review"` is the corresponding stage value (set automatically by `put_default_stage_for_status` in `transition_source_ingestion_status/3`). The orchestrator treats `"review"` and `"complete"` as terminal — it will not re-enqueue.

**Testing:**
- Status transitions to `"needs_review"` and `processing_stage` to `"review"`
- `broadcast_review_ready/1` called with correct ingestion ID
- Artifact manifest correctly lists all stage artifacts

---

### Task 11.1: JSON Schema for data validation

**Status: Done**

**Depends on:** Task 9

**Files:**
- Create: `priv/schemas/gall_record.json`
- Create: `lib/gallformers/ingestion_pipeline/schema.ex`

**Behavior:**
- Single JSON Schema file defines the gall_record structure (all fields, types, vocabularies)
- Schema module loads schema, renders for LLM prompts, validates output
- Schema auto-injected into prompt via `{{SCHEMA}}` placeholder
- Schema validates trait values against vocabulary enums
- Replace current `DataContract.validate/1` with `Schema.validate/1`

**Dependencies:**
- Add `ex_json_schema` to `mix.exs`

**Testing:**
- Schema validates valid record → passes
- Schema rejects missing required fields → fails with details
- Schema rejects invalid trait values (shape, color, etc.) → fails

---

### Task 12: Duplicate review resolution

**Status: Done**

**Depends on:** Task 5 (Hash and dedup creates candidates)

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/duplicate_resolution.ex`
- Test: `test/gallformers/ingestion_pipeline/duplicate_resolution_test.exs`

**Behavior:**
- Thin adapter over `Gallformers.Ingestions` context for pipeline-specific duplicate operations. The `7c67` UI calls these functions when a reviewer acts on a duplicate candidate.
- `confirm_duplicate(candidate_id, reviewed_by_id)`:
  - Loads candidate via `Ingestions.list_duplicate_candidates/1` or directly
  - Calls `Ingestions.confirm_duplicate_candidate/2` with `%{reviewed_by_id: reviewed_by_id}`
  - Re-enqueues the orchestrator by calling `Worker.enqueue(source_ingestion_id)` — the orchestrator will see `status: "duplicate_confirmed"` and `processing_stage: "duplicate_review"` and treat it as terminal (no further stages)
  - Returns `{:ok, source_ingestion}`
- `reject_duplicate(candidate_id, reviewed_by_id)`:
  - Calls `Ingestions.reject_duplicate_candidate/2` with `%{reviewed_by_id: reviewed_by_id}`
  - After rejection, `reject_duplicate_candidate/2` auto-transitions to `"processing"` / `"duplicate_review"` if no pending candidates remain (this is handled inside the context). If the ingestion is still `"needs_duplicate_review"` (other pending candidates), do nothing further.
  - If ingestion is now `"processing"` (all candidates resolved), re-enqueue orchestrator via `Worker.enqueue/1` to continue pipeline from duplicate-review resume point (next stage is `llm_clean`)
  - Returns `{:ok, source_ingestion}`
- `promote_to_unique(ingestion_id, reviewed_by_id)`:
  - Loads all pending candidates for the ingestion via `Ingestions.list_duplicate_candidates/1`
  - Rejects each via `Ingestions.reject_duplicate_candidate/2`
  - Re-enqueues orchestrator via `Worker.enqueue/1`
  - Returns `{:ok, source_ingestion}`

**Testing:**
- `confirm_duplicate/2` marks candidate as confirmed, re-enqueues orchestrator, ingestion ends at `duplicate_confirmed`
- `reject_duplicate/2` with no remaining candidates: auto-transitions to `processing` / `duplicate_review` (via context), re-enqueues orchestrator
- `reject_duplicate/2` with remaining pending candidates: no re-enqueue
- `promote_to_unique/2` rejects all candidates, re-enqueues orchestrator

---

### Task 13: Integration and end-to-end tests

**Status: Done**

**Depends on:** All previous tasks

**Files:**
- Create: `test/gallformers/ingestion_pipeline/full_pipeline_test.exs`
- Create: `test/support/fixtures/ingestion_pipeline_fixtures.ex`

**Behavior:**

`ingestion_pipeline_fixtures.ex`:
- `source_ingestion_fixture(attrs \\ %{})` — creates a `SourceIngestion` with sensible defaults via `Ingestions.create_source_ingestion/1`
- `duplicate_candidate_fixture(ingestion, candidate, attrs \\ %{})` — creates a `DuplicateCandidate` via `Ingestions.create_duplicate_candidate/3`

Integration flows (all use mock S3 backend, `Oban.Testing` helpers, mock `LLMClient` via `Mox` or similar):

1. **Normal path:** Enqueue orchestrator → stages run in sequence via `perform_job` → final status `"needs_review"`, `processing_stage: "review"`, all 6 stage artifacts exist at expected S3 paths, PubSub messages received in order
2. **Exact hash duplicate path:** Two ingestions with same `preprocessed_text_sha256` → dedup auto-confirms → `status: "duplicate_confirmed"`, `duplicate_of_source_ingestion_id` set, no LLM stages run
3. **Exact DOI duplicate path:** Two ingestions with same `normalized_doi` → dedup auto-confirms
4. **Probable duplicate path:** Ingestion with high MinHash similarity to existing → `status: "needs_duplicate_review"`, candidates created, orchestrator does NOT re-enqueue → reviewer calls `confirm_duplicate/2` → ends at `duplicate_confirmed`
5. **Duplicate rejected path:** Same as above but reviewer calls `reject_duplicate/2` → pipeline continues to `needs_review`
6. **LLM error path:** `LLMClient` mock returns `{:error, :server_error, 500}` for `llm_clean` stage → after Oban retries exhausted, ingestion ends at `status: "failed"`, `error_stage: "llm_clean"` set, error broadcast received

All flows verify:
- Ingestion row `status` and `processing_stage` at each checkpoint
- PubSub messages received in expected order (subscribe before enqueue)
- Artifact keys exist in mock S3 backend
- Duplicate candidates created/managed correctly via context

**Completed notes:**
- Added `test/support/fixtures/ingestion_pipeline_fixtures.ex` for ingestion and duplicate-candidate setup
- Added `test/gallformers/ingestion_pipeline/full_pipeline_test.exs` covering the normal path, exact hash duplicate, exact DOI duplicate, probable duplicate confirm, probable duplicate reject/resume, and final-attempt LLM failure semantics
- Implemented the decided worker retry behavior so the ingestion remains on its runnable checkpoint until the final Oban attempt, with `failed/failed` only persisted after retries are exhausted

---

### Task 14: OpenTofu S3 configuration for ingestion prefix

Moves to a separate matter [db32](∏db32-split-source-ingestion-storage-into-public-published-sources-and-private-pipeline-artifacts.md)
