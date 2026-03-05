# Extraction Prompt Design Notes

## Context

These notes come from a manual extraction run against Uichanco 1918 ("A Biological and Systematic Study of Philippine Plant Galls") using the original Step 4 extraction prompt with Claude Opus 4.6. The input was ~950 lines of cleaned OCR text. The output was 34 gall-host association records.

This document captures: (1) a revised comprehensive prompt, (2) lessons learned during extraction, and (3) recommendations for handling large inputs in the pipeline.

---

## Revised Extraction Prompt

```
You are a gall biology data extractor. Given cleaned scholarly text about plant galls,
extract every gall-host association into a JSON array.

For each gall-host association found, produce one JSON object with these fields:

- "gall_species": {"name": "Genus species", "authority": "Author", "family": "Family",
  "order": "Order"}
- "host_species": {"name": "Genus species", "authority": "Author", "family": "Family"}
- "traits": an object with the following keys. Each trait (except detachable) has
  "original" (exact text from source, or null) and "suggested" (list of closest matches
  from the vocabulary below, or empty list):
    - "shape": cluster, conical, cup, cylindrical, globular, hemispherical, linear,
      numerous, rosette, spangle/button, sphere, spindle, tuft
    - "color": UV, black, brown, gray, green, orange, pink, purple, red, tan, white,
      yellow
    - "texture": areola, bumpy, erineum, glaucous, hairless, hairy, honeydew, leafy,
      mealy, mottled, pubescent, resinous dots, ribbed, ruptured/split, spiky/thorny,
      spotted, stiff, striped, succulent, woolly, wrinkly
    - "walls": false chamber, mycelium lining, ostiole, radiating-fibers, slit, spongy,
      thick, thin
    - "cells": free-rolling, monothalamous, not applicable, polythalamous
    - "alignment": drooping, erect, integral, leaning, supine
    - "plant_part": at leaf vein angles, between leaf veins, bud, flower, fruit,
      leaf edge, leaf midrib, lower leaf, on leaf veins, petiole, stem, underground
      (roots+), upper leaf
    - "form": abrupt swelling, bullet, hidden cell, leaf blister, leaf curl,
      leaf edge fold, leaf edge roll, leaf snap, leaf spot, modified capitulum,
      non-gall, oak apple, pip, plum, pocket, rust, scale, stem club, tapered swelling,
      witches broom
    - "season": Fall, Spring, Summer, Winter
    - "detachable": one of "unknown", "integral", "detachable", "both"
  - "description": full morphological description text from the source
  - "location": collection locality if mentioned, or null
  - "confidence": your confidence in the extraction accuracy, 0.0 to 1.0

### Output Rules

- Return ONLY a valid JSON array. No markdown fences, no commentary.
- One array element per gall-host association. If a gall has multiple hosts, create
  separate records.

### Trait Extraction Rules

- For traits, always include both "original" and "suggested". Use null for original
  if the trait is not mentioned. Use an empty list for suggested if no vocabulary
  match fits.
- "original" must be the EXACT text from the source, not your interpretation. Keep it
  short — just the relevant phrase, not the full sentence.
- "suggested" is your best mapping to the controlled vocabulary. Multiple values are
  allowed when the source describes multiple states (e.g., "red; basally yellowish"
  maps to ["red", "yellow"]).
- Do NOT force a mapping. If the source describes something with no close vocabulary
  match, leave suggested empty and let the original speak for itself.

### Taxonomy Rules

- If taxonomy fields (authority, family, order) are not stated, use null.
- Preserve authority strings exactly as written in the source, including abbreviations
  and parenthetical basionym authors (e.g., "(L.) Muell.-Arg.").
- When a gall-maker was not identified (e.g., "adult not collected", "causal agent
  unknown"), set gall_species.name to null. Still populate family/order if the text
  places it in a known group (e.g., described under a "Galls caused by Itonidae"
  section heading implies family Cecidomyiidae, order Diptera).
- When the source uses "sp. nov. (MS)" or similar manuscript name indicators, include
  the full designation in the authority field.
- Watch for OCR artifacts in taxonomic names. Common issues include: letter
  substitutions (e.g., "x" for "æ", "ii" for "ü"), garbled diacritics, and
  run-together words. Correct obvious OCR errors in names but note uncertainty by
  lowering confidence.

### Plant Part Mapping

- Historical botanical terminology must be translated:
  - "nether surface" = lower leaf
  - "upper surface" = upper leaf
  - "leaf lamina" = the leaf blade generally; map to upper/lower leaf based on context
  - "midrib" / "costa" = leaf midrib
  - "nervules" / "lateral nervules" = leaf veins
  - "petiole" = petiole
- When a gall spans both surfaces (e.g., "part on upper surface with corresponding
  lobe on nether surface"), include BOTH plant_part values.

### Form and Detachability Inference

- Infer "detachable" from morphological description:
  - "integral" — when the gall is a modification of existing tissue (leaf fold, leaf
    roll, leaf curl, stem swelling, midrib enlargement) that cannot be separated from
    the plant without destruction.
  - "detachable" — when the gall is a discrete structure attached by a peduncle, has
    a lid that falls off, or is described as sessile but separable.
  - "unknown" — when the description does not provide enough information to determine.
- For "form", map leaf margin involutions/rolls to "leaf edge roll", leaf margin folds
  to "leaf edge fold", shallow depressions with corresponding convexity to
  "leaf blister", and midrib/stem enlargements to "abrupt swelling" or
  "tapered swelling" depending on description.

### Season Mapping

- Map collection months to Northern Hemisphere seasons:
  - Spring: March, April, May
  - Summer: June, July, August
  - Fall: September, October, November
  - Winter: December, January, February
- When a source gives a range spanning multiple seasons (e.g., "August to December"),
  include ALL applicable seasons.
- If the source says "present throughout the year" or similar, include all four seasons.
- IMPORTANT: For tropical locations (Philippines, Indonesia, equatorial regions, etc.),
  these season mappings are approximate — the tropics don't have temperate seasons.
  Still use the Northern Hemisphere mapping for consistency, but mention this caveat
  in the top-level "notes" field.

### Description Field

- Include ONLY morphological description text: shape, size, color, surface texture,
  wall structure, chamber details, opening mechanism, and dimensions.
- EXCLUDE narrative text about breeding methods, collection circumstances, rarity
  observations, historical notes, and taxonomic discussion.
- Synthesize from multiple paragraphs if the morphological description is spread
  across the entry, but do not add interpretation.

### Multiple Galls on Same Host

- When a source describes multiple distinct gall types on the same host species
  (e.g., "Leaf galls No. 1" and "Leaf galls No. 2"), create separate records for each.
- When a gall-maker produces galls on multiple hosts, create separate records for each
  host.

### Confidence Calibration

Assign confidence based on these criteria:
- 0.85-1.0: Named gall species, named host, detailed morphological description,
  clear trait data.
- 0.70-0.84: One of: gall-maker not definitively identified ("probably caused by"),
  or host identified only to genus/variety, or sparse morphological description.
- 0.50-0.69: Two or more of the above issues, OR the description is too damaged/brief
  for reliable trait extraction, OR the association is inferred rather than stated.
- Below 0.50: Do not include — the data is too uncertain to be useful.

### Source Metadata

If the input file contains YAML frontmatter with source_id, title, authors, and year,
include a top-level wrapper object:

{
  "source": {
    "source_id": <id>,
    "title": "<title>",
    "authors": ["<author>"],
    "year": <year>
  },
  "notes": "<any global notes, e.g., tropical season caveat>",
  "associations": [ ...the array of gall-host records... ]
}

If no frontmatter is present, return just the array.
```

