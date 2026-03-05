---
status: planned
tags: [design]
created: 2026-03-04
updated: 2026-03-04
epic: ingestion
relates: [ef0e]
---

# Structured data extraction pipeline step

## Design: Structured Data Extraction Pipeline Step

New pipeline step `data-extract` that uses an LLM to extract structured gall records from cleaned scholarly document text, producing JSON suitable for review and import into gallformers via an admin tool.

### Goal

Review-first import: LLM extracts structured data into a review format. A human reviews/corrects in an admin tool before import. Critical for a taxonomy database where accuracy matters.

### Output format

JSON array, one record per gall-host association found in the document:

```json
[
  {
    "gall_species": {
      "name": "Schizomyia acalyphae",
      "authority": "Felt",
      "family": "Cecidomyiidae",
      "order": "Diptera"
    },
    "host_species": {
      "name": "Acalypha stipulacea",
      "authority": "Klotz.",
      "family": "Euphorbiaceae"
    },
    "traits": {
      "plant_part": { "original": "nether surface of leaf, along principal veins", "suggested": ["lower leaf", "on leaf veins"] },
      "shape": { "original": "subcylindrical", "suggested": ["cylindrical"] },
      "color": { "original": "red; basally yellowish", "suggested": ["red", "yellow"] },
      "texture": { "original": "covered with long, stiff, bristle-like hairs", "suggested": ["hairy", "stiff"] },
      "walls": { "original": "thin, fleshy", "suggested": ["thin"] },
      "cells": { "original": "monothalamous", "suggested": ["monothalamous"] },
      "alignment": { "original": null, "suggested": [] },
      "form": { "original": null, "suggested": [] },
      "detachable": "unknown",
      "season": { "original": "March", "suggested": ["Spring"] }
    },
    "description": "Monothalamous; subcylindrical; red; basally yellowish...",
    "location": "Luzon, Laguna, Los Baños; altitude ~45m",
    "confidence": 0.85
  }
]
```

### Trait mapping approach

Each trait has `original` (free text from source) and `suggested` (mapped to gallformers vocabulary). The LLM prompt includes all valid gallformers lookup values so it can suggest mappings. Reviewer sees both and can accept or override.

### Valid gallformers vocabulary (included in prompt)

- **shape:** cluster, conical, cup, cylindrical, globular, hemispherical, linear, numerous, rosette, spangle/button, sphere, spindle, tuft
- **color:** UV, black, brown, gray, green, orange, pink, purple, red, tan, white, yellow
- **texture:** areola, bumpy, erineum, glaucous, hairless, hairy, honeydew, leafy, mealy, mottled, pubescent, resinous dots, ribbed, ruptured/split, spiky/thorny, spotted, stiff, striped, succulent, woolly, wrinkly
- **walls:** false chamber, mycelium lining, ostiole, radiating-fibers, slit, spongy, thick, thin
- **cells:** free-rolling, monothalamous, not applicable, polythalamous
- **alignment:** drooping, erect, integral, leaning, supine
- **plant_part:** at leaf vein angles, between leaf veins, bud, flower, fruit, leaf edge, leaf midrib, lower leaf, on leaf veins, petiole, stem, underground (roots+), upper leaf
- **form:** abrupt swelling, bullet, hidden cell, leaf blister, leaf curl, leaf edge fold, leaf edge roll, leaf snap, leaf spot, modified capitulum, non-gall, oak apple, pip, plum, pocket, rust, scale, stem club, tapered swelling, witches broom
- **season:** Fall, Spring, Summer, Winter
- **detachable:** unknown, integral, detachable, both

### Pipeline integration

New step type: `data-extract`. Input: cleaned text file (output of llm-clean). Output: `.json` file. Requires model. Uses chunking for large documents with JSON array merging.

Example pipeline config:
```yaml
pipeline:
  name: bhl-full
  stages:
    - step: preprocess
    - step: llm-clean
      model: deepseek/deepseek-chat
    - step: data-extract
      model: deepseek/deepseek-chat
    - step: metadata
      model: deepseek/deepseek-chat
    - step: assemble
```

### Implementation

- New prompt in `prompts.py`: `DATA_EXTRACT_SYSTEM_PROMPT`
- New function in `llm.py`: `extract_data(text, provider) -> DataExtractResult`
- New step handler in `pipeline.py` and `VALID_STEPS`
- New subcommand: `ingest data-extract -i cleaned.md -o data.json --model ...`
- New dataclass: `DataExtractResult` with records list and token usage
- Tests for prompt structure, JSON output parsing, chunking + array merge, CLI subcommand, pipeline integration
