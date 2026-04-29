---
status: done
created: 2026-03-01
updated: 2026-03-01
epic: geo-expansion
relates: [8900]
---

# Landscape range map on public gall page

## Problem

With global coverage, the range map on public gall pages has two issues:

1. **Aspect ratio mismatch**: The map sits in a narrow sidebar (256-320px wide, 400px min-height) — portrait orientation. But species ranges spread latitudinally (east-west), so the map's shape fights the data.
2. **Over-zoom on global ranges**: `maxZoom: 8` in `fitToRange` causes the auto-fit to zoom in too tight on clusters, centering on ocean or cropping the range so the full picture isn't visible at a glance.

## Design

**Move the map from sidebar to full-width row below traits.**

### Layout change (gall_live.ex template)

Pull the map `<div>` out of the `flex-col md:flex-row` container (line ~429) that currently holds traits + map side-by-side. Place it as its own block below, still within the `lg:col-span-2` section.

- Remove `md:w-64 lg:w-80 shrink-0` wrapper
- Map gets full width of the 2-column area (~600-700px on desktop)
- Pass `class="min-h-[250px] h-[300px]"` for a landscape aspect ratio (~2:1)

### Traits grid (gall_live.ex template)

With the map gone from the sidebar, the traits have full width. Change the attributes grid from `grid-cols-1 md:grid-cols-2` to `grid-cols-1 md:grid-cols-3`. Redistribute 11 trait fields across 3 columns (~4/4/3). This takes less vertical space.

### Zoom cap (range_map.js)

Reduce `maxZoom` in `fitToRange()` from `8` to `5` so global/continental ranges stay zoomed out enough to show context.

### Files touched

1. `lib/gallformers_web/live/gall_live.ex` — template restructure
2. `assets/js/hooks/range_map.js` — maxZoom change

### What stays the same

- Component API (`<.range_map>`) unchanged
- `navigable` behavior unchanged
- Fullscreen control still available
- Mobile layout unchanged (already stacks vertically)
- No new components needed
