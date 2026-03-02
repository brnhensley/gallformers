---
status: raw
created: 2026-03-02
updated: 2026-03-02
epic: taxonomy
relates: [cdfd]
---

# Reconsider explore page and taxonomy browse/navigation hierarchy

## Problem

The explore page, family/genus/section browse pages, and intermediate pages were built incrementally. With intermediate ranks now in place, we have a full taxonomy hierarchy but the navigation is fragmented: the explore page builds its own parallel tree, browse pages are separate LiveViews with separate queries, and URLs are all ID-based with no semantic meaning.

## Design

### Valid Intermediate Ranks

Constrain the `rank` field to a fixed set: `subfamily`, `infrafamily`, `supertribe`, `tribe`, `subtribe`, `infratribe`. Enforce in changeset validation. Admin form uses dropdown instead of free text. This is a prerequisite for rank-typed URLs.

### Browser Routes

```
/galls                      → gall taxonomy tree browse (entry point)
/hosts                      → host taxonomy tree browse (entry point)
/places                     → place hierarchy browse (extracted from explore)

/family/:name               → family page (e.g., /family/Cynipidae)
/genus/:name                → genus page (e.g., /genus/Cynips)
/section/:name              → section page
/subfamily/:name            → intermediate rank page
/tribe/:name                → intermediate rank page
/subtribe/:name             → intermediate rank page
/infrafamily/:name          → intermediate rank page
/supertribe/:name           → intermediate rank page
/infratribe/:name           → intermediate rank page

/gall/:id                   → gall species detail (unchanged)
/host/:id                   → host species detail (unchanged)
/place/:code                → place detail (unchanged)
```

**Removed:** `/explore` (redirect to `/galls`), `/taxonomy/:id` (dev-only, just replaced).

### Toolbar Navigation

Replace explore link with menu offering three browse entry points: Galls, Hosts, Places.

### API Changes

Existing routes stay ID-based, unchanged.

**New:**
- `GET /api/v2/intermediates/:id` — single endpoint for any intermediate rank, returns rank in response body
- `GET /api/v2/sections` — list all sections (currently only show-by-ID exists)

**Fixed:**
- `GET /api/v2/families/:id` — expose intermediate children alongside genera (currently only returns genera)
- `GET /api/v2/families` — include intermediate info in listings

### Backwards Compatibility

- `/family/:id` → redirect to `/family/:name`
- `/genus/:id` → redirect to `/genus/:name`
- `/section/:id` → redirect to `/section/:name`
- `/explore` → redirect to `/galls`

No redirect needed for `/taxonomy/:id` (dev-only, unreleased) or `/explore?tab=places` (also dev-only).

### Uniqueness Strategy

Name-based URLs assume uniqueness of family/genus/section/intermediate names. This holds today. If a collision ever occurs (theoretically possible for genus names across kingdoms), disambiguate at that time. YAGNI.

### Not in Scope

- Species URL changes (stays `/gall/:id`, `/host/:id`)
- API migration to name-based lookups
- Tree component/interaction UX redesign (trees move to new routes but component stays the same initially)

