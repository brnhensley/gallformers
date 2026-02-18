---
status: raw
created: 2026-02-14
updated: 2026-02-17
epic: idea-bucket
---

# Morpho research - Deans and Prior Labs

Investigate morphological description work from two labs:

Deans Lab:
- Paper: https://bdj.pensoft.net/article/128585/

Prior Lab:
- TODO: Get links/PDFs for their work

Goals:
- Understand what morpho work has been done at both labs
- Evaluate relevance to gallformers data model and identification tools
- Identify potential integration points or data standards we should adopt

Research completed 2026-02-14: Downloaded GallOnt v2024-04-19 (OBO + OWL) to docs/ontology/. Created trait-mapping.md with full Gallformers-to-GallOnt mapping across all 10 trait categories. Key findings: cells/chambers near-perfect alignment, shape/texture partially aligned with ~15 terms each side lacks, GF forms are mostly practical field terms without ontology equivalents, and GallOnt has several major concepts GF lacks entirely (attachment style, spatial pattern, quantitative size, internal structure as separate category).

Integration levels (from conversation with lfn77 — researcher wants stored mapping + accessibility, not UI vocabulary changes):

Level 0: Static reference (done) — trait-mapping.md in docs/ontology/. Researchers can consult it. Zero code changes.

Level 1: Store GallOnt IDs alongside trait values — Add optional ontology_id column to each filter field table (shapes, textures, etc.). Populate for values with matches. No UI change, just queryable metadata. This is likely what lfn77 means by 'store those somewhere accessible.'

Level 2: Link out from trait values — When displaying a trait, if it has an ontology_id, render a small link icon to the OLS viewer page for that term. Minimal UI impact, huge value for researchers (formal definitions, synonyms, hierarchy).

Level 3: Ontology-aware browsing — Dedicated page/section showing GallOnt hierarchy with GF values mapped in. What lfn77 hinted at with 'term hierarchy located somewhere.' Biggest effort, needs clearer audience understanding first.

Sweet spot is probably Level 1 + Level 2: respects simplicity for everyday users, gives researchers interoperability, modest effort.

Level 3 exploration — three distinct use cases emerged:

A. Ontology-as-query: Browse GF galls via GallOnt hierarchy tree. Requires Level 1 in DB first.
B. Illustrated glossary: Reference page with GallOnt hierarchy, formal definitions, example photos (iNat links from OBO), mapped to GF trait values. Deep-linkable terms, cross-referenced back to ontology. Could REPLACE the existing filter terms help page. Highest value, lowest effort entry point.
C. Trait gap finder: Data completeness tool showing which GallOnt terms have no GF equivalent, which species are missing traits. Curation tool. Needs Level 1.

Key insight: The glossary (B) isn't just a nice-to-have — it serves as:
- Replacement for current filter terms help page
- Curation reference (definitions + photos help volunteers score consistently)
- Foundation that makes A and C natural extensions later
- Deep-linkable terms mean other pages/tools can reference specific definitions

The iNat observation links in the OBO file are a goldmine — nearly every GALLONT term has a seeAlso linking to an iNat observation as a visual example.

Current filter guide (gallformers.org/filterguide) is text-only definitions across 8 categories, no images. The illustrated glossary would replace it at the same URL with:

- Formal definitions sourced from GallOnt (more precise)
- Example photos from iNat (seeAlso links in OBO file)
- Deep-linkable anchors per term (e.g. /filterguide#monothalamous)
- Filter toggle: 'GF terms only' (default, serves current audience) vs 'All ontology terms' (shows full GallOnt vocabulary with GF terms highlighted)
- Visual indicator on each term: whether it maps to a GF trait value or is GallOnt-only
- Cross-reference links to OLS viewer for each term

This serves both audiences: everyday users get a better version of what they have today (default view), researchers get the full ontology context (toggled view). Neither audience is confused by the other's needs.

Implementation note: Current filter guide is lib/gallformers_web/live/filter_guide_live.ex

Correction: Level 3B (illustrated glossary) does NOT depend on Level 1. The glossary is a read-only reference page built from: (1) the trait mapping doc, (2) GallOnt OBO file (definitions + iNat seeAlso links), (3) existing filter field tables for current GF terms. The mapping can be a static data structure in code or parsed from the OBO at build time. Level 1 (ontology_id in DB) is only needed for Level 3A (ontology-as-query) and 3C (gap analysis against live species data).

Additional integration opportunities:

6. Semantic similarity between galls — With ontology-grounded traits, compute structured similarity between galls. Could power a 'similar galls' feature on species pages or help flag potential misidentifications.

7. Trait hierarchy in ID tool — Use the ontology's parent/child relationships to broaden ID tool filters. Selecting 'hairy' could implicitly match subtypes like hispid, arachnose, felt-like. Makes identification more forgiving for users who don't know the precise term.

8. Prior Lab data ingest — Their lab is scoring traits on GF species using GallOnt vocabulary. If both systems share IDs, their scored datasets could flow back as trait data, enriching records we don't have volunteer capacity to curate ourselves.