---

## Lessons Learned from Manual Extraction

### Judgment Calls the Original Prompt Didn't Cover

1. **OCR artifacts in names**: "Bafios" for "Baños", "Pteridium" for "Paederia", garbled diacritics throughout. The model needs explicit instruction to watch for and correct these.

2. **Historical botanical terminology**: "nether surface" (lower leaf), "nervules" (veins), "suffrutescent", "stramineous", "castaneous". The model handled these but only because of general knowledge — the prompt should make the common mappings explicit.

3. **Detachability inference**: The original prompt listed the vocabulary but gave no guidance on how to infer detachability from descriptions. Leaf folds are obviously integral; discrete spherical galls on peduncles might be detachable; most cases are ambiguous. Rules are needed.

4. **Section headings as taxonomy context**: When a gall appears under "GALLS CAUSED BY ITONIDAE" but the causal species is unknown, the heading provides family/order information. The prompt needs to say: use section context to populate higher taxonomy even when species is null.

5. **Description scoping**: Entries mixed morphological description with breeding notes, rarity observations, and literature references. The model needs to know what to include and exclude in the description field.

6. **Tropical season mapping**: Mapping months to Northern Hemisphere seasons for Philippine material is inherently approximate. The prompt should acknowledge this and instruct the model to flag it.

