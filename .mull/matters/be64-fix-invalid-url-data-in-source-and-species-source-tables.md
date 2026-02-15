---
status: active
created: 2026-02-15
updated: 2026-02-15
relates: [8257]
blocks: [1cab]
---

# Fix invalid URL data in source and species_source tables

Ecto migration to clean 12 bad URL records causing 500 errors in production.

source.link — 8 bad records:
- 393: missing scheme (doi.org/...)
- 491: not a URL — title text pasted into link field
- 504: missing scheme (ir.cut.ac.za/...)
- 588: not a URL — citation text pasted into link field
- 622: literal 'none'
- 787: missing scheme (www.biodiversitylibrary.org/...)
- 805: missing scheme (www.jstor.org/...)
- 835: missing scheme (www.biodiversitylibrary.org/...)

species_source.externallink — 4 bad records:
- 522 (species 570): leading space in URL
- 1524 (species 1400): corrupt prefix 'blandahttps://...'
- 5943 (species 581): whitespace only
- 7943 (species 5594): missing scheme (www.biodiversitylibrary.org/...)

Fix approach: migration that trims whitespace, prepends https:// where fixable, clears garbage values (491 title text, 588 citation text, 622 literal 'none', 1524 remove 'blanda' prefix).

Root cause identified in investigation: docs/investigations/20260215-request-log-anomalies-oom.md Finding #5.
Crash is ArgumentError in Phoenix <.link> component when given URLs with unsupported schemes.
