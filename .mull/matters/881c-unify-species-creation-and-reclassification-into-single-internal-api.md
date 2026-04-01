---
status: refined
created: 2026-03-22
updated: 2026-03-30
epic: taxonomy
relates: [7fda, fa48, 82f8]
blocks: [7fda, fa48]
needs: [8757]
---

# Unify species creation and reclassification into single internal API

## Design

Decisions from collaborative sessions 2026-03-22 and 2026-03-23.

### Domain Model

**Species → Taxonomy** (strict one-way dependency)

Species depends on Taxonomy. Taxonomy never imports/aliases/calls the Species module.

**Taxonomy owns:**
- The tree (families, genera, sections, intermediates) and all parent-child relationships
- All naming rules and constraints (uniqueness, valid types, placeholder logic)
- The `species.name` field — this is a denormalized cache of the species' position in the tree. Species context NEVER writes to `species.name`. Enforced by Boundary + custom Credo check (matter 8757).
- CRUD on all taxon types: family, genus, section, intermediates
- All tree operations (placement, movement, reclassification/rename)
- Genus/family resolution: parse name → find or create genus → find or create family
- Genus rename cascade: when a genus is renamed, Taxonomy updates all `species.name` values directly via `Repo.update_all` (cache maintenance, no Species module call)

**Species owns:**
- The species record CRUD (except `name` — see above)
- Aliases (CRUD) — aliases don't conform to taxonomy rules, they're just strings (common names, former scientific names, etc.)
- Everything non-taxonomic (images, sources, abundance)
- The specialized species operations: Split, Clone, Merge, Map — these delegate to Taxonomy for tree ops and handle the species-level concerns (alias creation, freeze/redirect for merge, etc.) themselves
- Transaction ownership for species-level operations

**Galls/Plants own:** trait-level data, host associations, range data

**Key invariant:** `species.name` is owned by Taxonomy. Species can read it but never write it. This is enforced mechanically via Boundary (module-level) and custom Credo check (field-level). See matter 8757.

### Why species.name is a cache

A species name encodes taxonomy — "Andricus quercuslanigera" embeds the genus "Andricus". When the genus is renamed, the species name must change. This makes the name a denormalized copy of the tree position. Taxonomy owns the canonical truth (the tree) and maintains the cache (the name string).

### Specialized Operations (Species-initiated, Taxonomy-delegated)

These live in Species because they're rich species-level operations, but they delegate tree work to Taxonomy:

- **Create:** `Species.create_species(params)` calls `Taxonomy.create_species_in_tree(name, taxoncode, opts)` for tree placement, then handles species-level setup (gall_traits, etc.). Transaction owned by Species.
- **Reclassify:** `Species.reclassify(species_id, new_name, opts)` calls `Taxonomy.move_species(...)` for tree movement and name update, then creates the alias for the old name itself. Transaction owned by Species.
- **Merge:** Two existing species become one. Freeze B, B's name becomes alias on A, B redirects to A. Species owns the orchestration (freeze, redirect), calls Taxonomy for any tree implications. Species creates the alias. (Implementation in matter 5c56.)
- **Split:** Clone species A into new B. `Species.create_species(...)` (which delegates to Taxonomy for tree placement) + `Species.reclassify(...)` on B for the new name. Composes from Create + Reclassify. (Implementation in matter 5c56.)
- **Map:** Add alias to existing species. Pure Species operation — no taxonomy mutation. `Species.create_alias_for_species(species_id, alias_attrs)`.

### Genus-Level References (from matter 53cb)

The name parser recognizes genus-level references ("Lupinus spp.", "Garrya sp."). The API contract acknowledges this variant:

```elixir
resolve_taxonomy(name, opts)
# Additional return: {:genus_reference, genus_name, genus_id | nil}
```

Not implemented now — returns the variant so callers can handle it (show a message, skip, etc.) without the system breaking on genus-level names. Full implementation tracked in matter 53cb.

### Current State

- **Creation:** GallLive.Form / HostLive.Form → `Galls.create_gall_with_associations` / `Plants.create_host_with_associations` → `SpeciesLink.link_species_taxonomy/4`
- **Reclassify:** ReclassifyLive modal → `Reclassification.reclassify_species/2` → `reassign_species_taxonomy/3` + `Reclassification.rename_species/3`
- **Gaps:** Gall/host form creation still calls SpeciesLink directly instead of unified Taxonomy API. Task 5 not started.

### Dependency: matter 8757 (architectural fitness testing)

Boundary + custom Credo checks are in place. 8757 is complete (closed).

## Implementation Progress (as of 2026-03-30)

### Task 1: Move naming functions from Species to Taxonomy — DONE
- `rename_species/3`, `rename_for_genus_change/4`, `add_rename_alias/2` moved from Species to Taxonomy.Reclassification
- Tests moved from `species_test.exs` to `taxonomy/reclassification_test.exs`
- `tree.ex` genus rename cascade updated to call `Taxonomy.rename_for_genus_change`
- `taxonomy.ex` has public delegations for all three functions
- Old functions removed from `species.ex`

### Task 2: Consolidate genus/family resolution into a single path — DONE
- `lookup_taxonomy_for_new_species/1` returns `{:genus_reference, ...}` variant
- `Lineage.lookup_result()` type updated
- `gall_live/form.ex` handles new variant in `lookup_genus_name/1`
- Tests in `taxonomy/species_link_test.exs` cover all resolution paths

### Task 3: Add genus/family creation to reclassify backend — DONE
- `reclassify_species/2` handles `genus_is_new: true` + `family_is_new: true` params
- Private `resolve_genus_id/1` and `resolve_family_id/1` create via `Tree.create_taxonomy`
- Tests cover: existing genus, new genus under existing family, new genus under new family, alias creation

### Task 4: Update reclassify modal UI for genus/family creation — DONE
- `reclassify_live.ex`: event handlers for create_family, create_genus, select_family_type; tracks genus_is_new, family_is_new, family_type state
- `form_components.ex`: allow_new + create_event on both typeaheads, family type dropdown for galls, removed "create in taxonomy manager first" note
- LiveView test covers reclassify-to-new-genus end-to-end

### Task 5: Migrate gall/host form creation to unified API — NOT STARTED
Gall/host forms still call `SpeciesLink.link_species_taxonomy/4` directly.

### Task 6: Verify and document — NOT STARTED

All changes are uncommitted on main branch, mixed with an unrelated PMTiles-via-CloudFront infrastructure change.

