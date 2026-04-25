---
status: done
created: 2026-04-23
updated: 2026-04-24
epic: ingestion
blocks: [a80e]
parent: 7fda
---

# Formalize ingestion pipeline workflow as an explicit state machine

## Problem

The ingestion pipeline already behaves like a state machine, but the transition logic is currently distributed across the worker, stage modules, the ingestion context, and duplicate-resolution helpers. The result is an implicit workflow model with multiple owners.

Recent example: duplicate-review rejection semantics drifted apart between the ingestion context, orchestrator assumptions, and the Task 12 plan. That inconsistency was fixable, but it demonstrates the architectural problem: the codebase has a workflow, but not a single workflow authority.

## Design

**Architecture:** Introduce a single internal workflow module, likely `Gallformers.IngestionPipeline.Workflow`, that becomes the authority for:
- canonical state representation
- legal `status` / `processing_stage` combinations
- transition events and their resulting state changes
- paused / terminal / resumable predicates
- next runnable stage resolution for the orchestrator

**Persistence boundary:** Keep the existing DB representation for now (`status` + `processing_stage` on `SourceIngestion`). Do not introduce a third-party FSM library and do not change the schema unless the refactor proves the current representation is insufficient.

**Critical semantic rule:** `processing_stage` should be treated as a durable checkpoint, not a literal “currently running stage” field. Under current behavior, examples are:
- `processing/submitted` means next stage is `extract`
- `processing/extract` means `extract` finished and next stage is `preprocess`
- `processing/assemble` means `assemble` finished and next stage is `upload`
- `needs_duplicate_review/duplicate_review` means paused for human review
- `processing/duplicate_review` means duplicate review resolved and next stage is `llm_clean`
- `needs_review/review` means pipeline finished and human review is now unlocked

The workflow module must make this meaning explicit and central, so other modules stop encoding their own interpretation.

**Canonical reachable states:** The workflow module should explicitly define the allowed persisted states under current intended behavior:
- `processing/submitted`
- `processing/extract`
- `processing/preprocess`
- `processing/hash_and_dedup`
- `needs_duplicate_review/duplicate_review`
- `processing/duplicate_review`
- `duplicate_confirmed/duplicate_review`
- `processing/llm_clean`
- `processing/metadata`
- `processing/data_extract`
- `processing/assemble`
- `needs_review/review`
- `complete/complete`
- `failed/failed`

**Open semantic cleanup to resolve during implementation:** `upload` currently exists in `SourceIngestion.processing_stages/0`, but current code does not persist `processing/upload`; `upload` is an execution step inferred from `processing/assemble`. This matter should normalize that intentionally instead of leaving it ambiguous. Default preference: preserve the current checkpoint model and keep `upload` as a stage module name rather than a persisted checkpoint, unless a strong reason emerges to change it.

**Workflow API target:** The concrete API can evolve during implementation, but the module should provide equivalents of:
- `state/1` or `status_stage/1`
- `next_stage/1`
- `transition/3` or `transition_attrs/2`
- `paused?/1`
- `terminal?/1`
- `valid_state?/1`

The worker should ask the workflow module what to do next. Stage modules and duplicate-review helpers should ask the workflow module what transition to persist.

## What Is Already Implemented (Refactor, Do Not Recreate)

The following modules already implement pipeline behavior and must be refactored around the workflow module rather than replaced wholesale:

- `lib/gallformers/ingestion_pipeline/worker.ex` — current next-stage routing and failure handling
- `lib/gallformers/ingestion_pipeline/stage_worker.ex` — stage behaviour
- `lib/gallformers/ingestion_pipeline/stages/*.ex` — current stage success transitions and side effects
- `lib/gallformers/ingestion_pipeline/duplicate_resolution.ex` — duplicate-review adapter and orchestrator re-enqueue behavior
- `lib/gallformers/ingestions.ex` — persistence boundary, duplicate candidate operations, and current status/stage transition helper
- `lib/gallformers/ingestions/source_ingestion.ex` — allowed `status` and `processing_stage` values
- Existing tests under `test/gallformers/ingestion_pipeline/` and `test/gallformers/ingestions_test.exs`

