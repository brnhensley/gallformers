---
status: done
created: 2026-03-17
updated: 2026-03-17
epic: identification
relates: [85c0]
docket: true
---

# Region hint for global search — show filtered-out results

When a region/place filter is active in global search and a species has no range data (or range outside the selected region), it doesn't appear in results. The user has no indication that the species exists.

## Design

### Problem
Region filter is set once at first login and forgotten. Users don't connect empty search results to the active filter.

### Changes

**1. Region scope bar — visual emphasis when filter is active**
- Active filter: `bg-amber-50 border-b border-amber-200`, icon/text `text-amber-700`, label "Filtered to" before region name
- No filter ("All Regions"): keep current neutral gray styling
- Scope: `region_scope` component in `ui_components.ex`

**2. No-results message — mention the filter**
- When `@continent_code` is set and results are zero: "No results for 'query' in **[Region]**. You have a region filter active — try searching **All Regions** or adjusting your search terms." with "All Regions" as a clickable link that clears the filter.
- When no filter is active: keep current generic message.
- Scope: `search_live.ex` render function

No new queries, no new assigns. ~20 lines of template changes.
