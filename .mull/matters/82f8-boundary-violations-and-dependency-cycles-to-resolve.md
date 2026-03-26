---
status: refined
created: 2026-03-24
updated: 2026-03-26
epic: platform
relates: [8757, 881c, 3f58]
---

# Boundary violations and dependency cycles to resolve

Discovered during Boundary setup (matter 8757). These are existing architectural issues, not introduced by Boundary — Boundary just made them visible.

## Dependency Cycles

Three circular dependencies between context modules:

1. **Galls ↔ GallHosts** — `Gallformers.Galls` deps on `Gallformers.GallHosts` and vice versa
2. **Search ↔ Places** — `Gallformers.Search` deps on `Gallformers.Places` and vice versa
3. **Ranges ↔ GallHosts** — `Gallformers.Ranges` deps on `Gallformers.GallHosts` and vice versa

### Search ↔ Places

Matter 154b extracted `TextMatch` into a shared module but left it inside the `Gallformers.Search` boundary. Places aliases `Gallformers.Search.TextMatch`, creating the cycle. Fix: move `TextMatch` to its own boundary or a shared location (e.g., `Gallformers.TextMatch`). Zero behavioral change — pure boundary reorganization.

### Galls ↔ GallHosts and Ranges ↔ GallHosts — dissolve GallHosts

GallHosts is a context organized around a table rather than a domain concept. The `gallhost` table is an implementation detail — the domain concepts are "a gall forms on hosts" (Galls' perspective) and "a host has galls" (Plants' perspective).

**Cohesion**: low-to-moderate. Two distinct clusters — join table CRUD (cohesive) and a composite orchestrator (`save_gall_host_changes`) that reaches into Galls, Ranges, and Species.

**Coupling**: high for a join table wrapper. 7 modules depend on it (Ca), it depends on 5 boundaries (Ce), two of which create cycles.

**How it grew**: the schema needed a home (reasonable), then relationship queries accumulated there because they were lengthy and neither Galls nor Plants felt right. Result: a boundary organized around a table, not a concept.

**Resolution: dissolve into natural owners.**

| Function cluster | Natural owner | Rationale |
|---|---|---|
| `get_hosts_for_gall`, `add/remove_host_to_gall`, host counts for galls, `get_host_species_ids_for_gall` | Galls (internal module, e.g., `Galls.HostAssociations`) | Gall lifecycle |
| `get_galls_for_host`, gall counts for hosts | Plants | Host perspective |
| `save_gall_host_changes` (orchestrator) | Galls | It's a gall admin save |
| `GallHost` schema | `Galls.GallHost` | Galls is the primary consumer |

Length concern is real but handled by internal modules (like existing `Galls.Identification`). Functions stay organized without needing a separate boundary.

This eliminates both GallHosts cycles — not by restructuring dependencies, but by removing the artificial boundary that created them. Ranges would still query the `GallHost` schema directly (schema ≠ context boundary).

## Taxonomy → Species/Galls (dirty_xrefs)

Will be resolved by 881c (unified taxonomy API). Listed here for completeness:

- `Gallformers.Taxonomy` → `Gallformers.Species` (3 modules: Species, Species.Species, Species.Alias)
- `Gallformers.Taxonomy` → `Gallformers.Galls` (1 module: reclassification.ex calls force_undescribed_if_placeholder)

## Species cross-context references (dirty_xrefs)

- `Gallformers.Species` → `Gallformers.GallHosts` (GallHost schema) — Species.enrich_with_common_names_and_counts uses gallhost join
- `Gallformers.Species` → `Gallformers.Galls.GallTraits` — Species references GallTraits schema
- `Gallformers.Species` → `Gallformers.Images.Image` — Species.get_images_for_species queries Image schema

These suggest Species is doing too much — enrichment and image queries should probably live in their respective contexts. Note: GallHosts dissolution will change the Species → GallHosts xref — Species will need to call Galls for gall-related counts and Plants for host-related counts instead.

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