## Implementation Plan

**Goal:** Replace the current implicit ingestion workflow with a single explicit, testable workflow model before continuing remaining ingestion pipeline work in `a80e`.

---

### Task 1: Workflow module foundations and transition table

**Status: Done**

**Files:**
- Create: `lib/gallformers/ingestion_pipeline/workflow.ex`
- Create: `test/gallformers/ingestion_pipeline/workflow_test.exs`

**Behavior:**
- Define canonical workflow state helpers around `status` + `processing_stage`
- Encode the legal persisted states listed in this matter
- Encode paused / terminal / resumable predicates
- Encode next runnable stage resolution for each reachable state
- Encode transition events for:
  - stage success checkpoints
  - stage failure
  - probable duplicate pause
  - duplicate confirmed terminal state
  - duplicate rejected resume state
  - review-ready terminal state
  - complete terminal state
- Make an explicit decision about whether `processing/upload` is a valid persisted state or whether `upload` remains a non-persisted execution step. Preserve current checkpoint semantics unless a concrete implementation need justifies otherwise.

**Testing:**
- Direct tests for every legal state
- Illegal combinations rejected by `valid_state?/1` or equivalent helper
- `next_stage/1` returns the correct answer for every non-terminal state
- Duplicate-review states distinguish paused vs resumable vs terminal duplicate outcomes
- Failure and review-ready transitions resolve to the intended terminal states

---

### Task 2: Move orchestrator routing into the workflow module

**Status: Done**

**Files:**
- Modify: `lib/gallformers/ingestion_pipeline/worker.ex`
- Modify: `test/gallformers/ingestion_pipeline/worker_test.exs`

**Behavior:**
- Remove the worker-owned routing table as the workflow authority
- Refactor the worker to ask the workflow module what to do next:
  - run a stage
  - pause
  - no-op terminal state
- Keep the worker responsible for job execution and re-enqueue mechanics, but not for owning the workflow semantics
- Refactor failure handling so the worker uses workflow transitions instead of hand-assembling failed-state attrs

**Testing:**
- Existing worker routing tests updated to assert through workflow-driven behavior
- Duplicate-review paused and resumed flows still behave correctly
- Terminal states remain no-op
- Failure path persists the correct failed state through the workflow module

---

### Task 3: Centralize stage success transitions

**Status: Done**

**Files:**
- Modify: `lib/gallformers/ingestion_pipeline/stages/extract.ex`
- Modify: `lib/gallformers/ingestion_pipeline/stages/preprocess.ex`
- Modify: `lib/gallformers/ingestion_pipeline/stages/hash_and_dedup.ex`
- Modify: `lib/gallformers/ingestion_pipeline/stages/llm_clean.ex`
- Modify: `lib/gallformers/ingestion_pipeline/stages/metadata.ex`
- Modify: `lib/gallformers/ingestion_pipeline/stages/data_extract.ex`
- Modify: `lib/gallformers/ingestion_pipeline/stages/assemble.ex`
- Modify: `lib/gallformers/ingestion_pipeline/stages/upload.ex`
- Modify related tests under `test/gallformers/ingestion_pipeline/stages/`

**Behavior:**
- Replace raw `transition_source_ingestion_status/3` calls in stage modules with workflow-driven transitions
- Preserve all existing side effects:
  - artifact uploads
  - duplicate-signal persistence
  - broadcasts
  - duplicate-candidate creation
- Keep stage modules focused on business work for that stage; they should no longer own ad hoc state-pair assembly
- Normalize success semantics so stage completion always flows through the same workflow transition path

**Testing:**
- Existing stage tests remain green with updated expectations only where workflow centralization changes the call path, not the behavior
- Upload stage still produces `needs_review/review`
- Hash-and-dedup still distinguishes exact duplicate, probable duplicate pause, and no-match continuation

---

### Task 4: Refactor duplicate-review resolution around workflow transitions

**Status: Done**

