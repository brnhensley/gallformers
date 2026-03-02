---
status: done
created: 2026-02-28
updated: 2026-03-01
epic: taxonomy
relates: [5c56]
---

# Intermediate taxonomy ranks (subfamily, tribe, etc.)

## Motivation

A contributor adding world herb gall wasps (Aulacideini) needs intermediate ranks between Family and Genus. Cynipidae has subfamily/tribe structure; Cecidomyiidae is even more complex (supertribes, subtribes). The DB also covers mites, fungi, aphids — the set of valid ranks varies across organism groups and may not be stable.

## Design Decisions

### Gall-formers only (for now)
Host plant taxonomy between family and genus is unstable and less universally used. This expansion applies to gall-former families only. Hosts keep the existing Family → Genus → Section model.

### Two structural anchors, flexible middle
Family and genus are the two structurally special types — family is the root, genus is what species attach to. Everything between them is an "intermediate" node with a freeform rank label. No hardcoded rank enum.

### Data model
Extend the existing `taxonomy` table:
- Add `type: "intermediate"` to the validated types (alongside family/genus/section)
- Add a `rank` column (string) for the display label ("Subfamily", "Tribe", "Subtribe", etc.)
- `parent_id` chain encodes ordering: Family → intermediate → intermediate → ... → Genus
- No global rank ordering needed — the tree structure IS the ordering

### Lineage struct
`%Lineage{}` gains an `intermediates` field — a list of `%{id, name, rank}` maps ordered root-to-leaf. Empty list `[]` for species with no intermediates (the vast majority today). Existing code that accesses `.family`, `.genus`, `.section` is unaffected.

### Query strategy
`get_taxonomy_path` recursive CTE already handles arbitrary depth. Lineage construction uses it and partitions results by type: family, intermediates (sorted by depth), genus, section.

## Admin UI

### Create intermediate
1. Pick parent (family or existing intermediate)
2. Enter rank label ("Subfamily", "Tribe", etc.)
3. Enter name ("Cynipinae", "Aulacideini", etc.)
4. Select children to move under it — shows all current direct children of the chosen parent. **Minimum one child required.** No empty intermediates.
5. Save atomically — create node + re-parent children in one transaction

### Edit intermediate
Change name, rank label, or description. Changing parent re-parents the whole subtree.

### Delete intermediate
Collapse upward — children re-parent to the deleted node's parent. Same confirmation UX as existing taxonomy deletes: impact summary (N children will move to parent X) + name-type-to-confirm modal.

### Genus creation changes
Parent picker now shows intermediates as valid parents, not just families. A genus can parent to whatever the lowest node in the chain is.

### Index page
Filter dropdown adds "intermediate" type. Rows show rank label as a badge.

## Public UI

### Species pages (gall/host)
Replace inline taxonomy rendering with the `taxonomy_breadcrumb` component (currently exists but is unused). Full clickable chain: Family → Subfamily → Tribe → Genus.

### Intermediate browse page
New page (e.g. `/gall/taxonomy/:id`) — a single parameterized LiveView for any intermediate node. Shows:
- Name and rank ("Tribe: Aulacideini")
- Parent chain as breadcrumb
- Direct children list (intermediates or genera) with species counts

### Genus page
Breadcrumb updated to show intermediates above it.

### Family browse page
Children list now shows mix of top-level intermediates and genera not yet assigned to an intermediate.

### Search
Typeahead includes intermediates. "Aulac" → "Aulacideini (Tribe)". Selecting navigates to the intermediate browse page.

## Blast Radius

**Structural changes (must change):**
- `lineage.ex` — struct + 4 constructors
- `species_link.ex` — `get_taxonomy_for_species/1` query
- `tree.ex` — `get_genus_lineage`, `get_section_lineage`, `build_taxonomy_from_genus`
- Inline struct literals in `reclassify_helpers.ex`, `species_link.ex` (add `intermediates: []`)
- Test struct literals in `taxonomy_test.exs`, `galls_test.exs`, `plants_test.exs`

**Display changes (additive):**
- `gall_live.ex`, `host_live.ex`, `section_live.ex`, `genus_live.ex` — wire up `taxonomy_breadcrumb`
- `data_display_components.ex` — update `taxonomy_breadcrumb` to handle intermediates
- New intermediate browse LiveView

**No change needed:**
- Admin forms (pass-through), `galls.ex`, `plants.ex` business logic, prod data tests — access `.family`/`.genus`/`.section` only

