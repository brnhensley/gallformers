---
status: raw
created: 2026-03-03
updated: 2026-03-04
epic: cynipid
relates: [0f79, 67c9]
---

# Genus-level host associations

## Problem

The `gallhost` table is species-to-species. When literature (e.g., Gagné's World Catalog) lists hosts at the genus level — "Lupinus spp." or "Garrya sp." — the only workaround is creating a fake species like "Lupinus spp". Users searching for a specific species (e.g., Lupinus arboreus) won't find galls associated only at the genus level.

This matters because:
- Older records often don't ID the host to species
- Catalogs like Gagné list genus-level hosts when many species in the genus are affected
- Users check their specific host species and consider the search done — they miss genus-level associations entirely

## Examples from Gagné

- **Asphondylia garryae**: hosts "Garrya sp.; G. buxifolia, G. fremontii" — mix of genus-level and species-level
- **Dasineura lupinorum**: hosts "Lupinus arboreus; Lupinus spp." — one specific species plus genus-level

## What exists today

- Taxonomy tree already links species → genus → family
- `get_species_ids_for_genus()` resolves a genus to all its species IDs
- ID tool already has genus-level filtering internally
- No schema support for recording association precision (genus vs species)

## Open questions

- How should genus-level associations appear in search results — alongside species-level, visually distinguished?
- Data model: new junction table (gall↔genus) vs flag/column on gallhost?
- How to handle mixed associations (some species explicit + genus-level catchall)?
- Range implications: does a genus-level association inherit range from all species in that genus?
