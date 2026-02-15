# Design: Separate "Undescribed" from "Incomplete"

## Problem

The codebase conflates two distinct concepts:

1. **Undescribed** — the taxon is genuinely undescribed or unknown in the scientific literature
2. **Incomplete** — the Gallformers entry is missing information (e.g., a source)

The current code forces `undescribed=true` when a gall has no sources. This is incorrect: a gall can be formally described in the literature but simply missing its source in our database. The "undescribed" flag should only reflect taxonomic status.

Additionally, the "gallformers code" (used to link to iNaturalist observations) is derived from the species name's specific epithet and preserved across reclassification via a `former_undescribed` alias type. This is fragile — it couples naming conventions to data linkage and requires complex alias rotation logic.

## Design

### 1. Undescribed Lock: Remove Source Requirement

`Galls.compute_undescribed_lock/2` currently locks undescribed to `true` for two reasons:
- Placeholder genus ("Unknown (Family)") — **keep this**
- No sources linked — **remove this**

After the change, undescribed is locked only by genus membership. Admins can freely toggle undescribed for any gall with a real genus, regardless of source status.

### 2. Data Complete Lock: Add Source Gate

New function `Galls.compute_datacomplete_lock/1` blocks `datacomplete=true` when a gall has no sources. Mirrors the undescribed lock pattern:

- Returns `{locked?, reason}` tuple
- Reason text: "A source is required to mark a gall as data complete."
- Only applies to galls (host datacomplete has different semantics and no automatic gate)
- For new galls (nil species_id), returns unlocked

### 3. Gall Admin Form Changes

**Datacomplete checkbox**: Gets the same lock treatment as undescribed — disabled when locked, amber reason text below explaining why. New assigns: `datacomplete_locked`, `datacomplete_lock_reason`. New helper: `apply_datacomplete_lock/2`, called everywhere `apply_undescribed_lock` is called.

When locked, `datacomplete` is forced to `false` before save.

**Gallformers code field**: New editable text input on the gall form. Displayed near the undescribed checkbox.

### 4. Gallformers Code: Promote to Data Field

**New field**: `gallformers_code` (string, nullable) on `gall_traits`.

**Replaces**:
- Deriving the code from the specific epithet of the species name
- The `former_undescribed` alias type and all management code
- The `compute_gallformers_code/3` function in `gall_live.ex`

**Public display logic** (unchanged UX, simplified implementation):
- `gallformers_code` present + undescribed → "undescribed" blurb with code, copy button, iNat link
- `gallformers_code` present + described → "formerly undescribed" blurb with iNat link
- No `gallformers_code` → nothing displayed

**Undescribed creation flow**: Pre-populates `gallformers_code` from the specific epithet of the generated name. The field is editable — the admin can change it.

### 5. Code Removal

The following are eliminated by the gallformers code field:

- `former_undescribed` alias type (from `Alias` schema valid types)
- `Species.has_former_undescribed_alias?/1`
- `Species.rotate_former_undescribed_alias/1`
- `former_undescribed_choice` parameter and `resolve_alias_opts` branches in `Reclassification`
- `maybe_rotate_former_undescribed/2` in `Reclassification`
- `resolve_reclassify_alias_type/2` former_undescribed clause
- `compute_gallformers_code/3` in `gall_live.ex`
- Alias filtering for `former_undescribed` in `gall_live.ex`
- `former_undescribed` handling in `reclassify_live.ex` and `form_components.ex`
- Migration `20260209224658_add_former_undescribed_alias_type.exs` (already run; new migration cleans up the type)

### 6. Data Migration

**Gated on diagnostic queries reviewed by the user.** No migration runs until diagnostics are reviewed and approved.

#### Diagnostics (run first, review results)

1. Count of undescribed galls with real genera (the mislabeled ones)
2. Of those, how many have sources vs don't
3. Count of galls marked datacomplete but lacking sources
4. Current `former_undescribed` aliases and their species

#### Migration operations (after approval)

1. **Add column**: `gallformers_code` to `gall_traits`
2. **Populate gallformers_code**: From `former_undescribed` alias epithet if one exists, else from current species name epithet for undescribed galls
3. **Fix undescribed flags**: Set `undescribed=0` on galls with real genera (not "Unknown%"), regardless of source status
4. **Fix datacomplete**: Set `datacomplete=0` on galls that are currently complete but lack sources
5. **Clean up aliases**: Convert `former_undescribed` aliases to `scientific` type (or delete if redundant)
6. **Remove alias type**: Drop `former_undescribed` from valid alias types

### 7. Test Changes

**Update existing tests**:
- `compute_undescribed_lock` tests — remove "no sources → locked" case
- Reclassification tests — remove `former_undescribed` alias expectations
- Any test relying on sourceless galls being forced undescribed

**New tests**:
- `compute_datacomplete_lock/1` — locked when no sources, unlocked when sources exist, nil returns unlocked
- Admin form: datacomplete checkbox disabled when locked, reason text displayed
- Admin form: gallformers_code field editable, persisted
- Undescribed creation flow: gallformers_code pre-populated from epithet
- Public gall page: display logic for code + undescribed, code + described, no code

**Prod data invariant tests**:
- Add: no gall with `datacomplete=true` lacks sources
- Remove: invariant that assumes sourceless galls are undescribed

## Out of Scope

- Host form datacomplete changes (no lock needed)
- Public-facing badge changes (already works with existing boolean)
- API field changes (fields stay the same, semantics tighten)
- Additional datacomplete gates beyond sources
- Changes to placeholder genus logic
- TaxonName parsing module (still useful for other purposes)

## Interaction Matrix

A gall can be in any combination:

| Undescribed | Data Complete | Gallformers Code | Display |
|-------------|---------------|------------------|---------|
| Yes | Yes | Present | Undescribed blurb + iNat link |
| Yes | No | Present | Undescribed blurb + iNat link |
| No | Yes | Present | "Formerly undescribed" + iNat link |
| No | No | Present | "Formerly undescribed" + iNat link |
| Yes | Yes | None | No special display |
| Yes | No | None | No special display |
| No | Yes | None | No special display |
| No | No | None | No special display |
