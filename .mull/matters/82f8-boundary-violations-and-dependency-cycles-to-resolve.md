---
status: done
created: 2026-03-24
updated: 2026-03-26
epic: platform
relates: [8757, 881c, 3f58]
---

# Boundary violations and dependency cycles to resolve

## Resolved

### Dependency cycles (3 → 1)

- **Search ↔ Places**: moved TextMatch to own top-level boundary (Gallformers.TextMatch)
- **Galls ↔ GallHosts** and **Ranges ↔ GallHosts**: dissolved GallHosts context — gall-side functions to Galls.HostAssociations, host-side to Plants, schema to Galls.GallHost
- **Galls ↔ Ranges**: pre-existing cycle that was hidden behind GallHosts. Now visible and honest. Both directions are declared deps.

### Shared module promotion

- **Gallformers.TextMatch** — extracted from Search boundary. Pure-logic, zero deps.
- **Gallformers.TaxonName** — extracted from Taxonomy boundary. Pure-logic, zero deps.
- Both remain as dirty_xrefs in GallformersWeb due to Boundary's structural limitation: sub-boundaries can't be listed as deps by non-sibling boundaries.

### Boundary leak fixes

- `Species.get_images_for_species` → moved to `Images.list_images_for_species`
- `Key.key_has_images?`, `Key.serialize` → moved from PdfGenerator to Key schema
- `Keys.s3_paths`, `Keys.cdn_urls` → moved from PdfGenerator to Keys context
- `Keys.generate_and_upload` → delegated through Keys (PdfGenerator removed from dirty_xrefs)
- About controller taxonomy stats → moved to `Taxonomy.count_families_for_taxoncode/1` and `count_genera_for_taxoncode/1`
- `Lineage.from_path`, `Lineage.placeholder_genus?` → delegated through Taxonomy context

### Dirty_xrefs reduced (20 → 18)

Removed: `Keys.PdfGenerator`, `Taxonomy.TaxonName`. Added: `TaxonName`, `TextMatch` (structural, not leaks).

## Intentionally deferred

- **Taxonomy → Species/Galls dirty_xrefs** — deferred to 881c (unified taxonomy API)
- **Species.enrich_with_common_names_and_counts** — cross-context composition, left as dirty_xrefs (Galls, Plants). Not worth the abstraction cost.
- **Auth0User/User unification** — captured as matter 3f58. The web layer's Auth0User references are a domain model issue, not a boundary fix.
- **Repo in health_controller** — legitimate infra (health check pinging DB)
- **Repo in sitemap_controller** — 7 simple ID queries. Adding context functions solely for sitemap is tail-wagging-dog.
- **SchemaFields.required?** — structural, correct as-is. Cross-cutting UI infrastructure.
- **Remaining GallformersWeb struct dirty_xrefs** — structural consequence of Boundary's hierarchy model. Sub-boundary internal modules (schemas) can't be accessed without dirty_xrefs when the consumer deps on the parent boundary.
- **Galls ↔ Ranges cycle** — genuine mutual dependency. Both contexts legitimately call each other. Fixing requires rethinking range ownership, out of scope for this matter.