7. **Multiple gall types per host**: Ficus ulmifolia had three different gall types from different insect groups. The prompt should explicitly address this pattern.

8. **"Probably caused by" language**: Some associations were tentative. The original prompt's "be conservative with confidence" was too vague — explicit calibration bands are better.

9. **Illustrations sections**: The paper had extensive plate descriptions that partially repeated information from the main text but with slight name variations (e.g., "Diceromyia vernonix" vs "Diceromyia vernoniae"). The model needs guidance on whether to treat plate captions as additional data or ignore them.

10. **Color from context**: "Concolorous with leaf" requires the model to infer green. "Stramineous" means straw-colored (yellow/tan). "Castaneous" means chestnut brown. Domain vocabulary needs either a glossary or an instruction to translate.

### What the Original Prompt Got Right

- The trait vocabulary was comprehensive and well-matched to the source material.
- The dual original/suggested structure captured nuance well.
- Requiring one record per gall-host pair was the correct granularity.
- The JSON schema was clean and unambiguous.

---

## Handling Large Inputs

### The Problem

The test file was ~950 lines. It was read in four 300-line chunks, then the entire extraction was done from memory in a single output. This approach is fragile:

- Detail from early chunks degrades by the time output is written.
- Longer papers (some gall monographs are 200+ pages) will exceed any context window.
- No way to verify completeness — did the model silently skip entries it forgot?

### Recommended Approach: Section-Based Splitting

Taxonomic literature naturally divides by section headers. This paper had:
- "GALLS CAUSED BY ITONIDAE (CECIDOMYIIDAE)" — 19 entries
- "GALLS CAUSED BY PSYLLIDAE" — 7 entries
- "GALLS CAUSED BY THYSANOPTERA" — 7 entries
- "GALLS CAUSED BY GELECHIDAE" — 1 entry

**Proposed pipeline step**: Before extraction, split the cleaned text on major section headers. Feed each section to the extraction prompt independently. Merge the resulting JSON arrays.

Benefits:
- Each LLM call processes a manageable chunk with full attention.
- Section headers provide taxonomy context (family/order) naturally.
- Parallelizable — sections can be processed concurrently.
- Failures are isolated to one section, not the whole paper.

Implementation notes:
- The splitting heuristic needs to handle varied header formats: markdown headers, all-caps lines, bold text, centered text.
- Each section chunk should include the YAML frontmatter (for source metadata) and any preamble that establishes context (e.g., the plant family list).
- The merge step should deduplicate by (gall_species.name, host_species.name) pair in case plate/illustration sections re-describe entries.

### Alternative: Chunked Extraction with Continuation

If section-based splitting isn't feasible (some papers don't have clean sections):
- Instruct the model to process entries sequentially and emit a `continuation_marker` (last host species processed, or line number) when it reaches its comfortable limit.
- Subsequent calls include the marker and pick up where the previous call left off.
- Merge step deduplicates and validates continuity.

This is more complex and error-prone than section splitting but works for unstructured texts.

### Not Recommended: Single-Pass on Full Text

What was actually done. Works for papers under ~1000 lines but doesn't scale. Extraction quality is unverifiable for early entries, and the approach will silently fail on longer works.
