# Source Ingestion Pipeline

A composable text processing pipeline for extracting, cleaning, and structuring source documents for gallformers. Documents go through a series of stages — OCR, preprocessing, LLM cleanup, metadata extraction — and come out as structured markdown with YAML frontmatter.

## Setup

Requires Python 3.12+ and [uv](https://docs.astral.sh/uv/).

```bash
cd services/source-ingestion
uv sync
```

Copy and customize the provider config:

```bash
cp providers.example.yaml providers.yaml
```

Set API keys for your providers as environment variables (see `providers.yaml` for which env var each provider expects). For local LM Studio models, any value works:

```bash
export LMSTUDIO_API_KEY=not-needed
```

## Quick Start

### Run a pipeline

```bash
uv run ingest run \
  -p pipelines/bhl-qwen-clean.yaml \
  --source-id 9995 \
  -i output/OLM-Step1.raw.extraction.md
```

### Run individual stages

Each stage is a standalone subcommand with `-i` (input file) and `-o` (output file):

```bash
# Extract text from a PDF
uv run ingest extract -i document.pdf -o raw.md

# Preprocess (deterministic cleanup)
uv run ingest preprocess -i raw.md -o preprocessed.md

# LLM cleanup
uv run ingest llm-clean -i preprocessed.md -o cleaned.md \
  --model lmstudio/qwen3-vl-8b

# Extract metadata
uv run ingest metadata -i preprocessed.md -o metadata.json \
  --model lmstudio/qwen3-vl-8b

# Assemble final document
uv run ingest assemble -i cleaned.md --metadata metadata.json \
  -o 9995.md --source-id 9995
```

## Subcommands

| Command | Input | Output | Model? | Description |
|---------|-------|--------|--------|-------------|
| `extract` | PDF, URL, or text file | markdown | No | Text extraction via pymupdf4llm (PDF), trafilatura (URL), or file read |
| `ocr` | PDF file | markdown | Yes | Vision-model OCR, page by page (e.g., olmocr) |
| `preprocess` | text file | text file | No | Deterministic cleanup: BHL boilerplate, line rejoining, plate removal |
| `llm-clean` | text file | text file | Yes | LLM-based OCR artifact repair and markdown formatting |
| `metadata` | text file | JSON file | Yes | LLM-based extraction of title, authors, year, DOI |
| `assemble` | text + JSON | markdown | No | Combines cleaned text with YAML frontmatter |
| `run` | any | varies | Varies | Executes a multi-stage pipeline from a YAML config |

### Common options

- `-i` / `--input` — input file path (or URL for `extract`)
- `-o` / `--output` — output file path
- `--model` — provider/model spec in `provider/model` format (e.g., `lmstudio/qwen3-vl-8b`)
- `--config` — path to provider config YAML (defaults to `providers.example.yaml`)

## Pipeline Config Format

Pipelines are YAML files that declare a sequence of stages:

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

### Fields

- **`pipeline.name`** (required) — Name used as prefix for output files.
- **`pipeline.stages`** (required) — Ordered list of stages to execute.

### Stage types

Each stage is a `step:` entry. Stages that call an LLM also need a `model:` field.

| Step | Requires `model`? | Notes |
|------|-------------------|-------|
| `extract` | No | Uses pymupdf4llm for PDFs, trafilatura for URLs |
| `ocr` | Yes | Vision model OCR (e.g., `lmstudio/olmocr-2-7b`) |
| `preprocess` | No | Deterministic text cleanup heuristics |
| `llm-clean` | Yes | LLM text cleanup with chunking for large documents |
| `metadata` | Yes | Extracts title, authors, year, DOI as JSON |
| `assemble` | No | Must follow a `metadata` step |

### Forking

Send one stage's output to multiple parallel branches using `fork:`:

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
          - step: metadata
            model: lmstudio/qwen3-vl-8b
          - step: assemble
        deepseek:
          - step: llm-clean
            model: deepseek/deepseek-chat
          - step: metadata
            model: deepseek/deepseek-chat
          - step: assemble
```

Each branch receives the output of the last pre-fork stage as its input and runs independently.

### Running a pipeline

```bash
uv run ingest run \
  -p pipelines/my-pipeline.yaml \
  --source-id 9995 \
  -i input-document.pdf \
  -o ./output                    # optional, defaults to ./output
```

## Output Structure

The pipeline runner places all files flat in `output/{source_id}/`, prefixed by the pipeline name:

```
output/9995/
  bhl-ocr-cleanup-1-ocr.md
  bhl-ocr-cleanup-2-preprocess.md
  bhl-ocr-cleanup-3-llm-clean.md
  bhl-ocr-cleanup-4-metadata.json
  bhl-ocr-cleanup-9995.md          # final assembled document
```

With forking, branch names appear in the prefix:

```
output/9995/
  compare-llms-1-ocr.md
  compare-llms-2-preprocess.md
  compare-llms-qwen-3-llm-clean.md
  compare-llms-qwen-4-metadata.json
  compare-llms-qwen-9995.md
  compare-llms-deepseek-3-llm-clean.md
  compare-llms-deepseek-4-metadata.json
  compare-llms-deepseek-9995.md
```

### Resumability

If an output file already exists, that stage is skipped. To re-run a stage, delete its output file.

## Provider Configuration

Providers are configured in a YAML file (`providers.example.yaml`):

```yaml
providers:
  lmstudio:
    base_url: "http://localhost:1234/v1"
    env_key: "LMSTUDIO_API_KEY"
    no_system_role: true
    models:
      - qwen3-14B
      - qwen3-vl-8b
      - olmocr-2-7b
  deepseek:
    base_url: "https://api.deepseek.com/v1"
    env_key: "DEEPSEEK_API_KEY"
    models:
      - deepseek-chat
```

- **`base_url`** — OpenAI-compatible API endpoint
- **`env_key`** — Environment variable name for the API key
- **`no_system_role`** — Set `true` for models that don't support the system role (folds system prompt into user message)
- **`models`** — List of available model names

Reference models as `provider/model` (e.g., `deepseek/deepseek-chat`, `lmstudio/qwen3-vl-8b`).

## Preprocessing Heuristics

The `preprocess` step applies deterministic cleanup tailored for BHL (Biodiversity Heritage Library) OCR documents:

1. **BHL boilerplate removal** — strips cover page metadata
2. **Plate page removal** — drops OCR junk from scanned photograph pages
3. **Page header stripping** — removes running headers, journal names, page numbers
4. **Hyphenation rejoining** — fixes words split across line breaks
5. **Line rejoining** — merges OCR-broken lines back into paragraphs

## Development

```bash
uv sync
uv run pytest tests/ -v
```
