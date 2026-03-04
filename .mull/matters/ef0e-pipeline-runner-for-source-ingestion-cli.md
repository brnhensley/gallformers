---
status: raw
tags: [design]
created: 2026-03-04
updated: 2026-03-04
epic: ingestion
---

# Pipeline runner for source ingestion CLI

## Design: Composable Pipeline Runner

**Context:** The source ingestion CLI (services/source-ingestion/) currently has a monolithic `cli.py` that hardcodes the pipeline stages. This redesign makes stages composable and declarative.

**Future direction:** This will likely move to Elixir/BEAM orchestration in production (GenStage/Broadway for pipeline stages, supervision trees for LLM failure handling). The Python PoC validates the stage design and prompts. Keep stages dumb (file in → file out) to make the eventual port straightforward.

### Architecture: Hybrid

Two layers:
1. **Subcommands** — each stage is an independent `ingest <stage>` command: `-i input_file -o output_file`
2. **Pipeline runner** — `ingest run -p pipeline.yaml` chains subcommands via YAML config

### Available stages

| Command | Input | Output | Requires model? |
|---------|-------|--------|-----------------|
| `ingest extract` | PDF/URL/text file | raw markdown | No |
| `ingest ocr` | PDF file | raw markdown | Yes (vision model) |
| `ingest preprocess` | text file | cleaned text | No |
| `ingest llm-clean` | text file | cleaned text | Yes |
| `ingest metadata` | text file | JSON file | Yes |
| `ingest assemble` | cleaned text + metadata JSON | final markdown | No |

### Pipeline config (YAML)

```yaml
pipeline:
  name: bhl-ocr-cleanup
  stages:
    - step: ocr
      model: lmstudio/olmocr-2-7b
    - step: preprocess
    - step: llm-clean
      model: lmstudio/qwen3-vl-8b
    - step: metadata
      model: lmstudio/qwen3-vl-8b
    - step: assemble
```

### Forking

```yaml
pipeline:
  name: compare-llms
  stages:
    - step: ocr
      model: lmstudio/olmocr-2-7b
    - step: preprocess
    - fork:
        qwen:
          - step: llm-clean
            model: lmstudio/qwen3-vl-8b
        deepseek:
          - step: llm-clean
            model: deepseek/deepseek-chat
```

### Output naming

Flat in `output/{source_id}/`, prefixed by pipeline name:
```
output/9995/
  compare-llms-1-ocr.md
  compare-llms-2-preprocess.md
  compare-llms-qwen-3-llm-clean.md
  compare-llms-deepseek-3-llm-clean.md
```

### Resumability

If an output file exists, skip that stage. Re-run picks up where it left off.

### Implementation scope

- **Rewrite:** `cli.py` → click group with subcommands
- **Add:** `pipeline.py` — YAML config loader + runner (~100 LOC)
- **Keep unchanged:** `extract.py`, `ocr.py`, `preprocess.py`, `llm.py`, `prompts.py`, `output.py`, `providers.py`

### Research notes

Evaluated pypyr, Ploomber, Hamilton, Gloe, Haystack, LangChain, InstructLab SDG. All either overkill (LangChain/Haystack), wrong model (doit), or don't provide enough over a custom ~100 LOC runner to justify the dependency. Custom runner with existing PyYAML/Click deps is the pragmatic choice.

