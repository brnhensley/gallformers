---
status: raw
created: 2026-03-02
updated: 2026-03-03
epic: 1-foundation
relates: []
---

# LLM-assisted source ingestion

## The Need

The majority of gall literature hasn't been entered into Gallformers and realistically never will be through manual data entry. During COVID, Adam entered ~90% of the literature currently in the system. With the recent worldwide expansion, the backlog of relevant literature is large and growing. A tool that reduces the friction of getting published data into the system would make that backlog tractable.

## Current state

The system has 851 sources with 7,845 species-source description entries. Average description is ~620 characters; the longest is ~32K characters. Only 45 descriptions exceed 5K characters — the vast majority are short. Editors use a mix of paste-and-reformat (from papers, BHL OCR) and compose-from-scratch workflows, varying by user and entry length. Source descriptions are rendered as markdown (Earmark/GFM) with automatic glossary term linking.

## Context

- Source descriptions follow an informal but consistent pattern: name used by source, synonyms, gall description, hosts, range, phenology, comments. Not all sections appear in every entry — incomplete sources are the norm.
- Editorial conventions exist: `[square brackets]` for editor commentary, `[modern names]` for updated host taxonomy, `[]()` for linking other GF entries. Multiple entries per gall from the same source (pre-synonymization) are kept as separate blocks.
- A significant amount of source material comes from BHL, which has messy OCR that's human-painful but LLM-parseable.
- There is no formalized markdown template yet.
- A related phenology data layer proposal (PR #521) would benefit from structured phenology extraction from literature.
- Sources already track license (`All Rights Reserved`, `Public Domain / CC0`, `CC-BY`) and license link. This enables decisions about public display of full text.

## Long-term vision

An incremental pipeline where each layer builds on the previous:

1. **Document ingestion** — Extract text from a source document (PDF, BHL OCR, URL), clean it up with an LLM (correct OCR errors, fix formatting), structure it as clean markdown with YAML frontmatter (authors, title, DOI, license, etc.), and persist to S3 linked to the source record. This creates a durable, machine-readable artifact of the full source text. Anyone with proper authorization can contribute documents — the pipeline runs independently of the main application. A standalone PoC validates this layer (see PoC 1 below).
2. **Structured extraction** — Parse the layer 1 markdown artifact and extract per-species data into a structured format: species entries with host associations, trait values, range, phenology, synonyms, taxonomic notes. The output is a structured artifact (format TBD — likely JSON or YAML) written to S3 as a sibling of the layer 1 markdown. This layer differs from layer 1 in that it interprets the text rather than just cleaning it. A separate PoC validates this layer (see PoC 2 below).
3. **Admin review UI** — Update the admin interface to read in the layer 2 structured artifact and present the admin with a changeset: proposed species-source descriptions, host associations, trait values, new species entries. The admin can approve, edit, or reject each proposed change before it touches the database. This is where "nothing touches the DB without human approval" lives.
4. **Proactive discovery** — Search vetted repositories (BHL) for relevant papers, feed into layers 1-3.

Each layer is independently useful. Nothing touches the database without human approval.

The key architectural insight: layer 1 produces a **full-text markdown artifact** that becomes the source of truth for all downstream processing. Layer 2 produces a **structured data artifact** that the application consumes. Both artifacts live on S3, are durable, and can be reprocessed as extraction logic improves.

### Integration with the application

Layer 1 adds a `markdown_s3_key` column to the `source` table. When present, admin pages can display the full markdown text. For sources with permissive licenses (`Public Domain / CC0`, `CC-BY`), the public source page could also render the full text — making Gallformers a more complete reference.

Layer 2 adds a sibling structured artifact on S3. Layer 3 reads this artifact and presents it as reviewable changesets in the admin UI.

## Security and cost

Layers 1 and 2 run outside the application and write only to S3. There is no conversational LLM endpoint exposed to users. The attack surface is limited to the pipeline operator's local environment. No database access or tooling is given to the model — worst case is wasted tokens, not data corruption.

Layer 3 (admin review UI) is the only layer that touches the database, and only through explicit admin approval of proposed changesets.

**Output sanitization.** Source descriptions are currently rendered with `Phoenix.HTML.raw()` and no HTML sanitization. This is a pre-existing vulnerability — any editor can inject HTML today. LLM-generated content doesn't change the risk profile, but as we add more automated text processing, sanitizing markdown output on render becomes more important. This is a known issue to address separately, not a blocker for this work.

**Cost model.** US frontier models (Claude, GPT) are too expensive for bulk document processing — Sonnet at ~$0.22/paper makes a 500-paper backlog cost ~$110. Chinese and budget models (DeepSeek V3, Kimi K2, Gemini Flash, Mistral, MiniMax) are 10-50x cheaper, putting the same backlog at $5-10 total. The PoC is model-agnostic and will test quality across several cheap options. For the PoC: operator's own API key, no rate limiting needed. For production use: API key funded by GF Patreon, managed through Fly.io secrets.

## Proposed first steps

Before writing any feature code, validate the premise with two PoCs:

1. **Build PoC 1** (see below). Produce working document ingestion for a handful of real sources. Test across source types (clean PDFs, BHL OCR, short papers, long monographs). Measure cost and latency across budget models.
2. **Build PoC 2** (see below). Take PoC 1 output and extract per-species structured data. Design the structured output format. Evaluate extraction accuracy — can it correctly identify species, hosts, traits, range, phenology from the clean markdown?
3. **Design the source description template.** Take a sample of existing source entries and produce a few different markdown formatting proposals — different heading styles, section ordering, how to handle incomplete entries. This template guides both the PoC 2 extraction and the eventual layer 3 admin UI.
4. **Pitch to community.** Present before/after examples to the GF community and get feedback on template style, output quality, and whether this is useful enough to build into the site.

This produces concrete evidence — example outputs, cost numbers, community reaction — before committing to building anything into the site.

## Source description template

The template standardizes sections that already appear informally in most entries. Sections are included only when present in the source — incomplete entries are the norm. When a single source has multiple entries for the same gall (pre-synonymization), they appear as separate blocks, not interleaved.

This template guides layer 2 (structured extraction) and defines the format for per-species entries in the layer 3 admin review UI.

### Format

Uses `###` markdown headings for section labels. Species name as `##` heading with taxonomic status (sp. nov., syn. nov., etc.) when applicable. Latin names italicized.

### Sections (in order, all optional)

1. **Name** (`##` heading) — Species name as used by the source, with taxonomic status. E.g., `## *Pseudoneuroterus saltabundus* Sottile & Cerasa sp. nov.`
2. **Synonyms** — The author's synonym list, as given.
3. **Gall** — Gall morphology, measurements, appearance. Verbatim from source — no wasp/adult insect anatomy.
4. **Host** — Host plant listing. Modern name corrections in `[brackets]` when the source uses an outdated name.
5. **Range** — Geographic distribution.
6. **Phenology** — Timing, emergence, seasonality.
7. **Comments** — Ecology, taxonomic notes, similar galls. Editorial commentary in `[square brackets]`.

### Key principles

- **Direct quotation.** Text outside `[square brackets]` is verbatim from the source. The LLM selects and structures relevant passages but does not paraphrase, summarize, or rephrase. This is attributed to the source author, not the editor.
- **`[Square brackets]` are editor-only.** Only the human editor adds bracketed commentary — corrections to outdated host names, cross-references to other GF entries, taxonomic context the source doesn't provide. The LLM should not generate editorial commentary; it lacks the domain context to do so meaningfully.
- **No insect morphology.** Adult wasp anatomy (antenna segments, mesoscutum sculpture, etc.) is stripped. Only gall descriptions are included. When gall and insect anatomy are interleaved in the same paragraph, include the full paragraph rather than attempting surgical extraction — the editor can trim later. The goal is to not lose gall data, not to perfectly separate domains.
- **Sparse entries are fine.** A species mentioned only in a table might have just Host, Range, and Phenology. The template compresses naturally.
- **Table extraction.** When a source includes a summary table of species with host/range/phenology data, the LLM extracts each species into its own entry. This is one of the highest-value uses of the tool.

### Worked example

Source: Sottile S., Nicholls J.A., Tang C-T., Stone G.N. & Cerasa G. 2026. Description of *Pseudoneuroterus saltabundus* new species (Hymenoptera: Cynipidae: Cynipini) with jumping galls from Italy and revised keys to Western Palaearctic Cynipini genera lacking transscutal articulation. European Journal of Taxonomy 1039: 219–250. https://doi.org/10.5852/ejt.2026.1039.3193

This paper describes one new species and provides a table summarizing biology, distribution, host plants, and emergence times for all five *Pseudoneuroterus* species. The LLM extracts entries for each.

---

#### Full entry (new species, rich data)

## *Pseudoneuroterus saltabundus* Sottile & Cerasa sp. nov.

### Gall
The gall typically develops on the lower surface of *Q. cerris* leaves along the secondary veins, although in rare cases it has been observed on the upper surface as well; in the presence of 4–6 closely spaced galls, complete deformation and bending of the leaf lamina may occur. At the point of insertion, an invagination of the leaf blade is observed, while no conspicuous structures are present at the corresponding point on the upper surface, but rather a translucent 'spot'. At the insertion point, a thin membranous lamina expands in a fan-like manner and envelops the gall like a small shell; it is covered with star-shaped hairs similar to those on the leaf. This laminar structure is present only on one side of the gall and may perform a protective function in the early stages of gall development. In the mature gall, the lamina remains vestigial, reaching up to ¼, rarely ⅓ of its height. In rare cases, the lamina develops into a ribbon-like structure that encircles the gall. The lamina remains attached to the leaf after the main gall detaches, providing a remnant of the gall's presence.

The main gall has a sub-globular ellipsoid shape, with a glabrous surface, traversed by very slight reliefs resembling venations (venulations). The thin (< 0.1 mm), leathery walls enclose a large larval chamber, excavated by the larva during the trophic phase. Typical dimensions are: longest side: 1.6–1.8 mm, shortest side: 1.3–1.5 mm, height: 1.4–1.6 mm. On the underside of the gall, the shape protrudes towards the point of insertion on the leaf blade; however, it is sessile with no peduncle present. The colour is whitish to pale green during development, and becomes light brown upon maturation.

### Host
*Quercus cerris* (Quercus section Cerris), the only known host species to date.

### Range
Northern Italy (Lombardy and Emilia-Romagna), peninsular Italy (Tuscany, Umbria, and Lazio) and Hungary.

### Phenology
Galls develop rapidly in late spring, between the end of May and mid-June, and generally complete development within approximately 7 to 10 days. Mature galls abscise from the leaf and remain in the moist litter during the following months. Agamic females emerge during the second half of January and early February of the following year.

### Comments
Only the asexual generation is known.

Rapid development and immediate abscission from the host leaf are likely advantageous traits favouring escape from parasitoid attack. Gall abscission is a process enhanced by the fully fed, mature larva, which is capable of performing rapid body extensions that facilitate detachment. The larva is positioned in a U-shaped posture within the gall chamber and, when externally stimulated, it abruptly extends its body, producing a rapid snapping motion. These contractions strike the internal walls of the gall, generating a distinct and audible "tick" sound perceptible to the human ear. The kinetic energy generated by these repeated strikes not only facilitates gall abscission, but also enables the remarkable jumping ability of the fallen galls, often exceeding distances of over 60 mm. The galls retain this jumping ability until September.

**Similar galls.** The asexual generation galls of *P. saltabundus* sp. nov. are similar in shape and size to the asexual generation galls of *Neuroterus anthracinus*, but while the galls of the latter exhibit two symmetrical lamellar valves at the base and possess a smooth and glossy surface with coloured maculae, the galls of the new species present only a single lateral lamella, and the surface is traversed by very slight elevations resembling venation and is matte. Moreover, the agamic generation of *N. anthracinus* develops in the late summer–autumn on section Quercus oaks, whereas those of *P. saltabundus* develop in late spring (late May–mid-June) on section Cerris oaks.

Asexual galls of *P. saltabundus* sp. nov. could be confused with those of its congener *P. saliens*. Galls of that species have a fusiform shape with a longer attachment base, larger dimensions, a smooth, almost shiny surface or with very fine parallel dorso-ventral striations, and develop along young stems or the leaf midrib. In contrast, *P. saltabundus* galls are rounder not fusiform, have a matte surface with characteristic venulation and typically develop on secondary veins. Additionally, *P. saliens* galls develop in autumn rather than spring. Both galls exhibit the ability to jump, although this behaviour is less pronounced in *P. saliens*.

---

#### Table-derived entry (sparse, from Table 1)

## *Pseudoneuroterus mazandarani* Melika & Stone, 2010

### Host
*Q. castaneifolia*

### Range
Iran, Mazandaran Province.

### Phenology
June (asexual generation).

---

## Proof of concept

Two standalone PoCs, one per pipeline stage. Both run locally, use the operator's own API keys, and have no connection to the gallformers application.

### PoC 1: Document ingestion (layer 1)

Given a source document (PDF, URL, or text file), PoC 1:

1. **Extracts text** from the input document
2. **Sends extracted text to an LLM** with a system prompt specifying the output format
3. **Produces a structured markdown file** with YAML frontmatter and clean body text
4. **Optionally uploads** to S3 with a key derived from the source ID

### Output format

```markdown
---
source_id: 1234
title: "Description of Pseudoneuroterus saltabundus..."
authors: ["Sottile S.", "Nicholls J.A.", "Tang C-T.", "Stone G.N.", "Cerasa G."]
year: 2026
doi: "10.5852/ejt.2026.1039.3193"
license: "CC-BY"
original_url: "https://doi.org/10.5852/ejt.2026.1039.3193"
extracted_at: "2026-03-03T12:00:00Z"
model: "deepseek-v3"
---

[Clean, structured full text of the source document]
```

The body text is the full document content, cleaned of OCR artifacts, with consistent formatting. This is not per-species extraction — that's PoC 2. PoC 1 produces one markdown file per source document representing the complete text.

### Tech stack

**Python** — fastest path to a working PoC given the ecosystem:

- **Text extraction**: `pymupdf4llm` (PDF → markdown-friendly text), `trafilatura` (URL → text), or plain file read for pre-extracted text
- **LLM**: Model-agnostic via OpenAI-compatible API (most providers support this interface). A `--model` flag and provider config selects the model at runtime. No SDK lock-in to any single provider.
- **S3**: `boto3` (optional upload step)
- **CLI**: `click` or `argparse`

### Model candidates

The PoC targets cheap, high-volume models. US frontier models are too expensive for bulk processing. Candidates to test:

**US frontier models (for reference — too expensive for bulk use):**

| Model | Input/1M | Output/1M | Est. cost per paper | 500 papers |
|-------|----------|-----------|--------------------:|------------|
| Claude Sonnet 4.6 | $3.00 | $15.00 | ~$0.22 | ~$112 |
| GPT-4o | $2.50 | $10.00 | ~$0.16 | ~$78 |
| Claude Opus 4.6 | $15.00 | $75.00 | ~$1.12 | ~$562 |

**Budget models (PoC candidates):**

| Model | Input/1M | Output/1M | Est. cost per paper | 500 papers | Why test it |
|-------|----------|-----------|--------------------:|------------|-------------|
| DeepSeek V3.2 | $0.28 | $0.42 | ~$0.01 | ~$5 | Strong general quality at low cost |
| Gemini 2.5 Flash | $0.30 | $2.50 | ~$0.03 | ~$17 | Google's fast model, good at structured output |
| Kimi K2 0905 | $0.39 | $1.90 | ~$0.03 | ~$14 | 75% discount with context caching, long context |
| Mistral Medium 3 | $0.40 | $2.00 | ~$0.03 | ~$15 | Claims near-proprietary quality |
| MiniMax | $0.20 | $0.40 | ~$0.01 | ~$4 | Budget option, quality TBD |
| Gemini Flash-Lite | $0.10 | $0.40 | ~$0.01 | ~$3 | Cheapest option, quality floor test |

Estimates assume a typical 20-page paper (~15K tokens in, ~12K tokens out). The gap between frontier and budget models is 10-50x. Processing the full backlog with a budget model costs less than a single month of any frontier model's pro subscription.

Note: frontier model subscriptions (Claude Pro, ChatGPT Plus, etc.) cannot be used for API calls — they only grant access to the provider's own tools (Claude Code, web chat, etc.). Using these models programmatically requires separate pay-per-token API billing, making the cost column above the actual cost with no way to amortize it against an existing subscription.

The PoC runs the same documents through 2-3 budget models and compares output quality. We're looking for the cheapest model that meets the 8/10 accuracy bar.

### CLI interface

```bash
# From a PDF
./ingest --source-id 1234 --input paper.pdf

# From a URL
./ingest --source-id 1234 --input "https://doi.org/10.5852/ejt.2026.1039.3193"

# From pre-extracted text (BHL copy-paste, etc.)
./ingest --source-id 1234 --input raw_text.txt

# Output to local file (default) or upload to S3
./ingest --source-id 1234 --input paper.pdf --output local  # writes to ./output/1234.md
./ingest --source-id 1234 --input paper.pdf --output s3      # uploads to s3://bucket/sources/1234.md
```

### LLM prompt strategy

The system prompt instructs the model to:

1. Clean OCR artifacts (broken words, garbled characters, column-merge errors)
2. Preserve the original text faithfully — no paraphrasing, no summarization
3. Apply consistent markdown formatting (headings, italics for Latin names, etc.)
4. Populate YAML frontmatter from metadata found in the document (title, authors, DOI) merged with operator-provided values (source_id, license)

The prompt does NOT ask the model to extract per-species entries, strip insect morphology, or apply the GF source description template. That's PoC 2. Layer 1 is: make the document machine-readable and store it.

### What PoC 1 validates

- **Text extraction quality**: Can we get clean text from the range of input formats (journal PDFs, BHL OCR, web pages)?
- **LLM formatting quality**: Does the model produce faithful, well-structured markdown without hallucinating or paraphrasing?
- **Cost per document**: Tokens in/out per document, cost at API rates. This gives a concrete number for "how much would it cost to process the backlog?"
- **Latency**: How long per document? Affects whether batch processing is practical.
- **Edge cases**: Very long documents (monographs), heavily damaged OCR, non-English sources, tables and figures.

### PoC 1 success criteria

- 8/10 processed documents need zero manual correction to the body text
- Frontmatter is correctly populated when metadata is present in the document
- Cost per document is under $0.05 for typical papers (under 30 pages) using a budget model
- Processing time is under 60 seconds for typical papers

### PoC 1 scope boundaries

**In scope:**
- Text extraction from PDF, URL, plain text
- LLM-based cleanup and formatting
- YAML frontmatter generation
- Local file output
- Optional S3 upload

**Out of scope:**
- Per-species data extraction (that's PoC 2)
- Any connection to the gallformers database or application
- Multi-user access or authentication
- Rate limiting or cost controls beyond "your API key, your bill"
- Batch processing (one document at a time for the PoC)

### PoC 2: Structured extraction (layer 2)

Takes a PoC 1 markdown artifact as input and extracts per-species structured data.

Given a clean markdown file from PoC 1, PoC 2:

1. **Sends the markdown to an LLM** with a system prompt specifying extraction rules and the source description template
2. **Produces a structured data file** (JSON or YAML) containing per-species entries with all extractable fields
3. **Writes the structured file** alongside the layer 1 markdown (locally or to S3)

#### Structured output format (draft — needs design work)

```json
{
  "source_id": 1234,
  "extracted_at": "2026-03-03T12:00:00Z",
  "model": "deepseek-v3",
  "species": [
    {
      "name": "Pseudoneuroterus saltabundus",
      "authority": "Sottile & Cerasa",
      "taxonomic_status": "sp. nov.",
      "description": "The gall typically develops on the lower surface...",
      "hosts": ["Quercus cerris"],
      "range": "Northern Italy, peninsular Italy, Hungary",
      "phenology": "Late spring, end of May to mid-June",
      "synonyms": [],
      "comments": "Only the asexual generation is known..."
    }
  ]
}
```

The exact schema needs design work — it should align with what the admin review UI (layer 3) can consume and map to existing database fields (species_source descriptions, host associations, gall traits, etc.).

#### What PoC 2 validates

- **Extraction accuracy**: Can the LLM correctly identify and separate per-species entries from a full document?
- **Field mapping**: Can it reliably extract hosts, range, phenology, traits into structured fields?
- **Edge cases**: Papers with many species in tables, species mentioned across multiple sections, ambiguous host associations.
- **Template adherence**: Does the extracted description text follow the source description template principles (direct quotation, no insect morphology, sparse entries OK)?

#### PoC 2 success criteria

- 8/10 species entries are correctly identified and separated from the document
- Host associations are correctly extracted when explicitly stated in the source
- Species names and authorities are parsed correctly
- The structured output is machine-readable and maps cleanly to GF data model concepts

#### PoC 2 scope boundaries

**In scope:**
- Structured data extraction from PoC 1 markdown output
- Per-species entry identification and separation
- Host, range, phenology, synonym extraction
- Structured output format design
- Local file output, optional S3 upload

**Out of scope:**
- Matching extracted species to existing GF database records
- Admin UI or changeset presentation (that's layer 3)
- Any database writes
- Trait value normalization (e.g., mapping free-text phenology to structured season fields)

## Future: hosted pipeline

Post-PoC, the ingestion pipeline could move from a local CLI to a hosted service, allowing more contributors to process documents without running the tool locally. This opens up significant questions around authentication, cost allocation, abuse prevention, multi-tenancy, and operational complexity — none of which need answers yet. Calling it out here so it's on the radar, but the PoCs come first. If the PoCs don't validate, none of this matters.

## Open questions

- Which budget models meet the quality bar for OCR cleanup (PoC 1) and structured extraction (PoC 2)? May be different models for different layers.
- What's the right structured output format for PoC 2? JSON? YAML? How does it map to the GF data model (species_source, host associations, gall_traits)?
- How should the layer 3 admin review UI present changesets? Per-species approval? Bulk review? Diff view against existing data?
- How should the markdown file handle non-text content (figures, plates, maps)? Omit? Placeholder? Caption only?
- For very long monographs (100+ pages), should the pipeline chunk the document or process it whole? Context window limits may force chunking.
- What's the right S3 key structure? `sources/{source_id}.md` + `sources/{source_id}.json` is simple but doesn't handle versioning. Do we need versioning?
- When does layer 3 (admin review UI) get built? After both PoCs validate and community feedback is in.
