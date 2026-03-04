---
status: raw
created: 2026-03-04
updated: 2026-03-04
epic: identification
relates: [85c0, 53cb]
---

# Browse/filter galls by host family

## Survey Feedback (2026-03-04)

"Currently can only identify galls by host species or genus, but sometimes it would be nice to view galls by host family, especially for plant taxa that are difficult to ID or when necessary characters for a precise host ID are lacking when a gall is observed (eg: this plant is in the mint family but isn't blooming so the precise ID is ambiguous)"

## Use Case

Field observers often can't ID a host plant to species or genus (e.g., not blooming, lacking key characters). They CAN usually ID to family. Currently there's no way to browse galls at that level.

## Notes

- The data model already has family → genus → species hierarchy
- Host associations go through species, so aggregating up to family is a query-level change
- Could be an additional filter/entry point on the ID page, or a separate browse-by-family view
- Keys feature (85c0) may also benefit from family-level entry points
