---
status: done
created: 2026-02-15
updated: 2026-02-15
relates: [be64, 1cab]
---

# Gracefully handle invalid URLs in templates

Phoenix <.link> crashes with ArgumentError when given href values with unsupported schemes. This causes 500 errors on public pages when source/species_source records have bad URL data.

Affected templates:
- gall_live.ex:655 — species_source.externallink passed to <.link href={}>
- source_live.ex:162 — source.link passed to <.link href={}>
- source_live.ex:185 — source.licenselink passed to <.link href={}>

Defense-in-depth: even after fixing existing data (be64) and adding validation (1cab), templates should never crash on bad data. A rendering issue should degrade gracefully, not take down the page.

Approach: create a helper function (e.g. valid_url?/1 or safe_href/1) that checks whether a string is a valid URL before passing to <.link>. If invalid, render the text without a link rather than crashing. Place the helper in a shared location (component or utility module) since multiple templates need it.

Could also be a component like <.external_link> that wraps <.link> with the safety check built in.
