---
status: planned
created: 2026-03-05
updated: 2026-03-05
epic: admin
relates: [e617]
docket: true
---

# WCVP fuzzy search modal for host admin

## Problem

When editing a host and clicking WCVP refresh, if no exact match is found the user gets a toast error and no way forward. This is a dead end — the user has to manually figure out what WCVP calls this species.

## Design

Replace the toast with a **search modal** that lets the user find the right WCVP entry interactively.

### Trigger

When the existing refresh logic (`refresh_from_wcvp` handler in `HostLive.Form`) finds no exact match — currently line 283 `put_flash(:error, ...)`.

### Modal contents

- Message: "No exact match found in WCVP for {host name}"
- Search input pre-filled with the host's current name
- Results list below (taxon name only), updated as user types
- Selected result highlighted in the list
- Two buttons: **Cancel** / **Continue** (Continue disabled until a result is selected)

### Flow

1. User clicks WCVP refresh → no exact match found
2. Modal opens with pre-filled search, initial results shown
3. User refines search if needed (can backspace to genus-only), clicks a result to select it
4. Clicks **Continue** → modal closes, proceeds to existing diff modal with the selected WCVP entry
5. Or clicks **Cancel** → modal closes, nothing happens

### Search approach

Add `Lookup.search_contains/2` — splits query on whitespace, ANDs each term as a contains match:

    "Aln sin" → WHERE lower(taxon_name) LIKE '%aln%' AND lower(taxon_name) LIKE '%sin%'

This handles:
- Subspecies: "Alnus sinuata" matches "Alnus alnobetula subsp. sinuata"
- Partial typing: "Aln sin" matches same
- Genus-only browsing: user deletes epithet, searches just "Alnus"

Reuses the same pattern as `Gallformers.Search` global search (term-splitting with `%term%`).

### What stays the same

- Existing diff modal (range changes, wcvp_id, apply/cancel) is unchanged
- `Lookup.search/2` (prefix match) is unchanged — still used elsewhere
- No new modules needed; changes are in `Lookup` + `HostLive.Form`

### Key files

- `lib/gallformers/wcvp/lookup.ex` — add `search_contains/2`
- `lib/gallformers_web/live/admin/host_live/form.ex` — modal UI + event handlers
