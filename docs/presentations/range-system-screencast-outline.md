# Range System for Admins — Screencast Series Outline

Series of 4 short videos covering the full range subsystem. Audience: all admins.

## Video 1: Foundations — Places, Precision & the Map (~6 min)

Everything else builds on understanding these concepts.

1. **The places hierarchy** — continent, country, state/province, and why "leaf places" matter
2. **Precision: exact vs country-level**
   - Exact = "we know it's in this specific state"
   - Country = "it's somewhere in this country but we don't know which states"
   - Show on the map: dark green (exact) vs light green (inherited/country-level)
3. **The map legend** — walk through each color/pattern and what it means
4. **Native vs introduced** — what the hatched pattern means, why we track this distinction
5. **Navigable maps on public pages** — click a region, go to the place page

**Demo path**: Pick a host with both exact and country-level entries, show its public page, point out the legend.

---

## Video 2: Host Ranges & WCVP Sync (~8 min)

Hosts are the data source that gall ranges build on.

1. **Where host range data comes from** — WCVP / Kew Gardens, TDWG botanical regions mapped to our places
2. **Host Range Review page** (`/admin/host-range`)
   - Filters: confirmed/unconfirmed, WCVP match, sync status
   - Search by name/genus/family
   - Bulk confirm and bulk sync
3. **Syncing a single host** — navigate to Host Edit (`/admin/hosts/:id`)
   - The 6-bucket diff: add native, add introduced, remove, reclassify (x2), agree
   - Cherry-picking changes — you don't have to accept everything WCVP says
   - Save applies your selections
4. **CountryDrillDown panel** — click a country on the host map
   - Toggle country-level precision on/off
   - Set distribution type (native/introduced) at country level
   - Check individual states for exact documentation
5. **Confirmation** — what "confirmed" means, how it gets invalidated when hosts change

**Demo path**: Find an unconfirmed host, sync from WCVP, walk through the diff, cherry-pick, drill into a country, confirm.

---

## Video 3: Gall Range Curation (~8 min)

Now that admins understand host ranges, show how gall ranges layer on top.

1. **The mental model** — gall range = "where does this gall actually occur?" carved out of "where do its hosts grow"
2. **The fallback** — if no curated range exists, the public page shows the union of all hosts' *native* ranges (introduced excluded). Once you curate, the curated range is the source of truth.
3. **GallHost page** (`/admin/gallhost`) — the main workspace
   - Select a gall via typeahead
   - Host management: add/remove hosts (and how that affects the range canvas)
   - **The map colors in this context**:
     - Green = in gall range (included)
     - Red/coral = in host range but NOT in gall range (excluded)
   - Click a subdivision to toggle inclusion directly
4. **RangeDrillDown panel** — click a country with subdivisions
   - Checkboxes: checked = included, unchecked = excluded
   - Include All / Exclude All shortcuts
   - Only shows subdivisions where hosts actually occur (no phantom entries)
5. **The implicit exclusion model** — there is no "exclusions table." If a place is in the host range but not in gall_range, it's excluded. Simple as that.
6. **Save vs Save & Confirm** — when to use which

**Demo path**: Pick a gall with multiple hosts, show the fallback range on the public page, then go to GallHost, curate the range (include some, exclude some, drill into a country), save & confirm, show the public page again.

---

## Video 4: Review Workflows & Day-to-Day (~5 min)

Now admins know the tools — show how to use them in practice.

1. **Gall Range Review page** (`/admin/gall-range`)
   - The triage list: unconfirmed galls needing range review
   - Show All toggle
   - Bulk confirm (for cases where fallback range is good enough)
   - Click a gall name to jump to GallHost for detailed curation
2. **Host Range Review page revisited** — the triage workflow
   - Filter to "never synced", bulk sync, review results modal
   - Handling no-matches and failures
3. **When does confirmation get invalidated?** — adding/removing hosts from a gall resets its range confirmation
4. **The typical workflow**:
   - Sync host ranges from WCVP (periodic)
   - Curate gall ranges on GallHost page
   - Use review pages to track what still needs attention

**Demo path**: Show the gall range review page filtered to unconfirmed, pick one, curate it, come back and show it's now confirmed.

---

## Recording Tips

- Use the same gall/host examples across videos where possible — builds familiarity
- Pick a gall with 2-3 hosts spanning multiple countries for the best demo of drill-down and exclusion
- Show the public page before and after curation in Video 3 — the "aha moment" is seeing the map change
