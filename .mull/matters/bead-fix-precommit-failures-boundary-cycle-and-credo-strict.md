---
status: raw
created: 2026-04-01
updated: 2026-04-01
epic: platform
relates: [b016, 82f8]
---

# Fix precommit failures — Boundary cycle and Credo strict

## Problem

`mix precommit` fails on two steps, both pre-existing:

### 1. `compile --warnings-as-errors` — Boundary dependency cycle

`Galls → Ranges → Galls`. Ranges imports `Gallformers.Galls.{GallHost, GallTraits}` schemas to use in queries (specifically `invalidate_gall_ranges_for_host/1`). It never calls Galls context functions.

This is the last remaining cycle from matter 82f8, which resolved the other two. The hacky fix (use string table names to avoid the schema import) was rejected — the real question is where `invalidate_gall_ranges_for_host` and its schema dependencies should live architecturally.

Options to evaluate:
- Move `invalidate_gall_ranges_for_host` from Ranges into Galls (it operates on gall data)
- Move GallHost/GallTraits schemas to a shared location
- Restructure the Ranges/Galls boundary

### 2. `credo --strict` — 515 design suggestions (all [D] level)

All from custom Credo checks (no upstream Credo issues):
- 235 × `NoBareTruthinessAssert` — `assert field` without comparison
- 164 × `FlashOnlyAssertions` — form tests only check flash, not DB state
- 88 × `TestsOwnTheirData` — tests read DB without creating own data
- 12 × misc (nested modules, hardcoded IDs)

The bulk remediation is tracked in matter b016. The precommit question is: should `--strict` stay in precommit (aspirational but red), or should it move to `check-full` until b016 reduces the count to zero?

