---
status: planned
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

## Implementation Plan

**Goal:** Restructure taxonomy navigation with semantic URLs, validated intermediate ranks, separate browse entry points, and API intermediate support.

**Architecture:** Split the explore page into three standalone LiveViews (`/galls`, `/hosts`, `/places`). Switch all taxonomy browse routes from ID-based to name-based lookup using the existing `get_taxonomy_by_name/2`. Add rank validation as a changeset constraint. Add intermediate API endpoint and fix family endpoints to include intermediates.

### Task 1: Validate intermediate ranks in changeset

**Files:**
- Modify: `lib/gallformers/taxonomy/taxonomy.ex` (add `@valid_ranks`, validate_inclusion in `maybe_require_rank`)
- Modify: `lib/gallformers_web/live/admin/taxonomy_live/form.ex` (change rank text input to select dropdown, lines 622-633)
- Test: `test/gallformers/taxonomy_test.exs` (add changeset validation tests for valid/invalid ranks)

**Behavior:**
Add `@valid_ranks ~w(subfamily infrafamily supertribe tribe subtribe infratribe)` to the Taxonomy schema. In `maybe_require_rank/1`, add `validate_inclusion(:rank, @valid_ranks)` alongside the existing `validate_required`. Expose the list via a public function `valid_ranks/0` so the admin form can use it for the dropdown options. Change the admin form rank field from `type="text"` to `type="select"` with options built from `Taxonomy.valid_ranks/0`.

**Testing:**
- Changeset accepts each valid rank for type "intermediate"
- Changeset rejects invalid rank strings for type "intermediate"
- Changeset still allows nil rank for non-intermediate types

**Notes:** Run against prod data copy to verify no existing intermediates have rank values outside this set. If any do, fix the data first.

### Task 2: Split explore into /galls, /hosts, /places

**Files:**
- Create: `lib/gallformers_web/live/galls_browse_live.ex` (galls tree — extracted from ExploreLive galls+undescribed tabs)
- Create: `lib/gallformers_web/live/hosts_browse_live.ex` (hosts tree — extracted from ExploreLive hosts tab)
- Create: `lib/gallformers_web/live/places_browse_live.ex` (places tree — extracted from ExploreLive places tab)
- Modify: `lib/gallformers_web/router.ex` (add new routes, remove `/explore`, add `/explore` redirect)
- Modify: `lib/gallformers_web/live/explore_live.ex` (delete or gut — depends on redirect approach)
- Test: `test/gallformers_web/live/explore_live_test.exs` (update/replace with tests for new LiveViews)

**Behavior:**
Each new LiveView owns one browse experience. `GallsBrowseLive` at `/galls` shows described and undescribed gall trees (two tabs or toggle). `HostsBrowseLive` at `/hosts` shows the host tree. `PlacesBrowseLive` at `/places` shows the place hierarchy. All three use the existing `TreeComponents.tree_browser` and carry over the search/filter/expand logic from ExploreLive. The explore page becomes a redirect controller action that sends `/explore` → `/galls` (301 permanent).

**Testing:**
- `/galls` renders the gall taxonomy tree with family nodes
- `/hosts` renders the host taxonomy tree
- `/places` renders the place hierarchy
- `/explore` redirects to `/galls` with 301
- Search/filter behavior works on each page

**Notes:** The tree-building code (smart expand thresholds, search filtering) is currently in ExploreLive. Extract shared logic into a helper module or keep it duplicated if each page will diverge. The `Galls.get_galls_tree()` and `Plants.get_hosts_tree()` context functions stay as-is.

### Task 3: Toolbar navigation menu

**Files:**
- Modify: `lib/gallformers_web/components/layouts.ex` (replace single Explore link with dropdown menu, lines 65-68 nav_links)

**Behavior:**
Replace the "Explore" nav link with a dropdown menu (similar to the existing "Resources" dropdown at lines 70-76). Menu label: "Browse" (or "Explore" — keep the familiar name). Items: Galls (`/galls`), Hosts (`/hosts`), Places (`/places`). Render in both desktop and mobile nav sections.

**Testing:**
- Layout renders three browse links in the dropdown
- Each link points to the correct route

### Task 4: Semantic URLs for taxonomy browse pages

