---
status: raw
effort: 2 hours
created: 2026-02-15
updated: 2026-02-18
epic: platform
blocks: [4389]
---

# Real-time updates (PubSub)

From bead 707 (P4).

Configure PubSub in supervision tree, create broadcast helpers in contexts, subscribe in public LiveViews, handle entity_updated messages, test admin edit -> public page auto-update.

## Reframed as investigation

Before building anything: should we even do this? Questions to answer:

1. **Is there a real user problem?** Are users seeing stale data that causes confusion or bad decisions? Or is this a solution looking for a problem?
2. **Who benefits?** Admin-to-admin sync? Admin-to-public? Public-to-public?
3. **What pages would this apply to?** Species detail? Explore? Admin forms? All of them?
4. **What's the alternative?** Simple page refresh, short cache TTLs, or just accepting eventual consistency?
5. **Does converting read-only pages to controllers (9ad7) change the calculus?** If high-traffic pages become dead renders, there's no LiveView to push updates to.

Output: recommendation on whether to proceed, and if so, scoped proposal for where to apply it.
