---
status: raw
created: 2026-03-16
updated: 2026-03-17
epic: platform
---

# Upgrade CI GitHub Actions to Node.js 24 compatible versions

## Status (2026-03-17)

Waiting on two upstream actions before completing. Deadline: June 2, 2026.

## Ready to upgrade

| Action | Current | Target | Occurrences |
|--------|---------|--------|-------------|
| `actions/checkout` | `@v4` | `@v5` | 6 (ci.yml ×3, deploy.yml ×2, tileserver-deploy.yml ×1) |
| `actions/cache` | `@v4` | `@v5` | 3 (ci.yml ×2, deploy.yml ×1) |
| `actions/setup-node` | `@v4` | `@v5` | 1 (ci.yml assets job) |
| `docker/setup-buildx-action` | `@v3` | `@v4` | 1 (tileserver-deploy.yml — may be deleted) |

**Note on `setup-node@v5`**: Breaking change — auto-caches when `packageManager` is in package.json. Add `package-manager-cache: false` to preserve current behavior (we manage caching via `actions/cache`).

## Blocked on upstream

| Action | Current | Node 24 status | Occurrences |
|--------|---------|----------------|-------------|
| `erlef/setup-beam` | `@v1` | PR [#426](https://github.com/erlef/setup-beam/pull/426) open (2026-03-11), active | 3 (ci.yml ×2, deploy.yml ×1) |
| `superfly/flyctl-actions/setup-flyctl` | `@master` | Issues [#108](https://github.com/superfly/flyctl-actions/issues/108), [#109](https://github.com/superfly/flyctl-actions/issues/109) open, no PR | 2 (deploy.yml ×1, tileserver-deploy.yml ×1) |

## Not affected

`db-snapshot.yml` and `discord-release.yml` use no GitHub Actions (shell commands only).

## Files to touch

`ci.yml`, `deploy.yml`. `tileserver-deploy.yml` to be deleted (unused).