**Files:**
- Modify: `lib/gallformers_web/router.ex` (change `:id` to `:name` for family/genus/section, add rank-typed routes for intermediates, remove `/taxonomy/:id`)
- Modify: `lib/gallformers_web/live/family_live.ex` (mount takes `:name`, looks up via `get_taxonomy_by_name(name, "family")`)
- Modify: `lib/gallformers_web/live/genus_live.ex` (mount takes `:name`, looks up via `get_taxonomy_by_name(name, "genus")`)
- Modify: `lib/gallformers_web/live/section_live.ex` (mount takes `:name`, looks up via `get_taxonomy_by_name(name, "section")`)
- Modify: `lib/gallformers_web/live/intermediate_live.ex` (mount takes `:name`, extracts rank from route path, looks up via `get_taxonomy_by_name(name, "intermediate")` then verifies rank matches)
- Modify: `lib/gallformers_web/components/data_display_components.ex` (taxonomy_breadcrumb links change from `/family/#{id}` to `/family/#{name}`, etc.)
- Modify: tree link generation in `TreeBuilder` or wherever explore tree node URLs are built — family/genus nodes should link to `/family/:name`, `/genus/:name`
- Test: `test/gallformers_web/live/family_live_test.exs` and similar (update to use name-based routes)

**Behavior:**
Routes change from `/family/:id` to `/family/:name`. Each LiveView's mount parses the name param and calls `Taxonomy.get_taxonomy_by_name(name, type)`. For intermediates, six routes (`/subfamily/:name`, `/tribe/:name`, etc.) all point to `IntermediateLive` — the route determines the expected rank. IntermediateLive validates the looked-up record's rank matches the route (a subfamily accessed via `/tribe/X` returns 404).

All internal links (breadcrumbs, tree nodes, admin edit pencils) update to use name-based paths. The admin edit pencils keep using IDs since admin routes stay ID-based.

**Testing:**
- `/family/Cynipidae` loads the Cynipidae family page
- `/genus/Cynips` loads the Cynips genus page
- `/subfamily/Cynipinae` loads the Cynipinae intermediate page
- `/tribe/Cynipinae` returns 404 (wrong rank)
- Non-existent names return 404
- Breadcrumb links use names not IDs

**Notes:** `get_taxonomy_by_name/2` already exists in `tree.ex`. The IntermediateLive needs a way to know which rank to expect — pass it via router metadata or extract from the request path.

### Task 5: Backwards-compatible redirects for old ID-based URLs

**Files:**
- Create: `lib/gallformers_web/controllers/redirect_controller.ex` (handles old ID-based taxonomy routes)
- Modify: `lib/gallformers_web/router.ex` (add redirect routes for `/family/:id`, `/genus/:id`, `/section/:id` where `:id` is numeric)

**Behavior:**
When a request hits `/family/123` (numeric), look up the taxonomy by ID, then 301 redirect to `/family/Cynipidae`. Same for genus and section. Non-numeric params pass through to the LiveView (they're names). This can be handled by the LiveView itself (check if param is numeric, redirect if so) or by a separate controller route that matches numeric patterns.

**Testing:**
- `/family/123` redirects to `/family/Cynipidae` (301)
- `/genus/456` redirects to `/genus/Cynips` (301)
- `/family/Cynipidae` loads normally (no redirect loop)
- Invalid numeric IDs return 404

**Notes:** Phoenix route matching is first-match. Put the redirect routes (matching integers) before the name-based LiveView routes. Or handle it in the LiveView mount: if the param parses as an integer, look up and redirect.

### Task 6: API intermediate endpoint and family fixes

**Files:**
- Modify: `lib/gallformers_web/controllers/api/taxonomy_controller.ex` (add `intermediate/2` action, add `sections/2` list action, fix `family/2` and `families/2` to include intermediates)
- Modify: `lib/gallformers_web/router.ex` (add API routes for intermediates and sections list)
- Test: `test/gallformers_web/controllers/api/taxonomy_controller_test.exs` (add tests for new endpoints, update family tests)

**Behavior:**
New `GET /api/v2/intermediates/:id` endpoint returns: `{id, name, type, rank, description, parent: {id, name, type}, children: [{id, name, type, rank?}]}`. Children are the intermediate's direct children (genera or sub-intermediates).

New `GET /api/v2/sections` list endpoint returns all sections with parent genus info.

Fix `GET /api/v2/families/:id` to distinguish between genus and intermediate children in the response. Current response uses a `genera` key — change to `children` array where each child has a `type` field (`"genus"` or `"intermediate"` with `rank`).

Fix `GET /api/v2/families` list to include intermediate children in the per-family listings.

**Testing:**
- `GET /api/v2/intermediates/:id` returns correct intermediate with rank and children
- `GET /api/v2/intermediates/:id` returns 404 for non-intermediate taxonomy
- `GET /api/v2/sections` returns list of all sections
- `GET /api/v2/families/:id` response includes both genera and intermediates with type discrimination
- `GET /api/v2/families` list includes intermediates per family

**Notes:** The family endpoint response format change (`genera` → `children`) is safe to make in v2. Request log analysis (Feb 2026) shows essentially zero API consumers — 10 total API hits across the month, all with null user-agent (likely health checks or dev testing). No versioning needed. The OpenAPI spec at `/api/docs/openapi.json` needs updating too.