## Migration
Single migration: add `rank` column to `taxonomy` table, update type check constraint (if any) to include "intermediate".

## Implementation Plan

**Goal:** Add support for intermediate taxonomy ranks (subfamily, tribe, etc.) between family and genus for gall-former families, with full admin CRUD and public browse/search.

**Architecture:** Extend the existing single-table `taxonomy` model with a new `"intermediate"` type and freeform `rank` column. The parent_id chain already supports arbitrary depth. Lineage struct gains an `intermediates` list. All existing family/genus/section behavior is unchanged — intermediates are additive.

**Tech Stack:** Ecto migration, Phoenix LiveView, existing taxonomy context modules, recursive CTE.

### Task 1: Migration and Schema

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_intermediate_taxonomy_rank.exs`
- Modify: `lib/gallformers/taxonomy/taxonomy.ex` (schema, changeset, type validation)
- Modify: `priv/repo/structure.sql` (reference update for rank column)
- Test: `test/gallformers/taxonomy_test.exs`

**Behavior:**
Add `rank` column (nullable string) to taxonomy table. Extend `@taxonomy_types` to include `"intermediate"`. Update changeset: intermediates require `parent_id` (like genus/section) and `rank` is required when type is `"intermediate"`. Family and genus changesets are unchanged. The `rank` field is freeform — no enum, just a string like "Subfamily" or "Tribe".

**Testing:**
- Valid intermediate changeset with name, type "intermediate", parent_id, rank
- Invalid intermediate changeset missing rank
- Invalid intermediate changeset missing parent_id
- Existing family/genus/section changesets still work (rank ignored)
- `taxonomy_types/0` includes "intermediate"

```elixir
# Schema addition
field :rank, :string

# In changeset, after existing validations:
|> maybe_require_rank()

defp maybe_require_rank(changeset) do
  if get_field(changeset, :type) == "intermediate" do
    validate_required(changeset, [:rank], message: "is required for intermediate ranks")
  else
    changeset
  end
end
```

**Notes:** The migration is straightforward — just `alter table(:taxonomy) do add :rank, :string end`. No data migration needed since no intermediates exist yet. Update `maybe_require_parent` to include `"intermediate"` alongside genus and section.

### Task 2: Intermediate Domain Struct and Lineage Extension

**Files:**
- Create: `lib/gallformers/taxonomy/intermediate.ex`
- Modify: `lib/gallformers/taxonomy/lineage.ex`
- Test: `test/gallformers/taxonomy_test.exs`

**Behavior:**
Create a lightweight `Intermediate` struct (like `Family`, `Genus`, `Section`) with fields: `id`, `name`, `rank`, `description`. Add `intermediates` field to `Lineage` struct — a list of `Intermediate.t()` ordered root-to-leaf, defaulting to `[]`.

Update all four Lineage constructors:
- `from_genus/1` — walk the parent chain via `get_taxonomy_path` instead of single-hop preload. Partition results: family node → `family`, intermediate nodes → `intermediates` (sorted by depth), starting genus → `genus`.
- `from_section/2` — calls `from_genus` (which now handles intermediates), then patches section.
- `new_genus/1` — set `intermediates: []`.
- `from_query_result/2` — this is the hot path (called from `get_taxonomy_for_species`). Needs a new approach since the current query only does a single join to family.

**Testing:**
- `Lineage` struct includes `intermediates` field
- `from_genus` with no intermediates returns `intermediates: []`
- `from_genus` with one intermediate (subfamily) returns it in list
- `from_genus` with two intermediates (subfamily → tribe) returns them ordered root-to-leaf
- `from_section` inherits intermediates from genus lineage
- `new_genus` has `intermediates: []`
- `from_query_result` populates intermediates when provided

```elixir
# Intermediate struct
defmodule Gallformers.Taxonomy.Intermediate do
  defstruct [:id, :name, :rank, :description]
  @type t :: %__MODULE__{id: integer() | nil, name: String.t(), rank: String.t(), description: String.t() | nil}
