---
status: raw
created: 2026-03-03
updated: 2026-04-05
epic: cynipid
relates: [0f79, 67c9]
needs: [600a]
---

# Genus-level host associations

## Problem

When literature identifies a host plant only to genus level, admins create placeholder species like "[Genus] spp." There's no enforcement of this convention, no way for the system to know these are placeholders, and no guardrails around genus-level vs species-level associations.

## Spec

### Semantics

A genus-level placeholder host means "this gall is known to occur on additional unidentified members of this genus." It is an additive assertion, not a temporary state of knowledge — it can coexist with species-level host associations for the same genus on the same gall.

### Rules

1. A host species can be flagged as a genus-level placeholder (a column, not parsed from the name)
2. Naming is system-enforced: "[Genus] spp" — no freeform variants
3. One placeholder per genus maximum
4. Both genus-level and species-level host associations for the same genus on the same gall are allowed — they represent different claims ("known on S. otites" + "known on at least one other unidentified Senecio")
5. These constraints are per-genus, per-gall — other genera on the same gall are unaffected

### Range

- Genus-level placeholder hosts have no WCVP range data and contribute nothing to the auto-computed host union
- Gall range is independent of host range. The union of hosts' native ranges is the **default starting point**, not the authority — admins can freely add or remove any region. (Broader change — depends on 600a resolving the authority question.)
- ID and Search serve fundamentally different needs — ID is a precision filter, Search is inclusive discovery

### ID screen behavior

The ID screen has two levels of host filtering with different range rules:

- **Species filter** (specific species, e.g. "Senecio otites"): precision tool. Only species-level host matches. Genus-level placeholders do NOT surface. Galls with no range are excluded (current INNER JOIN behavior, unchanged).
- **Genus/Section filter** (e.g. "Senecio"): exploration tool. Shows all galls with any host in that genus, whether species-level or genus-level. Galls with no range ARE included (like Search) — because the user is already casting a wider net. A "Range Unknown" badge signals when a result matched via genus-level association without range.
- **Search page**: galls with no range appear in all regions (current behavior, unchanged).

Implementation: when genus filter is active and region filter is set, use LEFT JOIN on gall_range so NULL range rows pass through. Species filter keeps the current INNER JOIN.

### User-facing display

- Genus-level placeholder hosts are visually distinguished wherever they appear (search, gall detail, host detail) to communicate "host known to genus only"
- "Range Unknown" badge on ID results that matched via genus-level association without range data

### Data cleanup

- Audit existing placeholder records, standardize naming to the enforced "[Genus] spp" convention, and set the placeholder flag

## Decisions

- **No family-level host associations.** The Genus/Section filter and the family browse feature (67c9) cover that need through filtering, not data entry.
- **No admin nudge to remove genus placeholder.** Having N species cataloged in a genus says nothing about whether unidentified hosts remain. The placeholder is a positive assertion, not a gap.
- **Gall range independent of host range.** Broader than this matter — depends on 600a resolving its "authority" design decision. The 600a diff/review workflow remains useful as a tool regardless.

## What's NOT in scope

- New data model / junction table for genus-level associations — the current species-as-placeholder approach works
- Range inheritance for genus-level placeholders — they contribute nothing to range


## Open questions discussion

### Q1: How should galls with genus-level hosts (and no range) behave on the ID screen?

**How Search works today:** The Search page includes galls with no range in all regions. If a gall has no range data, it shows up regardless of what region the user selected. This is inclusive by design — Search is for discovery.

**How ID works today:** The ID screen excludes galls with no range when a region filter is active. ID is a precision filter — if you set a region, you only get galls documented in that region.

**The question:** Genus-level placeholder hosts, generally, have no range data. How should the ID screen handle galls whose only host match is a genus-level placeholder with no range? The ID screen has two host filter modes, and each creates a different scenario:

**Scenario 1: Species filter** (user searches for a specific species, e.g. "Senecio otites")

Genus-level placeholders ("Senecio spp") should NOT match a specific species search — this seems clear. The placeholder is not a claim about any particular species. No range question arises because the gall doesn't match in the first place.

**Scenario 2: Genus/Section filter** (user filters by genus, e.g. "Senecio")

This is the real question. The user is explicitly exploring at genus level. A gall with "Senecio spp" as its only host is a legitimate match for the genus filter — but it likely has no range. Three options:

**Option A: Include them (bypass region filter, show indicator)**
- Pro: The user chose to filter by genus, signaling they want broad results. Hiding rangeless galls defeats the purpose of genus-level associations.
- Pro: Closer to Search behavior for genus-level filtering. Users don't have to learn a different mental model.
- Con: If the region filter is set to "North America" and a Patagonian gall shows up, that could be confusing even with an indicator.
- Con: As more genus-level associations are added, this could increase noise in region-filtered results.

