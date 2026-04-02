---
status: raw
created: 2026-03-03
updated: 2026-04-02
epic: cynipid
relates: [0f79, 67c9]
---

# Genus-level host associations

## Problem

When literature identifies a host plant only to genus level, admins create placeholder species like "[Genus] spp." There's no enforcement of this convention, no way for the system to know these are placeholders, and no guardrails around mixing genus-level and species-level associations for the same genus on the same gall.

## Discovery (2026-04-02)

Interviewed the primary user/admin. Key findings:

- The fake species workaround ("Sanicula spp") is structurally adequate for data entry — no new data model needed
- The discovery/search gap is largely addressed by the existing Genus/Section filter on the ID screen, plus the recent change showing galls with no range regardless of region filter
- The real pain is **inconsistency and lack of formalization** of the placeholder pattern
- Genus-level associations are **temporary states of knowledge** — they get replaced when a specific host species is identified
- The Unknown gall pattern is NOT analogous: Unknown galls are single unidentified organisms awaiting description; genus-level hosts are a permanent record of imprecise source data that gets superseded, not resolved

## Spec

### Rules

1. A host species can be flagged as a genus-level placeholder (a column, not parsed from the name)
2. Naming is system-enforced: "[Genus] spp" — no freeform variants
3. One placeholder per genus maximum
4. A gall's host associations within a given genus are either genus-level OR species-level, never both
5. Transitions in either direction are allowed but require explicit confirmation with clear explanation of what will be added/removed
6. These constraints are per-genus, per-gall — other genera on the same gall are unaffected

### Transition confirmations

- **Upgrading precision (spp → species):** Confirm that the genus placeholder will be removed and replaced with the specific species
- **Downgrading precision (species → spp):** Confirm that all specific species associations within that genus will be removed and replaced with the genus placeholder. This is the dangerous direction — potentially losing multiple specific associations.

### User-facing display

- Genus-level placeholder hosts are visually distinguished wherever they appear (search, gall detail, host detail) to communicate "host known to genus only"

### ID screen region filtering

- Galls whose match is via a genus-level placeholder host bypass the region filter entirely (same pattern as the Search page, which already includes regionless results)
- A "Range Unknown" badge appears on the result card — but only when the genus-level association is the reason the gall matched. If the gall also matched on a species-level host with known range, no badge.

### Data cleanup

- Audit existing placeholder records, standardize naming to the enforced convention, and flag them
- Identify galls that violate rule #4 — both a genus placeholder and specific species in the same genus on the same gall (e.g., gall 4971 has both genus-level and species-level Sanicula associations)
- These violations need case-by-case admin review before the migration encodes the resolutions

## Decisions

- **No family-level host associations.** We are not planning to support host associations above genus level. The Genus/Section filter and the family browse feature (67c9) cover that need through filtering, not data entry.

## What's NOT in scope

- New data model / junction table for genus-level associations — the current species-as-placeholder approach works
- Special search/ID behavior beyond display — the Genus/Section filter already handles "show me all galls on this genus"
- Range data for placeholders — doesn't make sense conceptually

