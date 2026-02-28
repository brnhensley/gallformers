---
status: raw
created: 2026-02-28
updated: 2026-02-28
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

