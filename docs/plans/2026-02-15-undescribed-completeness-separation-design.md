# Design: Separate "Undescribed" from "Incomplete"

## Status

- **Design**: Approved
- **Data audit**: Complete — see [triage doc](Triaging%20the%20state%20of%20Gall%20species%20data.md)
- **Awaiting reviewer feedback** on 3 action items by Tuesday 2026-02-18
- **Code tasks 2-9** can proceed independently of the data review
- **Data migration (task 10)** blocked until reviewer feedback is resolved

## Problem

The codebase conflates two distinct concepts:

1. **Undescribed** — the taxon is genuinely undescribed or unknown in the scientific literature
2. **Incomplete** — the Gallformers entry is missing information (e.g., a source)

The current code forces `undescribed=true` when a gall has no sources. This is incorrect: a gall can be formally described in the literature but simply missing its source in our database. The "undescribed" flag should only reflect taxonomic status.

Additionally, the "gallformers code" (used to link to iNaturalist observations) is derived from the species name's specific epithet and preserved across reclassification via a `former_undescribed` alias type. This is fragile — it couples naming conventions to data linkage and requires complex alias rotation logic. The data audit revealed hundreds of inconsistencies caused by this approach.

## Design

### 1. Undescribed Lock: Remove Source Requirement

`Galls.compute_undescribed_lock/2` currently locks undescribed to `true` for two reasons:
- Placeholder genus ("Unknown (Family)") — **keep this**
- No sources linked — **remove this**

After the change, undescribed is locked only by genus membership. Admins can freely toggle undescribed for any gall with a real genus, regardless of source status.

### 2. Data Complete Lock: Add Source and Undescribed Gates

New function `Galls.compute_datacomplete_lock/1` blocks `datacomplete=true` when:
- The species has no sources linked, OR
- The gall is marked undescribed (an undescribed species by definition has incomplete data)

Mirrors the undescribed lock pattern:
- Returns `{locked?, reason}` tuple
- Only applies to galls (host datacomplete has different semantics and no automatic gate)
- For new galls (nil species_id), returns unlocked

### 3. Gall Admin Form Changes

**Datacomplete checkbox**: Gets the same lock treatment as undescribed — disabled when locked, amber reason text below explaining why. New assigns: `datacomplete_locked`, `datacomplete_lock_reason`. New helper: `apply_datacomplete_lock/2`, called everywhere `apply_undescribed_lock` is called.

When locked, `datacomplete` is forced to `false` before save.

**Gallformers code field**: New editable text input on the gall form. Displayed near the undescribed checkbox.

### 4. Gallformers Code: Promote to Data Field

**New field**: `gallformers_code` (string, nullable, unique) on `gall_traits`.

**Replaces**:
- Deriving the code from the specific epithet of the species name
- The `former_undescribed` alias type and all management code
- The `compute_gallformers_code/3` function in `gall_live.ex`

**Uniqueness**: Enforced via unique index (partial — only when non-null) and changeset validation. Collision check in admin form.

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

### 6. Data Migration

**Blocked on reviewer feedback (due Tuesday 2026-02-18).** See [triage doc](Triaging%20the%20state%20of%20Gall%20species%20data.md) for full audit results and the three action items requiring human decisions.

#### Migration rules (automated, after action items resolved)

1. **Populate gallformers_code**: Set `gallformers_code` = epithet for galls with 1+ dashes in epithet, excluding 23 legitimate described species with hyphenated epithets (listed in triage doc)
2. **Populate from former_undescribed aliases**: Extract epithet from any `former_undescribed` alias (none exist today; handled defensively)
3. **Fix undescribed flags**:
   - ID 2235 → set undescribed = true
   - All undescribed galls with real genus AND no dashes in epithet → set undescribed = false (except ID 1115, manual fix)
   - All galls under Unknown genera → ensure undescribed = true
4. **Fix datacomplete**: Set `datacomplete=false` on all galls without sources AND all undescribed galls
5. **Add unique index** on `gall_traits.gallformers_code` (partial, non-null only)
6. **Clean up aliases**: Convert any `former_undescribed` aliases to `scientific` type

#### Items requiring human resolution before migration

- **ID 1115**: Needs proper constructed name (current: `Unknown (Cynipidae) dentatae`)
- **IDs 4081/4082**: Duplicate gallformers code `r-carolina-folded-terminal-leaflet` — merge or disambiguate
- **IDs 2747/5443**: Duplicate gallformers code `c-americana-enlarged-bud-gall` — merge or disambiguate

### 7. Test Changes

**Update existing tests**:
- `compute_undescribed_lock` tests — remove "no sources → locked" case
- Reclassification tests — remove `former_undescribed` alias expectations
- Any test relying on sourceless galls being forced undescribed

**New tests**:
- `compute_datacomplete_lock/1` — locked when no sources, locked when undescribed, unlocked otherwise, nil returns unlocked
- Admin form: datacomplete checkbox disabled when locked, reason text displayed
- Admin form: gallformers_code field editable, persisted, unique constraint
- Undescribed creation flow: gallformers_code pre-populated from epithet
- Public gall page: display logic for code + undescribed, code + described, no code

**Prod data invariant tests**:
- Add: no gall with `datacomplete=true` lacks sources
- Add: no undescribed gall has `datacomplete=true`
- Add: no duplicate `gallformers_code` values
- Remove: invariant that assumes sourceless galls are undescribed

## Out of Scope

- Host form datacomplete changes (no lock needed)
- Public-facing badge changes (already works with existing boolean)
- API field changes (fields stay the same, semantics tighten)
- Additional datacomplete gates beyond sources and undescribed
- Changes to placeholder genus logic
- TaxonName parsing module (still useful for other purposes)

## Interaction Matrix

A gall can be in these combinations (undescribed + datacomplete is now impossible):

| Undescribed | Data Complete | Gallformers Code | Display |
|-------------|---------------|------------------|---------|
| Yes | No | Present | Undescribed blurb + iNat link |
| Yes | No | None | No special display |
| No | Yes | Present | "Formerly undescribed" + iNat link |
| No | Yes | None | No special display |
| No | No | Present | "Formerly undescribed" + iNat link |
| No | No | None | No special display |