**Files:**
- Modify: `lib/gallformers/ingestion_pipeline/duplicate_resolution.ex`
- Modify: `lib/gallformers/ingestions.ex`
- Modify: `test/gallformers/ingestion_pipeline/duplicate_resolution_test.exs`
- Modify: `test/gallformers/ingestions_test.exs`

**Behavior:**
- Remove duplicate-review transition semantics from scattered helpers where possible and route them through the workflow module
- Preserve current intended behavior from `a80e`:
  - confirm duplicate → `duplicate_confirmed/duplicate_review`, terminal
  - reject final pending candidate → `processing/duplicate_review`, resumable, next stage `llm_clean`
  - reject one of multiple pending candidates → remain paused at `needs_duplicate_review/duplicate_review`
- Keep the ingestion context as the persistence boundary and concurrency/race-control boundary for duplicate candidate updates
- Keep the duplicate-resolution adapter responsible for re-enqueueing the orchestrator when the workflow says the ingestion is resumable

**Testing:**
- Duplicate confirm remains terminal and re-enqueues only so the orchestrator can observe the terminal state
- Duplicate reject with no remaining candidates resumes processing
- Duplicate reject with pending candidates does not resume
- Promote-to-unique rejects all pending candidates and resumes processing

---

### Task 5: Add state-pair guardrails and regression coverage

**Status: Done**

**Files:**
- Modify: `lib/gallformers/ingestions/source_ingestion.ex`
- Modify: `lib/gallformers/ingestions.ex`
- Modify: `test/gallformers/ingestions_test.exs`
- Modify or create additional focused tests in `test/gallformers/ingestion_pipeline/`

**Behavior:**
- Add guardrails so invalid `status` / `processing_stage` combinations are rejected or at least validated centrally before persistence
- Minimize or remove `put_default_stage_for_status/2` if the workflow module makes it redundant
- Ensure there is one obvious place in the codebase to answer:
  - what combinations are valid
  - what event caused the transition
  - what the next runnable stage is
  - whether the state is paused or terminal
- Audit all remaining raw string-based status/stage manipulation in the ingestion pipeline and reduce it to intentional exceptions only

**Testing:**
- Invalid combinations fail fast in unit tests
- Existing ingestion context tests updated to reflect centralized semantics
- New regression tests specifically cover the semantic mismatch that motivated this matter: duplicate-review rejection resume behavior

---

### Task 6: Reconcile `a80e` follow-on work against the centralized workflow

**Status: Done**

**Depends on:** Tasks 1-5

**Files:**
- Modify: `test/gallformers/ingestion_pipeline/full_pipeline_test.exs` (when Task 13 begins in `a80e`)
- Modify any remaining `a80e` tests that assume pre-workflow semantics

**Behavior:**
- Update the remaining pipeline work to build on the centralized workflow model instead of the older implicit one
- Ensure future `a80e` implementation does not reintroduce ad hoc state-pair logic
- Treat this matter as the prerequisite workflow normalization before completing the remaining pipeline tasks

**Testing:**
- Full-pipeline integration tests added in `a80e` should assert against the workflow module’s semantics, not re-derive them locally

**Completed notes:**
- Reconciled the remaining `a80e` pipeline coverage against `Gallformers.IngestionPipeline.Workflow` rather than older worker-owned state assumptions
- Updated worker failure handling so intermediate Oban retries leave the ingestion resumable and only the final attempt persists `failed/failed`
- Added full-pipeline integration coverage that asserts centralized workflow checkpoints for normal, duplicate, resume, and terminal failure paths

## Acceptance Criteria

- There is one workflow module that clearly owns ingestion workflow semantics
- The worker no longer owns the authoritative routing table
- Stage modules no longer hand-assemble raw status/stage pairs for normal workflow transitions
- Duplicate-review pause/resume semantics are defined once and reused everywhere
- Invalid state-pair combinations are guarded against explicitly
- The refactor preserves current intended user-facing behavior while reducing semantic drift risk

## Dependency Note

This matter should be completed before finishing the remaining ingestion pipeline work in `a80e`, because otherwise more transition logic will continue to accrete around the current implicit model.
