---
status: raw
effort: 5 days
created: 2026-02-13
updated: 2026-02-18
epic: geo-expansion
blocks: [1db6]
---

# Host plant data sourcing for Central/South America

## Research phase (2 days)
Identify data sources for Central and South American host plants. Evaluate coverage, data quality, and format compatibility.

## Data import phase (1 day)
Pull in data from sources identified in research phase. Map to existing taxonomy, resolve naming conflicts.

## Importer tooling (2 days)
Existing USDA importer (services/usda_plants/) will need to be updated or rewritten for new data sources. Name parsing is particularly tricky — botanical names from Latin American sources have varied formatting conventions, subspecies/variety notation, and author citation styles that make reliable parsing difficult.