end
```

**Notes:** The `from_genus` constructor currently does `Repo.preload(:parent)` for a single hop. With intermediates, it needs to walk an arbitrary chain. The cleanest approach: use `get_taxonomy_path(genus.id)` which already returns the full path via recursive CTE, then partition by type. This avoids N+1 preloads.

Depends on: Task 1.

### Task 3: Query Changes for Lineage Construction

**Files:**
- Modify: `lib/gallformers/taxonomy/tree.ex` (`get_genus_lineage`, `get_section_lineage`, `build_taxonomy_from_genus`)
- Modify: `lib/gallformers/taxonomy/species_link.ex` (`get_taxonomy_for_species`, `get_taxonomy_for_species_batch`)
- Test: `test/gallformers/taxonomy_test.exs`

**Behavior:**
`get_genus_lineage/1` — replace `Repo.preload(:parent)` + `Lineage.from_genus` with `get_taxonomy_path(id)` + `Lineage.from_path`. Same for `get_section_lineage/1` and `build_taxonomy_from_genus/1`.

`get_taxonomy_for_species/1` — the genus query currently joins one level up (genus → family). With intermediates, the genus's parent might be a tribe, not a family. Two options: (a) use the recursive CTE from the genus to find the family, or (b) change `from_query_result` to accept the taxonomy path. Option (a) is cleaner — after getting genus_id from species_taxonomy, call `get_taxonomy_path(genus_id)` and partition.

`get_taxonomy_for_species_batch/1` — currently does genus → parent in one join. With intermediates, parent might not be a family. This needs a different approach: fetch genus IDs from species_taxonomy, then batch-fetch paths. For the batch case (used for listing pages), intermediates may not be needed in the returned data — it returns `%{genus: name, family: name}`. Keep the current query but resolve family by walking up from genus through intermediates. Use a CTE or subquery approach.

**Testing:**
- `get_taxonomy_for_species` for species under a genus with no intermediates — same as before
- `get_taxonomy_for_species` for species under genus → tribe → subfamily → family — returns all intermediates
- `get_genus_lineage` with intermediates in chain
- `get_section_lineage` with intermediates in chain
- `get_taxonomy_for_species_batch` resolves family correctly through intermediates

```elixir
# New helper in Lineage or Tree
def from_path(path_nodes) do
  family = Enum.find(path_nodes, &(&1.type == "family"))
  genus = Enum.find(path_nodes, &(&1.type == "genus"))
  intermediates =
    path_nodes
    |> Enum.filter(&(&1.type == "intermediate"))
    |> Enum.map(fn t -> %Intermediate{id: t.id, name: t.name, rank: t.rank, description: t.description} end)

  %Lineage{
    family: family && %Family{id: family.id, name: family.name, description: family.description},
    intermediates: intermediates,
    genus: genus && %Genus{id: genus.id, name: genus.name, description: genus.description}
  }
