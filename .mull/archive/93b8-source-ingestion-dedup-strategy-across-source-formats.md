---
status: done
created: 2026-04-21
updated: 2026-04-21
epic: ingestion
relates: [7fda]
blocks: [664d, a80e]
parent: 7fda
---

# Source ingestion dedup strategy across source formats

## Decision Summary

Source-ingestion dedup should be modeled as **multi-signal duplicate detection over submissions**, not as a single canonical content hash.

The system should distinguish three different questions that the current PoC and early plans blur together:
- **Is this the exact same uploaded artifact?**
- **Is this the exact same normalized text after deterministic preprocessing?**
- **Is this the same underlying article across different representations (PDF, publisher HTML, OCR, manually cleaned text)?**

Those are related, but they are not the same identity.

## Core Decision

### 1. There is no single universal article identity key

We should not force DOI, title metadata, or preprocess hash to serve as the one true canonical key.

Instead:
- `source_ingestions` represent individual submissions / processing attempts
- duplicate detection produces relationships between ingestions
- one ingestion may be chosen as the **canonical ingestion** for a duplicate set
- `normalized_doi` is the strongest hard identity signal when present, but not every document has one
- exact preprocess hash is an exact-normalized-text signal, not the article identity by itself

This keeps the model honest. It avoids pretending we know more than we do when metadata is partial or OCR-distorted.

### 2. Keep every input as its own ingestion row

If the same article is uploaded three ways, we should still keep three ingestion records.

Why:
- preserves provenance of what was uploaded and by whom
- supports review-first duplicate confirmation instead of silent collapse
- allows us to compare extraction quality across inputs
- lets operators understand why a candidate was flagged
- avoids overloading a hash array as both identity and audit trail

Confirmed duplicates should be linked, not erased.

## Signal Model

We should store and reason about duplicate signals in four classes.

### A. Same-upload signal

**Purpose:** resume / idempotency for identical submissions, not article identity.

Store:
- `raw_input_sha256` or equivalent byte hash when available

Interpretation:
- identical bytes means "this upload is the same file/input payload"
- useful for avoiding reruns or retry duplication
- not sufficient for same-article claims across formats

### B. Exact normalized-text signal

**Purpose:** identify exact matches after deterministic cleanup.

Store:
- `preprocessed_text_sha256`

Interpretation:
- strongest non-DOI exact-match signal we have
- good for exact aliases and artifact reuse decisions
- still too brittle to be the only duplicate mechanism across PDF/HTML/OCR/manual variants

This should answer the question "is this only an exact normalized-text match?" explicitly.

### C. Bibliographic identity signals

**Purpose:** identify the same article even when text differs.

Store normalized forms of:
- `normalized_doi`
- `normalized_title`
- `title_fingerprint`
- `author_fingerprint`
- `publication_year`

Notes:
- DOI normalization should strip resolver prefixes, lowercase, and trim punctuation
- title normalization should lowercase, collapse whitespace, strip punctuation noise, and ASCII-fold where useful
- author fingerprinting should favor stable surname-based matching rather than exact raw author strings
- year should tolerate small extraction ambiguity, but exact year still matters

Interpretation:
- DOI is the strongest identity signal and the only one strong enough for routine automatic duplicate confirmation on its own
- exact/near title plus author/year is a strong probable-duplicate signal, but still reviewable rather than silently merged

### D. Fuzzy text similarity signal

**Purpose:** catch same-article/different-format cases where exact normalized text does not match.

**Chosen approach:** MinHash over normalized token shingles.

For v1, prefer:
- normalized lowercase token stream from deterministic preprocess output
- 5-token shingles
- MinHash signature persisted on the ingestion record or in a related signal table

Why MinHash over SimHash for this matter:
- it maps cleanly to approximate Jaccard overlap on shingle sets, which is easier to reason about
- it is more explainable to maintainers than bit-distance thresholds on SimHash
- it is robust to insertions/deletions and moderate OCR/layout variation
- our expected ingestion volume is small enough that we do not need a web-scale-only technique optimized primarily for compression

Why not use an LLM for duplicate judgment:
- expensive in exactly the stage we are trying to keep cheap
- harder to explain operationally
- unnecessary when deterministic signals are sufficient for candidate generation

SimHash is not forbidden forever, but it should not be the first production choice.

## Production Decision Ladder

The production path should use an explicit rule ladder, not an opaque weighted score.

### Stage 0: create the ingestion record immediately

On submission, create a `source_ingestions` row and assign an immutable ingestion-id-based artifact prefix.

Do **not** wait for dedup resolution to decide whether the submission exists.

### Stage 1: extract and preprocess

After raw extraction and deterministic preprocess, compute the cheap signals:
- raw-input hash if available
- preprocess-text hash
- deterministic DOI extraction if possible
- cheap title/author/year guesses when available from extractors or document metadata
- MinHash signature when the document is long enough to justify it

### Stage 2: duplicate candidate lookup

Check existing ingestions in this order:

1. **Exact DOI match**
   - treat as exact article duplicate
   - default action: auto-confirm duplicate and link to the canonical ingestion
   - still preserve the new ingestion row for provenance

2. **Exact preprocess hash match**
   - if metadata is non-conflicting or corroborating, auto-confirm as exact-text duplicate
   - if metadata conflicts or is missing in a suspicious way, send to duplicate review instead of silently merging

3. **Strong metadata match**
   - exact or very-close title match
   - author fingerprint overlap
   - same year or narrowly tolerable year difference
   - result: create duplicate candidate for reviewer confirmation

4. **High fuzzy-text similarity**
   - MinHash similarity above a conservative threshold
   - preferably corroborated by at least one metadata signal unless text similarity is extremely high
   - result: create duplicate candidate for reviewer confirmation

