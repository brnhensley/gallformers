---
status: done
created: 2026-03-22
updated: 2026-04-01
epic: taxonomy
relates: [7fda, fa48, 82f8]
blocks: [7fda, fa48]
needs: [8757]
---

# Unify species creation and reclassification into single internal API

# Unify species creation and reclassification into single internal API

## Design

Decisions from collaborative sessions 2026-03-22 and 2026-03-23.

### Domain Model

**Species → Taxonomy** (strict one-way dependency)

Species depends on Taxonomy. Taxonomy never imports/aliases/calls the Species module.

**Taxonomy owns:**
- The tree (families, genera, sections, intermediates) and all parent-child relationships
- All naming rules and constraints (uniqueness, valid types, placeholder logic)
- The `species.name` field — denormalized cache of tree position. Species context NEVER writes to it. Enforced by Boundary + custom Credo check (matter 8757).
- CRUD on all taxon types: family, genus, section, intermediates
- All tree operations (placement, movement, reclassification/rename)
- Genus/family resolution: parse name → find or create genus → find or create family
- Genus rename cascade: updates all `species.name` values directly via `Repo.update_all`

**Species owns:**
- Species record CRUD (except `name`)
- Aliases (CRUD)
- Everything non-taxonomic (images, sources, abundance)
- Specialized operations (Split, Clone, Merge, Map) — delegate to Taxonomy for tree ops
- Transaction ownership for species-level operations

**Galls/Plants own:** trait-level data, host associations, range data

### Specialized Operations

- **Create:** `Species.create_species(params, taxonomy_opts)` → `Taxonomy.place_species_in_tree` for tree placement
- **Reclassify:** `Taxonomy.Reclassification.reclassify_species/2` handles genus/family resolution (including creation of new genera/families), tree movement, species rename, and alias creation
- **Merge/Split:** Future (matter 5c56)

### Key Modules

- `Taxonomy.SpeciesLink` — species-taxonomy linkage, resolution, queries
- `Taxonomy.Reclassification` — rename, reclassify, genus rename cascade support
- `Taxonomy.Tree` — tree CRUD, genus rename cascade
- `Taxonomy.Lineage` — lineage struct and lookup helpers

## Completed

All six tasks done. Committed in a736b161.

1. **Move naming functions** — `rename_species/3`, `rename_for_genus_change/4`, `add_rename_alias/2` moved from Species to Taxonomy.Reclassification
2. **Consolidate genus/family resolution** — `lookup_taxonomy_for_new_species/1` returns `:genus_reference` variant for genus-level names (matter 53cb)
3. **Genus/family creation in reclassify backend** — `reclassify_species/2` handles `genus_is_new` + `family_is_new` params
4. **Reclassify modal UI** — `allow_new` + `create_event` on typeaheads, family type dropdown for galls
5. **Migrate forms to unified API** — Both `create_gall_with_associations` and `create_host_with_associations` call `Species.create_species` → Taxonomy (no direct SpeciesLink calls from forms)
6. **Verify and document** — Matter updated, all tests pass