**Option B: Exclude them (current behavior — no range, no result)**
- Pro: Region filter means what it says. No surprises.
- Pro: Creates strong pressure for admins to set range on genus-level galls.
- Con: Genus-level associations become invisible on ID until someone manually sets range. Admins may not know these galls exist to set range on.
- Con: Undermines the value of genus-level associations — they only help on Search, not the primary ID tool.

**Option C: Show them in a separate section below main results**
- Pro: Clear separation — "these matched your genus but have no range data."
- Con: More UI complexity. May not be worth it for what could be a small number of results.

### Q2: Should gall range be fully independent of host range?

**Context:** The system has evolved through three models:
1. **Original:** Gall range = union of host ranges, with exclusions allowed
2. **Current:** Gall range = union of host ranges, with overrides within that union
3. **Proposed:** Gall range = independent. Host union is the default starting point, admin can freely set any region.

The genus-level host work motivates this because genus-level placeholders generally have no range, so the auto-computed union is incomplete by definition.

**Implications of full independence:**
- The "Refresh from hosts" workflow (600a) becomes advisory — a tool to see what hosts suggest, not an authority that constrains
- "Orphaned" places (in gall range but not in any host range) become a normal state, not an anomaly to resolve
- Bulk recompute needs very clear confirmation: "This will REPLACE your manually-set ranges with the host union"
- Admin has more power but also more responsibility — range correctness depends on admin discipline, not system guardrails
- The host-union diff UI is still valuable as a starting point and audit tool

**Implications of staying with current model (host union as ceiling):**
- Simpler mental model: gall range can never exceed host range
- But genus-level galls generally can't get range at all through the automatic path (generally no range data for placeholders)
- Admins would need a separate mechanism to set range for genus-level-only galls, which is effectively "independence" for a subset
- Risk of ending up with two range-setting paths that are hard to explain

**Middle ground: host union as default, expandable with explicit override**
- Default behavior unchanged — gall range starts as host union
- Admin can "unlock" a gall's range to add regions beyond the host union
- Makes the intent explicit: "I know this gall occurs here even though no host range data supports it"
- More complexity in the UI but clearer audit trail

### Q3: When both genus-level and species-level hosts exist for the same genus on a gall, does the genus-level placeholder still mean something?

**Context:** Under the proposed rules, a gall could have both "Senecio otites" (species-level) and "Senecio spp" (genus-level) as hosts. The intended meaning is "known on S. otites AND on at least one other unidentified Senecio."

**Case for yes (placeholder is a positive assertion):**
- The placeholder records a real observation: the literature/field data says this morphotype was found on an unidentified member of the genus
- Having 2 of 200 Senecio species in the DB doesn't mean the placeholder is stale — there are almost certainly more hosts
- Removing the placeholder loses information ("we saw this on an unidentified Senecio on the mainland")
- No admin nudge needed — the placeholder stays until someone has a reason to remove it

**Case for caution:**
- Over time, placeholders could accumulate without anyone revisiting whether they're still meaningful
- If an admin identifies the specific species that the placeholder was created for (the mainland Senecio turns out to be S. otites too), the placeholder should be removed — but nobody may remember to do that
- Without tracking WHY the placeholder exists (which source/observation), it's hard to know when it's been superseded
- Could the source field on the gall-host association carry this context? Or is that overengineering?

### Q4: Is the "Range Unknown" badge on ID results useful or just noise?

**Context:** If Q1 is resolved as "include genus-level matches without range," those results need some visual signal explaining why they appeared despite not matching the region filter.

**Case for the badge:**
- Without it, users may be confused about why a result appeared when their region filter should have excluded it
- Communicates data quality — "we know this gall exists on this genus, but we don't know where"
- Helps admins identify galls that need range data set

**Case against:**
- If there are only a few genus-level results mixed in, the badge is fine. If there are many, it becomes visual clutter.
- "Range Unknown" might be misread as "this gall has no range at all" rather than "the range isn't set for this particular host association path"
- A gall might have range from other hosts but match the genus filter via a rangeless genus-level placeholder — "Range Unknown" would be misleading in that case

**Alternative approaches:**
- Group rangeless genus-level matches separately (see Q1 Option C)
- Use a subtler indicator (icon, not a badge) that's visible but not prominent
- Only show the badge when the result would NOT have appeared without the genus-level association — i.e., if the gall also matched via a species-level host with range, no badge needed
- Tooltip on hover rather than always-visible badge

**Dependency:** This question is moot if Q1 resolves as "exclude them" (Option B).