5. **No strong signal**
   - continue through the expensive LLM stages

### Stage 3: later metadata can backfill future dedup quality

The full metadata stage later in the pipeline should still write normalized DOI/title/author/year back onto the ingestion record.

That does two things:
- improves future duplicate detection for later submissions
- allows retrospective duplicate candidates to be created if a later stage discovers a DOI that the cheap path missed

That does **not** mean we should delay all dedup until after the expensive stages.

## Exact vs Probable Duplicate Semantics

The system should present duplicate outcomes in explicit categories.

### Exact duplicate

Use this when one of the following is true:
- `normalized_doi` matches exactly
- `preprocessed_text_sha256` matches exactly and there is no conflicting bibliographic evidence

Outcome:
- new ingestion is linked to the canonical ingestion automatically or with minimal operator confirmation depending on implementation preference
- new ingestion does not proceed to expensive review work unless explicitly promoted

### Probable duplicate

Use this when the ingestion is strongly suspicious but not safe to collapse silently, for example:
- strong title/author/year match without DOI
- high MinHash similarity with metadata support
- exact preprocess hash with conflicting or incomplete metadata

Outcome:
- ingestion enters explicit duplicate-review state
- reviewer sees evidence and decides whether to merge or keep separate

### Not a duplicate

No strong signals or reviewer rejected the candidate.

Outcome:
- continue or remain in the standard ingestion review flow

## Canonical Storage And Alias Semantics

### Artifact prefixes should be ingestion-ID-based, not hash-based

Do not make preprocess hash, DOI, or title fingerprint the storage key.

Use something like:
- `source-ingestions/<ingestion-id>/...`

Why:
- duplicate identity may change after review
- canonical ingestion may change if a later submission has cleaner extraction
- immutable per-ingestion prefixes preserve provenance and avoid rename problems

### Canonical ingestion is a relationship, not a path convention

When duplicates are confirmed:
- choose one ingestion as canonical for downstream review work
- point duplicate ingestions at it via explicit linkage
- keep duplicate ingestions' own prefixes for their raw/extracted/preprocessed artifacts and audit trail

This also leaves room for a reviewer to promote a newer, cleaner ingestion as canonical later.

### Do not use `content_hashes` as the primary duplicate model

A `content_hashes` cache on `source_ingestions` is acceptable as a convenience if we later want one.

It should **not** be the source of truth.

The source of truth should be:
- each ingestion row storing its own signals
- explicit duplicate/candidate records linking ingestions

That is cleaner than treating an array of alias hashes as the whole dedup system.

## Reviewer Workflow Implications

`7c67` should assume duplicate handling is a first-class workflow, not an implicit side effect.

We should support:
- a distinct ingestion status such as `needs_duplicate_review`
- persisted candidate duplicate records in the DB
- reviewer-visible evidence for each candidate
- reviewer actions:
  - merge into existing canonical ingestion
  - keep separate / reject candidate
  - optionally promote the current ingestion as canonical if it is materially better

Reviewer evidence should be explainable and specific:
- DOI match
- exact preprocess hash match
- title match / near-match
- author fingerprint overlap
- year difference
- fuzzy text similarity estimate

## Schema Implications For `664d`

`664d` should be written against this model.

### `source_ingestions`

Should include fields for at least:
- `raw_input_sha256`
- `preprocessed_text_sha256`
- `normalized_doi`
- `normalized_title`
- `title_fingerprint`
- `author_fingerprint`
- `publication_year`
- fuzzy-text signature storage (`minhash_signature` or equivalent)
- duplicate workflow status / disposition
- `duplicate_of_source_ingestion_id` or equivalent canonical-link field

### Duplicate candidate support

Add an explicit table such as `source_ingestion_duplicate_candidates` rather than trying to encode all candidate state on one row.

That table should capture:
- the subject ingestion
- the candidate matching ingestion
- candidate status (`pending`, `confirmed`, `rejected`, `auto_confirmed` or similar)
- the evidence payload / signal summary
- reviewer and timestamp fields as needed

This table is what makes the review-first duplicate workflow legible.

## Pipeline Implications For `a80e`

`a80e` should implement dedup as a real stage boundary with explicit outputs.

That matter should:
- compute exact and fuzzy signals after deterministic preprocess
- evaluate duplicate rules before the expensive LLM-clean / data-extract stages
- transition to duplicate-review state when needed
- write normalized metadata back later for future candidate quality
- never treat the preprocess hash as the only same-article test

One important implementation detail:
- it is acceptable to add a **cheap metadata-sniff path** before the expensive stages if deterministic extractor metadata is insufficient
- that sniff should extract fields like DOI/title/year, not ask an LLM to decide duplicate identity directly

## Final Recommendation

The production dedup design for source ingestion should be:
- submission-centric, not hash-centric
- multi-signal, not single-key
- deterministic and explainable, not LLM-judged
- review-first for anything short of exact DOI or exact corroborated normalized-text matches

In practical terms:
- DOI exact match is the strongest automatic path
- preprocess hash remains valuable, but only as exact normalized-text evidence
- metadata equality is a strong candidate signal
- MinHash on token shingles is the preferred fuzzy text signal for same-article/different-format cases
- explicit duplicate candidate records and duplicate-review state should carry the workflow

## Resulting Guidance To Downstream Matters

### For `664d`

Design the schema around explicit signals and duplicate links, not around `content_hashes` as the canonical model.

### For `a80e`

Implement an explainable `hash_and_dedup` stage that computes multiple deterministic signals, auto-resolves only the safest cases, and pauses into duplicate review for the rest.
