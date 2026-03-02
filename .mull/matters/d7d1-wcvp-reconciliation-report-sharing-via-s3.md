---
status: raw
created: 2026-03-02
updated: 2026-03-02
epic: admin
relates: [8900]
---

# WCVP reconciliation report sharing via S3

## Problem

WCVP reconciliation (`mix gallformers.wcvp.reconcile`) must run locally because Mix isn't available on the Fly.io release. But the admin UI for reviewing reports runs on the server. Reports written to `priv/repo/data/reconciliation/` are baked into releases at build time — you can't upload new ones durably after deploy.

This means the second super admin can't see reconciliation results unless they also run the task locally with a fresh DB copy.

## Current workflow

1. `make download-db` — get fresh prod snapshot
2. `mix gallformers.wcvp.reconcile` — produces JSON reports locally
3. `mix gallformers.wcvp.apply range-updates.json --commit` — applies range changes locally
4. Reports viewable in admin UI only on localhost

## Proposed approach: S3-backed reports

Upload reconciliation reports to S3. The admin UI reads from S3 instead of the local filesystem.

- Reconcile task uploads JSON reports to S3 after writing locally (e.g. `s3://gallformers-backups/reconciliation/YYYY-MM-DD/`)
- `Wcvp.Reports` module switches from `File.read` to S3 fetch (with caching)
- `ReconciliationLive` admin page works unchanged once Reports module is updated
- Reports survive deploys and are accessible to all admins

## Files involved

- `lib/mix/tasks/gallformers/wcvp/reconcile.ex` — add S3 upload step after writing local files
- `lib/gallformers/wcvp/reporter.ex` — add S3 upload function
- `lib/gallformers/wcvp/reports.ex` — switch from local `File.read` to S3 fetch
- `lib/gallformers_web/live/admin/reconciliation_live.ex` — should work once Reports changes

## Open questions

- Use existing backups bucket or a dedicated path?
- Cache S3 reads on server (ETS or filesystem) or fetch on every page load?
- Keep local file writes too for dev convenience?

