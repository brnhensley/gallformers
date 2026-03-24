---
status: refined
created: 2026-03-22
updated: 2026-03-24
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

The name parser should recognize genus-level references ("Lupinus spp.", "Garrya sp."). The API contract acknowledges this variant:

```elixir
resolve_taxonomy(name, opts)
# Additional return: {:genus_reference, genus_name, genus_id | nil}
```

Not implemented now — returns the variant so callers can handle it (show a message, skip, etc.) without the system breaking on genus-level names. Full implementation tracked in matter 53cb.

### Current State

- **Creation:** GallLive.Form / HostLive.Form → `Galls.create_gall_with_associations` / `Plants.create_host_with_associations` → `SpeciesLink.link_species_taxonomy/4`
- **Reclassify:** ReclassifyLive modal → `Reclassification.reclassify_species/2` → `reassign_species_taxonomy/3` + `Species.rename_species/3`
- **Gaps:** Reclassify cannot create new genera or families. `rename_species`, `rename_for_genus_change`, `add_rename_alias` live in Species but are taxonomy operations. No enforcement of species.name ownership.

### Dependency: matter 8757 (architectural fitness testing)

Boundary + custom Credo checks MUST be in place before this work begins. 881c establishes the dependency direction and species.name ownership rule. 8757 encodes and enforces those rules mechanically so they can't be undone by agents or future developers.

## Implementation Plan

**Goal:** Unify species creation and reclassification into a coherent API with strict Species → Taxonomy dependency. Close the genus/family creation gap in reclassify. Establish species.name as Taxonomy-owned.

**Architecture:** Move naming/rename operations from Species to Taxonomy. Consolidate SpeciesLink and Reclassification. Add genus/family creation to reclassify modal. Migrate all callers. Includes c836 scope (genus/family creation during reclassify).

**Prerequisite:** Matter 8757 (Boundary + Credo checks) must be complete first.

### Task 1: Move naming functions from Species to Taxonomy

**Files:**
- Modify: `lib/gallformers/species.ex` (remove `rename_species`, `rename_for_genus_change`, `add_rename_alias`)
- Modify: `lib/gallformers/taxonomy.ex` (add public API delegations)
- Modify: `lib/gallformers/taxonomy/reclassification.ex` (absorb the moved functions)
- Modify: all callers of the moved functions
- Test: `test/gallformers/taxonomy/reclassification_test.exs` (new or expanded)

**Behavior:**
Move `rename_species/3`, `rename_for_genus_change/4`, and `add_rename_alias/2` from `Species` into `Taxonomy.Reclassification`. These are taxonomy operations — they involve name resolution and tree position. Update all callers. Species retains `create_alias_for_species/2` as a low-level alias primitive.

**Testing:**
- Existing rename tests move with the functions
- Verify all callers compile and pass
- Boundary check confirms Species no longer has rename logic
- Credo check confirms Species doesn't write to :name

**Notes:**
Leave temporary `@deprecated` delegations in Species only if caller migration can't be done atomically. Prefer updating all callers in this task.

### Task 2: Consolidate genus/family resolution into a single path

**Files:**
- Modify: `lib/gallformers/taxonomy/species_link.ex` (refactor `link_species_taxonomy/4` and `lookup_taxonomy_for_new_species/1`)
- Modify: `lib/gallformers/taxonomy/reclassification.ex` (use the consolidated resolution)
- Test: `test/gallformers/taxonomy/species_link_test.exs`

**Behavior:**
Both creation and reclassification need genus/family resolution. Today they use separate paths. Consolidate into a single function:

```elixir
resolve_taxonomy(name, opts)
# Returns:
#   {:ok, genus_id}
#   {:new_genus, genus_name, family_id}
#   {:ambiguous, genus_name, families}
#   {:genus_reference, genus_name, genus_id | nil}  # from 53cb — "Lupinus spp."
#   {:error, reason}
```

Encapsulates: parse genus from name → detect genus-level references → look up genus → if not found, determine if family exists → signal for creation if needed.

