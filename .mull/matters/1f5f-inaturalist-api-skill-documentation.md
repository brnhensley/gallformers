---
status: done
created: 2026-02-14
updated: 2026-02-14
blocks: [2708]
---

# iNaturalist API skill/documentation

Reusable Claude Code skill or documentation for working with the iNaturalist API.

Scope:
- Not gallformers-specific — should be usable on any project that talks to iNat
- API authentication (API key usage, rate limits)
- Observation endpoints: fetching observations by URL or ID
- Photo endpoints: getting original-size images, license info, attribution
- Taxonomy endpoints: species lookup, synonyms, taxonomic changes
- Sharp edges: rate limiting behavior, pagination quirks, license gotchas, image URL patterns
- Attribution requirements: what iNat/CC licenses require for display

Deliverable: A Claude Code skill file or standalone doc that an agent can be given when working with the iNat API.

Jeff has an iNat API key already.
