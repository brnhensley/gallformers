---
status: refined
created: 2026-03-24
updated: 2026-03-24
epic: platform
relates: [8757, 881c]
---

# Boundary violations and dependency cycles to resolve

Discovered during Boundary setup (matter 8757). These are existing architectural issues, not introduced by Boundary — Boundary just made them visible.

## Dependency Cycles

Three circular dependencies between context modules:

1. **Galls ↔ GallHosts** — `Gallformers.Galls` deps on `Gallformers.GallHosts` and vice versa
2. **Search ↔ Places** — `Gallformers.Search` deps on `Gallformers.Places` and vice versa
3. **Ranges ↔ GallHosts** — `Gallformers.Ranges` deps on `Gallformers.GallHosts` and vice versa

These are warnings, not build failures. But they indicate tight coupling that should be untangled.

## Taxonomy → Species/Galls (dirty_xrefs)

Will be resolved by 881c (unified taxonomy API). Listed here for completeness:

- `Gallformers.Taxonomy` → `Gallformers.Species` (3 modules: Species, Species.Species, Species.Alias)
- `Gallformers.Taxonomy` → `Gallformers.Galls` (1 module: reclassification.ex calls force_undescribed_if_placeholder)

## Species cross-context references (dirty_xrefs)

- `Gallformers.Species` → `Gallformers.GallHosts` (GallHost schema) — Species.enrich_with_common_names_and_counts uses gallhost join
- `Gallformers.Species` → `Gallformers.Galls.GallTraits` — Species references GallTraits schema
- `Gallformers.Species` → `Gallformers.Images.Image` — Species.get_images_for_species queries Image schema

These suggest Species is doing too much — enrichment and image queries should probably live in their respective contexts.

## GallformersWeb → context sub-modules (dirty_xrefs)

Web layer directly references internal schema/sub-modules instead of going through context public APIs:

- `Gallformers.Accounts.Auth0User`, `Gallformers.Accounts.User`
- `Gallformers.Articles.Article`
- `Gallformers.Galls.Summary`
- `Gallformers.Images.Attribution`, `Gallformers.Images.Audit`, `Gallformers.Images.AuditCache`, `Gallformers.Images.Image`
- `Gallformers.Keys.Key`, `Gallformers.Keys.PdfGenerator`
- `Gallformers.Search.TextMatch`
- `Gallformers.Sources.Source`
- `Gallformers.Species.Species`, `Gallformers.Species.SpeciesSource`
- `Gallformers.Taxonomy.Genus`, `Gallformers.Taxonomy.Lineage`, `Gallformers.Taxonomy.TaxonName`, `Gallformers.Taxonomy.Taxonomy`, `Gallformers.Taxonomy.Tree`
- `Gallformers.Wcvp.Lookup`, `Gallformers.Wcvp.Tdwg`

Many of these are legitimate (e.g., pattern matching on schema structs in templates). Others are genuine leaks (calling Tree functions directly from LiveViews).

## GallformersWeb → Repo, SchemaFields (dirty_xrefs)

Web layer calls Repo directly and references SchemaFields. Should go through contexts per architectural principles 1 & 5.

