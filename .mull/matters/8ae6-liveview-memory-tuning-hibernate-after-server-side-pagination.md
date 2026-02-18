---
status: done
created: 2026-02-18
updated: 2026-02-18
epic: platform
relates: [1edb, 9ad7]
---

# LiveView memory tuning (hibernate_after + server-side pagination)

Two fixes identified during the Feb 18 OOM step-function investigation:

1. **Add hibernate_after: 5_000 to LiveView socket config** — one-line change in endpoint.ex. All idle LiveView processes will hibernate after 5s, aggressively GC their heap. Currently zero LiveView memory tuning exists anywhere in the codebase.

2. **Server-side pagination for admin index pages** — Admin.GallLive.Index, Admin.HostLive.Index, and Admin.TaxonomyLive.Index all load entire unbounded result sets into socket assigns. Add LIMIT/OFFSET queries and track page state in the LiveView.

Context: docs/investigations/20260218-oom-crash-bot-traffic-memory-accumulation.md
