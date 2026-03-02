---
status: raw
created: 2026-03-02
updated: 2026-03-02
epic: platform
---

# JS bundle size optimization

## Current state

Dev build shows 2MB warning from esbuild (inflated by inline source maps). Production bundle is ~1.2MB uncompressed, 341KB gzipped — wire size is acceptable but uncompressed grew ~5x when MapLibre GL was added.

## Breakdown

- MapLibre GL (WebGL maps): ~500-600KB (~45%)
- D3 (admin bar chart): ~300-400KB (~30%)
- Phoenix/LiveView: ~200-300KB (~20%)
- Custom code + PMTiles: ~100KB (~5%)

## Opportunities

1. **Code splitting / lazy loading** — MapLibre and D3 only used on a few pages but loaded everywhere. Dynamic `import()` in hooks would avoid loading map library for most visitors. Biggest win.
2. **Replace D3 for admin chart** — ~300KB for a bar chart. Vanilla Canvas/SVG would be ~10KB. Admin-only so low priority but pure waste.
3. **Brotli pre-compression** — 15-20% better than gzip on JS if not already configured.

## Not urgent

341KB gzipped is within normal range for an app with maps. Address when it starts impacting real users or crosses 500KB gzipped.
