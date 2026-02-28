---
status: raw
effort: 5-7 days
created: 2026-02-16
updated: 2026-02-28
epic: taxonomy
relates: [5b3d, ede2, cdfd]
blocks: [f49a]
needs: [5b3d]
---

# Species merge and split operations

Taxonomic merges (synonymization) and splits are frequent operations that need to be easy and safe. Primarily about galls but should not exclude plants. Key challenge: handling all the associated data (traits, hosts, images, sources, aliases) correctly during these operations.

## Merge (Synonymization)

Merge is NOT a destructive data-union operation. It's aliasing + redirect. So merging B -> A:

- B stays in the database — its record, traits, hosts, images, everything stays intact
- B becomes read-only (frozen) — no more edits allowed
- B's name becomes a scientific synonym alias on A
- B redirects to A — public page for B shows synonymization notice or redirects to A
- B's gallformers_code stays on B — iNat links keep working because B still resolves to A
- Search for B finds A — FTS and typeahead resolve through the redirect
- Admin can optionally copy specific values from B → A as part of the merge workflow (details TBD)

Data model changes:
- `merged_into_id` (FK to species, nullable) — 'this species is now considered a synonym of X'
- Read-only status implied by merged_into_id being non-null
- Display/routing layer handles the redirect
- Admin layer blocks edits on merged species
- Need to think about how to handle in API

## Split (Clone + Diverge)

Split is a clone operation followed by manual cleanup:

- Admin presses Split on species A
- All details of A are copied into new species B (traits, hosts, images, sources, etc.)
- Admin renames B to something unique
- A new alias is added to B pointing back to A (its former name)
- Admin then edits both A and B to trim/adjust what doesn't apply to each

This avoids needing a complex allocation wizard — just clone and diverge.

## Data Surface

All FKs pointing at species.id that merge/split must account for:
- gall_traits (1:1, includes gallformers_code, undescribed, detachable)
- 9 M:M trait tables (gall_color, gall_walls, gall_cells, gall_shape, gall_texture, gall_alignment, gall_plant_part, gall_form, gall_season)
- gallhost (gall-host relationships)
- image (photos)
- species_source (citations)
- alias_species (alternative names)
- species_taxonomy (family/genus/section links)
- host_range (plant geographic range)
- gall_range_exclusion (gall range exclusions)
- abundance (species-level field)

## Applies to both galls and plants

## Design Decisions (2026-02-16)

### Chained merges
Must handle redirect chains (B → A → C). When A merges into C, update B to point directly to C — no chains.

### Unmerge
Taxonomic reversals happen. Design for unmerge from the start — unfreeze B, remove redirect. Non-destructive model makes this viable since B's data is preserved.

### Display: A shows A's data only
A's page shows A's own data. B is NOT unioned into A at query time. Instead, A should have a taxonomic history section that shows 'B was synonymized into this species' with a link to B (not just an alias entry). This implies tracking merges and splits more formally — likely a separate table (e.g., species_history or taxonomic_events) rather than just merged_into_id + aliases.

### Split: S3 images
Copy the S3 files during split so each species owns its images independently. Admin can then delete irrelevant ones from either side. Likely present this as an option during the split workflow.

### Split: unique constraints
Copy values as-is during clone, then alert the admin that gallformers_code and name must be changed to be unique before saving. Validation prevents saving until resolved.

### Host-side merges
Host plant merges are a bigger deal — every gall referencing host B needs consideration. Will likely need a more sophisticated merge process for hosts that surfaces the affected galls and lets the admin decide how to handle each relationship.

### Formal history tracking
Merges and splits should be recorded in a dedicated table (not just aliases), capturing: event type (merge/split), source species, target species, admin who performed it, timestamp, notes. This feeds the taxonomic history section on species pages.

## Prompt For Adam

You are a Product Manager for Gallformers, an online database of plant galls. You're interviewing a domain expert (a biologist/naturalist who cofounded the site) about a proposed feature for merging and splitting species records.

You have been given a design document that describes the high-level approach. Your job is to:

1. Understand how this works in real taxonomy — Ask about real-world examples of species merges (synonymizations) and splits. What triggers them? How often do they happen? Are there patterns (e.g., molecular work splitting old morphological
species)?
2. Stress-test the merge model — The proposal says "freeze B, redirect to A, keep B's data intact." Ask whether this matches how taxonomists think about synonymy. Are there cases where it's not clear which species is A (the keeper) vs B (the
synonym)? What about cases where both names have equal standing and a third name is chosen?
3. Stress-test the split model — The proposal says "clone A into B, then the admin trims both." Ask whether this matches how splits actually work in practice. When a species is split, is it usually obvious which specimens/observations belong
to which resulting species? Or is it ambiguous?
4. Probe the host plant side — When a host plant gets merged or split, every gall associated with it is affected. Ask about how common host plant taxonomic changes are compared to gall taxonomic changes, and what the practical impact is.
5. Find what's missing — Are there taxonomic operations beyond merge and split that we're not thinking about? What about rank changes (species promoted to genus, subspecies promoted to species)? What about uncertain synonymies where
taxonomists disagree?
6. Think about the iNaturalist connection — Gallformers codes are used on iNaturalist observations. When species get merged or split, what happens on the iNat side? Does Adam have to update observations there too? How does that workflow
interact with what we're building?

Keep your questions conversational and non-technical. You're not asking about databases or code — you're asking about how taxonomy works and whether this design will hold up against real-world scenarios. If Adam describes a scenario that seems
  like it would break the proposed design, dig into it.

At the end of the conversation, summarize:
- Scenarios that the current design handles well
- Scenarios that reveal gaps or need more thought
- Any new operations or concepts that should be added to the design