end
```

**Notes:** `get_taxonomy_path` already returns nodes ordered root-to-leaf with a recursive CTE, so the partitioning is straightforward. The batch query is the trickiest — for now, `get_taxonomy_for_species_batch` can use a CTE that walks from genus to root and picks the family type node. This changes the query from a single join to a CTE, but it's still one query.

The `list_genera_for_select/1` function in Tree also needs attention — it currently resolves `family_id` by checking if parent is section vs family. With intermediates, the parent could be an intermediate. Use `get_taxonomy_path` or a CTE subquery to find the ancestor family.

`list_gall_families_for_host/1` and `list_gall_families_for_host_genus/1` join `g.parent_id == f.id` assuming genus parent is always a family. These need the same CTE treatment to walk through intermediates. Similarly, `search_families` joins `g.parent_id == f.id` and `search_genera` joins `g.parent_id == f.id` for family resolution.

Depends on: Task 2.

### Task 4: Update Struct Literals and Fix Compile Errors

**Files:**
- Modify: `lib/gallformers_web/live/admin/reclassify_helpers.ex` (line ~25)
- Modify: `lib/gallformers/taxonomy/species_link.ex` (`resolve_disambiguation`, `extract_family_candidate`)
- Modify: `test/gallformers/taxonomy_test.exs`
- Modify: `test/gallformers/galls_test.exs`
- Modify: `test/gallformers/plants_test.exs`

**Behavior:**
Every place that constructs a `%Lineage{}` literal needs `intermediates: []` added. These are all "pass-through" — they don't need to populate intermediates because they're used in species creation/reclassification contexts where intermediates aren't relevant (species link to genus, not to intermediates).

`extract_family_candidate/1` in SpeciesLink builds a `family_candidate` map — this doesn't include intermediates and doesn't need to.

**Testing:**
- All existing tests pass with `intermediates` field present (even if nil/[])
- No compile warnings about missing struct keys

**Notes:** This is a mechanical task — grep for `%Lineage{` and add `intermediates: []` where missing. The struct default should be `[]` (not nil) so this only affects explicit literal construction. Set the struct default to `[]` in Task 2.

Depends on: Task 2.

### Task 5: Admin CRUD — Create Intermediate with Child Selection

**Files:**
- Modify: `lib/gallformers/taxonomy/tree.ex` (add `create_intermediate/1`)
- Modify: `lib/gallformers_web/live/admin/taxonomy_live/form.ex`
- Test: `test/gallformers/taxonomy_test.exs`
- Test: `test/gallformers_web/live/admin/taxonomy_live_test.exs`

**Behavior:**
New context function `create_intermediate(attrs)` that atomically: (1) creates the intermediate taxonomy node, (2) re-parents selected children under it. Takes `%{name, rank, parent_id, children_ids}`. Validates at least one child. Wraps in transaction.

Admin form changes:
- Type select adds `{"Intermediate", "intermediate"}` option
- When type is "intermediate", show:
  - Rank input (text field, placeholder "e.g. Subfamily, Tribe")
  - Parent picker: families + existing intermediates (not genera or sections)
  - Children picker: multi-select showing direct children of selected parent. Requires min 1 selection.
- Parent picker for "intermediate" type: `load_parent_options("intermediate")` returns families + intermediates
- When parent changes, children list refreshes to show that parent's direct children

The children picker should use the existing `multi_select` component or a checkbox list. Since we need to show all children of the selected parent and let the admin check which ones to move, a checkbox list in the form is simplest.

**Testing:**
- Create intermediate with one child — child re-parented
- Create intermediate with multiple children — all re-parented
- Create intermediate fails with zero children
- Create intermediate under a family
- Create intermediate under another intermediate (nested)
- Parent picker shows families and intermediates, not genera/sections

```elixir
def create_intermediate(attrs) do
  children_ids = attrs[:children_ids] || attrs["children_ids"] || []

  if children_ids == [] do
    {:error, :no_children_selected}
  else
    Repo.transaction(fn ->
      {:ok, intermediate} = create_taxonomy(Map.drop(attrs, [:children_ids, "children_ids"]))

      {count, _} =
        from(t in Taxonomy, where: t.id in ^children_ids)
        |> Repo.update_all(set: [parent_id: intermediate.id])

      if count == 0, do: Repo.rollback(:no_children_updated)
      intermediate
    end)
  end
end
```

**Notes:** The form needs a two-phase UX: (1) select parent → (2) see children and pick which to move. The children list loads via `get_children(parent_id)` and should exclude sections (only genera and intermediates can be children of an intermediate). The form should disable save until at least one child is checked.

Depends on: Task 1.

### Task 6: Admin — Delete Intermediate (Collapse Upward)

**Files:**
- Modify: `lib/gallformers/taxonomy/reclassification.ex` (`get_deletion_impact`, `delete_taxonomy_cascade`)
- Modify: `lib/gallformers_web/live/admin/taxonomy_live/form.ex` (delete confirmation message)
- Modify: `lib/gallformers_web/live/admin/taxonomy_live/index.ex` (delete from list)
- Test: `test/gallformers/taxonomy_test.exs`
- Test: `test/gallformers_web/live/admin/taxonomy_live_test.exs`

**Behavior:**
Deleting an intermediate collapses upward — all direct children re-parent to the intermediate's parent. This is NOT a cascade delete (no species are deleted). Add a new `get_deletion_impact` clause for type "intermediate" that returns the list of children that will be re-parented and the target parent. Add `delete_intermediate/1` that atomically re-parents children then deletes the node.

Impact message: "Delete intermediate 'Cynipinae' (Subfamily)? The following 3 children will be moved under Cynipidae: Cynipini, Aulacideini, Synergus."

**Testing:**
- Delete intermediate with one child — child re-parents to grandparent
- Delete intermediate with multiple children — all re-parent
- Delete nested intermediate — children move up one level
- Impact report shows correct children and target parent
- Confirmation modal matches existing UX (name-type-to-confirm)

**Notes:** This is fundamentally different from family/genus cascade delete. No species are harmed. The `delete_taxonomy_cascade` function needs a new clause for "intermediate" type that does re-parenting instead of cascading. The confirmation modal text should reflect the re-parenting, not deletion of children.

Depends on: Task 5.

### Task 7: Admin Index — Filter and Display Intermediates

**Files:**
- Modify: `lib/gallformers_web/live/admin/taxonomy_live/index.ex`
- Modify: `lib/gallformers_web/live/admin/taxonomy_live/form.ex` (type badge, parent display)
- Test: `test/gallformers_web/live/admin/taxonomy_live_test.exs`

**Behavior:**
Index page type filter dropdown adds `{"Intermediates", "intermediate"}`. The `type_badge` function adds a color for intermediates (e.g., amber/orange to distinguish from family=blue, genus=green, section=purple). Intermediate rows show the rank label in the description column or as a sub-badge. The public URL helper `taxonomy_public_url` adds a clause for intermediates pointing to the new browse page.

Genus creation form: `load_parent_options("genus")` changes to return families AND intermediates (since a genus can now parent to an intermediate). The parent picker prompt updates accordingly.

**Testing:**
- Filter by "intermediate" type shows only intermediates
- Intermediate rows display with correct badge color
- Intermediate rank label visible in the table
- Genus parent picker includes intermediates

**Notes:** The `list_taxonomies_with_parent_paginated` query already returns all types, so no query change needed for the index. Just UI adjustments.

Depends on: Task 5.

### Task 8: Taxonomy Breadcrumb Component with Intermediates

**Files:**
- Modify: `lib/gallformers_web/components/data_display_components.ex` (`taxonomy_breadcrumb`)
- Test: `test/gallformers_web/components/data_display_components_test.exs`

**Behavior:**
Update `taxonomy_breadcrumb` to accept an `intermediates` attr (list of maps with `:id`, `:name`, `:rank`). Render them between family and genus, each as a clickable link to `/taxonomy/:id`. Use the `|` separator between each level. When `intermediates` is empty or nil, behavior is identical to current.

```heex
<span :for={intermediate <- @intermediates || []} class="flex items-center gap-1">
  <span class="mx-1 text-gray-400">|</span>
  <strong>{intermediate.rank}:</strong>
  <.link navigate={"/taxonomy/#{intermediate.id}"} class="hover:underline">
    {intermediate.name}
  </.link>
</span>
```

**Testing:**
- Breadcrumb with no intermediates — renders family | genus (existing behavior)
- Breadcrumb with one intermediate — renders family | subfamily | genus
- Breadcrumb with two intermediates — renders family | subfamily | tribe | genus
- Links point to correct URLs

**Notes:** This component is currently unused in production. Wiring it into species pages happens in Task 10.

Depends on: Task 3 (needs intermediate data flowing through Lineage).

### Task 9: Public Intermediate Browse Page

**Files:**
- Create: `lib/gallformers_web/live/intermediate_live.ex`
- Modify: `lib/gallformers_web/router.ex` (add route)
- Modify: `lib/gallformers/taxonomy/tree.ex` (add `list_children_with_counts/1`)
- Test: `test/gallformers_web/live/intermediate_live_test.exs`

**Behavior:**
New LiveView at `/taxonomy/:id` that displays an intermediate taxonomy node. Shows:
- Page title: "Tribe: Aulacideini" (rank: name)
- Full parent chain as breadcrumb (using `taxonomy_breadcrumb` component via `get_taxonomy_path`)
- List of direct children with species counts. Children can be genera or nested intermediates.
  - Genera link to `/genus/:id`
  - Intermediates link to `/taxonomy/:id`
  - Show species count per child (for genera, count via `species_taxonomy`; for intermediates, count recursively or show direct child count)

New context function `list_children_with_counts(taxonomy_id)` — returns direct children with species counts. For genus children, count via `species_taxonomy` join. For intermediate children, count all species in their subtree (use recursive CTE or just show direct genera count for simplicity).

Route: `live "/taxonomy/:id", IntermediateLive` in the public scope.

**Testing:**
- Page renders for a valid intermediate with children
- Breadcrumb shows full path
- Children list shows genera with species counts
- Children list shows nested intermediates
- 404 for non-existent ID
- 404 for non-intermediate taxonomy (family/genus/section have their own pages)

**Notes:** Consider whether to validate that the taxonomy is actually type "intermediate" — family, genus, and section already have their own pages. If someone navigates to `/taxonomy/:id` with a genus ID, redirect or 404.

Depends on: Task 8.

### Task 10: Wire Breadcrumbs into Species and Genus Pages

**Files:**
- Modify: `lib/gallformers_web/live/gall_live.ex` (~lines 430-463)
- Modify: `lib/gallformers_web/live/host_live.ex` (~lines 361-408)
- Modify: `lib/gallformers_web/live/genus_live.ex` (~lines 180-203)
- Modify: `lib/gallformers_web/live/section_live.ex` (~lines 152-182)
- Test: existing LiveView tests should cover rendering

**Behavior:**
Replace the inline taxonomy rendering in each page with the `taxonomy_breadcrumb` component. Pass `intermediates` from `@taxonomy.intermediates` (or `@lineage.intermediates`).

For gall_live and host_live: the `@taxonomy` assign is a `Lineage` — pass `family`, `intermediates`, `genus` to the breadcrumb component.

For genus_live: the `@lineage` assign is a `Lineage` — render breadcrumb with family + intermediates (no genus link since we're on the genus page).

For section_live: similar to genus_live but includes section in the display.

**Testing:**
- Gall page renders intermediates in taxonomy section when present
- Host page renders intermediates
- Genus page shows intermediates in breadcrumb
- Pages with no intermediates render identically to before

**Notes:** This is mostly template changes — replacing inline HEEx with component calls. The data is already flowing through Lineage from Task 3.

Depends on: Tasks 3, 8.

### Task 11: Search Integration

**Files:**
- Modify: `lib/gallformers/taxonomy/search.ex` (`search_genera_and_sections`, `search_taxonomies`)
- Test: `test/gallformers/taxonomy_test.exs`

**Behavior:**
`search_genera_and_sections` — rename or extend to include intermediates. Currently filters `t.type in ["genus", "section"]`. Add `"intermediate"` to the list. Return the `rank` field in the select map so the UI can display "Aulacideini (Tribe)".

`search_taxonomies` — already searches all types, no change needed.

The public typeahead (used in the ID tool and search bar) should include intermediates in results. When selected, navigate to `/taxonomy/:id`.

**Testing:**
- Search for "Aulac" returns intermediate "Aulacideini" with rank "Tribe"
- Search results include type/rank information for display
- Intermediates appear alongside genera and sections in typeahead

**Notes:** The search functions need the `rank` field in their select. Add it — it's null for non-intermediates, so existing callers are unaffected.

Depends on: Task 1.

### Task 12: Family Browse Page — Mixed Children

**Files:**
- Modify: `lib/gallformers_web/live/family_live.ex`
- Modify: `lib/gallformers/taxonomy/tree.ex` (if needed for query)
- Test: `test/gallformers_web/live/family_live_test.exs`

**Behavior:**
The family browse page currently lists genera. With intermediates, it should show a mix of top-level intermediates and genera that are direct children of the family (genera not yet assigned to an intermediate).

Group the children: intermediates first (with their rank label), then genera. Each intermediate shows its children count. Genera show species count as before.

**Testing:**
- Family with no intermediates — renders exactly as before
- Family with intermediates — shows intermediates and direct genera
- Intermediate entries link to `/taxonomy/:id`

**Notes:** `get_children(family_id)` already returns all direct children regardless of type. The rendering just needs to handle the mix.

Depends on: Tasks 3, 9.

## Implementation Review Notes

### Task 3 blast radius is larger than documented

The plan lists `get_taxonomy_for_species`, `get_taxonomy_for_species_batch`, `list_genera_for_select`, and `list_gall_families_for_host/genus` as needing query changes. But several more functions also assume `genus.parent_id == family.id`:

- `search_families/2` (taxoncode filter branch) — joins `g.parent_id == f.id` to find genera under a family
- `search_genera/3` — joins `g.parent_id == f.id` to resolve `family_name` and `family_id`
- `get_species_ids_for_family/1` — joins `g.parent_id == ^family_id`, which would miss genera nested under intermediates

These won't break immediately (no intermediates exist yet), but will silently return wrong results once someone creates an intermediate and moves genera under it.

### from_genus must stay a pure constructor

The plan suggests changing `from_genus/1` to call `get_taxonomy_path` (a DB query). Currently `from_genus` is a pure data transform — it takes a TaxonomySchema with preloaded parent and builds a Lineage. Making it do I/O changes its contract. Better approach: add a new `from_path/1` constructor and have callers that need intermediates use `get_taxonomy_path` + `from_path`. Keep `from_genus` backward-compatible for contexts where intermediates aren't needed.

### Skip structure.sql update

Task 1 lists `priv/repo/structure.sql` as a file to modify. Per project conventions, `structure.sql` was a one-time V1 bootstrap and is not the source of truth. All schema changes go through Ecto migrations only.
