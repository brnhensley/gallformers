# Western Hemisphere Expansion — Product Requirements

## Vision

Expand gallformers.org from US + Canada coverage to the entire Western Hemisphere
(North America, Central America, Caribbean, South America). Driven by community and
research demand — the Neotropical gall fauna is rich and actively being studied, and
gallformers wants to support that work.

## Release Strategy

Ship complete or don't ship. All work streams ship together. Post-launch iteration
expected, but no partial rollout. No hard deadline — important but not time-pressured.

## Scope

### 1. Geographic Data Model

- Add all Western Hemisphere countries with state/province-level subdivisions
- Curating the subdivision list is part of the work (no known single authoritative source)
- Audit existing data for species whose ranges already extend past US/Canada
  (e.g., southern Florida / Caribbean overlap)

### 2. Research: Neotropical Plant Data Sources

- Investigate what authoritative data sources exist for Central/South American flora
- Evaluate feasibility of bootstrapping host plant data from any such sources
- If nothing viable, host data grows organically — which makes admin workflow
  improvements even more critical

### 3. Admin UX — Data Entry Workflow

- **Inline entity creation**: When a required entity (host, family, genus) doesn't
  exist, create it in a minimally viable state without leaving the current screen.
  No more bouncing between 3 separate screens.
- **Streamlined workflows**: Reduce friction in existing workflows to minimize the
  need for bulk import tooling
- **Sources required**: All data must be sourced from day one

### 4. Admin UX — Taxonomy Management

- Tools for splitting, merging, and moving taxa between parents
- Currently these operations are manual and done by a small number of admins
- Needs to be more robust and less error-prone for the expansion

### 5. Public UI (Needs Significant Exploration)

- **Search**: Must support species, hosts, and galls from all new regions
- **ID Tool**: Must work with expanded geographic and taxonomic scope
- **Browse/Filter**: Ability to browse/filter by country or region
- **Multilingual names**: Support local common names (Spanish, Portuguese, indigenous)
  via existing aliases/common names system. UI remains English.
- **Note**: The public UI changes beyond maps will require substantial design
  exploration before committing to approaches. The current UI was designed around a
  North American dataset and many assumptions may not hold.

### 6. Maps (High Risk — Prototype First)

Current maps show shaded US states/Canadian provinces. This does not scale to a hemisphere.

**Unsolved UX problems:**
- Hemisphere-spanning species vs. single-country endemics need different treatments
- Subdivisions become unreadably small at hemisphere scale
- Performance implications of rendering many more polygons
- How to display range meaningfully at varying scales

**This must be prototyped and proven before full implementation begins.** It is the
highest-risk item in this effort.

Possible directions: adaptive zoom, drill-down by country, region-focused views — all
open questions requiring design exploration and engineering prototyping.

### 7. Branding & Messaging

- Update site copy, about page, guides to reflect Western Hemisphere scope
- No longer position as a North American resource

## Key Assumptions

- Comprehensive host plant databases for Central/South America are limited compared
  to USDA PLANTS for the US. The research task (#2) will determine what's available.
  If nothing viable, host plant data grows organically through contributor entry —
  making the inline creation workflow (#3) critical path.
- English remains the lingua franca for the UI. Local/indigenous common names are
  supported as data (aliases), not as UI localization.
- Existing admins handle initial data entry. New admins from covered regions may be
  added over time (user provisioning tracked separately).

## Out of Scope

- UI localization (stays English)
- Eastern Hemisphere expansion
- Bulk import (may revisit if workflow improvements prove insufficient)
- Admin user provisioning/deprovisioning (captured in separate document)