**Testing:**
- Genus exists in one family → `{:ok, genus_id}`
- Genus exists in multiple families → `{:ambiguous, ...}`
- Genus doesn't exist, family exists → `{:new_genus, ...}`
- Genus doesn't exist, family doesn't exist → signals family creation needed
- Genus is placeholder ("Unknown") → find-or-create Unknown genus under family
- "Lupinus spp." → `{:genus_reference, "Lupinus", genus_id_or_nil}`

### Task 3: Add genus/family creation to reclassify backend

**Files:**
- Modify: `lib/gallformers/taxonomy/reclassification.ex` (handle new genus/family in `reclassify_species`)
- Modify: `lib/gallformers/taxonomy/tree.ex` (ensure `create_taxonomy` works for families with type/description)
- Test: `test/gallformers/taxonomy/reclassification_test.exs`

**Behavior:**
`reclassify_species/2` accepts new params: `genus_is_new: true`, `family_id: id` (or `family_is_new: true`, `family_name: name`, `family_type: type`). When `genus_is_new`, creates genus under specified family before reassigning. When `family_is_new`, creates family first (with required `description`/type), then genus.

Family type rules:
- Gall families: user must select type (Wasp, Midge, Fly, etc.)
- Host families: type auto-set to "Plant"

**Testing:**
- Reclassify to existing genus (unchanged behavior)
- Reclassify to new genus under existing family → genus created, species moved
- Reclassify to new genus under new family → family + genus created, species moved
- Gall family requires type selection
- Host family auto-sets "Plant"
- Alias created for old name when requested

### Task 4: Update reclassify modal UI for genus/family creation

**Files:**
- Modify: `lib/gallformers_web/live/admin/reclassify_live.ex` (handle "create new" in typeaheads)
- Modify: `lib/gallformers_web/components/form_components.ex` (enable `allow_new` on family/genus typeaheads)
- Test: `test/gallformers_web/live/admin/reclassify_live_test.exs`

**Behavior:**
- Family typeahead: enable `allow_new`. No match + "Create" → show family type dropdown for galls, auto-set "Plant" for hosts. Store `family_is_new: true, family_name, family_type` in modal state.
- Genus typeahead: enable `allow_new`. No match + "Create" → store `genus_is_new: true, genus_name` in modal state.
- Save dispatches to updated `reclassify_species/2` with new params.
- Remove "create in taxonomy manager first" note.

**Testing:**
- New genus: typeahead shows "Create", save creates genus
- New family (gall): type dropdown appears, save creates family + genus
- New family (host): type auto-set, no dropdown
- Existing behavior unchanged

### Task 5: Migrate gall/host form creation to unified API

**Files:**
- Modify: `lib/gallformers/galls.ex` (`create_gall_with_associations` uses unified Taxonomy functions)
- Modify: `lib/gallformers/plants.ex` (`create_host_with_associations` uses unified Taxonomy functions)
- Modify: `lib/gallformers_web/live/admin/gall_live/form.ex` (simplify taxonomy handling)
- Modify: `lib/gallformers_web/live/admin/host_live/form.ex` (simplify taxonomy handling)
- Test: existing gall/host form tests must pass unchanged

**Behavior:**
Replace direct calls to `SpeciesLink.link_species_taxonomy/4` with the unified Taxonomy API from Task 2. Form LiveViews should simplify — taxonomy resolution logic moves out of forms into Taxonomy context.

**Testing:**
- All existing gall creation tests pass
- All existing host creation tests pass
- Create with new genus still works
- Ambiguous genus still shows disambiguation
- Host section linking still works

**Notes:**
Riskiest task — changing working creation flows. Do not change behavior, only change which functions are called. Full test suite after every change.

### Task 6: Verify and document

**Files:**
- Modify: `CODING_STANDARDS.md` (Taxonomy naming API patterns, species.name ownership)
- Modify: `CLAUDE.md` (update architecture patterns, dependency direction)

**Behavior:**
Full precommit. Boundary check passes (no circular deps). Credo custom check passes (no Species writes to name). Document the unified API, domain model decision, and dependency direction.

**Testing:**
- `mix precommit` passes
- `mix boundary.check` passes
- No remaining direct calls to moved functions
- No Species → Taxonomy calls (Boundary enforces this)
- No Species writes to species.name (Credo enforces this)
