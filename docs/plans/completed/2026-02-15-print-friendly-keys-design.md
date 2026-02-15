# Print-Friendly Keys Design

**Date:** 2026-02-15
**Matter:** 66cb
**Status:** Design approved

## Problem

Keys need to be printable for two use cases: field reference (naturalists without internet) and publication (inclusion in papers and guides). The interactive web viewer at `/keys/:slug` is not suitable for print.

## Approach: Static PDF via Typst

Generate publication-quality PDFs using [Typst](https://typst.app), a modern typesetting engine. PDFs are pre-generated when keys are created or updated, stored on S3, and served via CDN links.

### Why Typst over CSS print

The features needed for a traditional dichotomous key — dot leaders, running headers, page numbers, couplet-level page break control — are native primitives in Typst. In CSS print, dot leaders require overflow hacks, running headers are Chromium-only (`@page` margin boxes), and page break control is a suggestion, not a guarantee. Typst is the right tool for typesetting.

### Why static over on-demand

Keys change rarely (admin edits only). Pre-generating PDFs on save avoids redundant work, removes latency from the user-facing path, and means serving is just a CDN link.

## Architecture

### PDF generation pipeline

```
Admin saves key
  → Keys.create_key/1 or Keys.update_key/2
  → on success, async Task.Supervisor task:
      → serialize key to JSON (sorted couplets, metadata)
      → write JSON to temp file
      → System.cmd("typst", ["compile", "--input", ...]) × 2 variants
      → upload PDFs to S3 at keys/{slug}/{slug}.pdf
                              keys/{slug}/{slug}-images.pdf
      → clean up temp files
```

### Two PDF variants per key

1. **Text-only** (`{slug}.pdf`) — compact, ideal for field use
2. **With images** (`{slug}-images.pdf`) — richer, for publication. Only generated when the key data contains images.

### Module structure

- `Gallformers.Keys.PdfGenerator` — orchestrates serialization, Typst CLI call, S3 upload
- `priv/typst/key.typ` — Typst template, checked into repo

### Error handling

PDF generation is async and non-blocking. If Typst fails, the key still saves successfully. Errors are logged. An admin "Regenerate PDFs" action handles cases where the template changes but key data hasn't.

## Typst template

### Page setup

- US Letter paper
- Serif font (Linux Libertine, bundled with Typst)
- Running header on pages 2+: key title (italic) + page number
- Footer: gallformers.org + generation date

### Document structure

1. Title block: title, subtitle, authors, citation, version, gallformers.org URL
2. Horizontal rule
3. Couplets in traditional dichotomous format:

```
1a. Leaf edge roll .......................... Prodiplosis morrisi
 b. Gall not a leaf edge roll ................................. 2

2a. Gall on leaf blade, globose ................. Cerapachys sp.
 b. Gall on petiole or stem .................................. 3
```

- Couplet number on first lead only, subsequent leads indented with letter
- Dot leaders via Typst's `repeat[.]`
- Taxon destinations in italics
- Couplet destinations as plain numbers
- Notes as smaller text below their lead, indented
- Images (when enabled) as small figures below the lead with captions
- Each couplet wrapped in `block(breakable: false)` to prevent page splits

### Data input

Key data serialized to JSON, passed via `--input data=...` CLI flag. Template reads with `json(bytes(sys.inputs.data))`.

## Public UI

On `/keys/:slug`, add download links:

- "Download PDF" — text-only variant
- "Download PDF (with images)" — shown only when key has images

Plain `<a>` tags to CDN URLs. Links hidden when PDFs haven't been generated.

## Deployment

### Typst binary

```dockerfile
COPY --from=ghcr.io/typst/typst:v0.14.2 /usr/local/bin/typst /usr/local/bin/typst
```

Pinned version, ~14MB addition to Docker image. No Elixir hex dependencies — CLI only via `System.cmd/3`.

### Template

Checked into repo at `priv/typst/key.typ`. Deployed with the release.

### Fonts

Typst bundles Linux Libertine. Custom fonts go in `priv/typst/fonts/` with `--font-path`.

### CI

Test that compiles a fixture key to PDF and asserts valid output. Catches template breakage on Typst version upgrades.

## Iteration plan

The template will be iterative. Initial implementation gets the structure rendering, then font choice, spacing, and typography are refined through visual review.
