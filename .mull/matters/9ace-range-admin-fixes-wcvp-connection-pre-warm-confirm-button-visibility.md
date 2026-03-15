---
status: done
created: 2026-03-14
updated: 2026-03-14
epic: platform
---

# Range admin fixes — WCVP connection pre-warm, confirm button visibility

WCVP SQLite repo starts in the supervision tree but ecto_sqlite3 pools are lazy — no connection until first query. After a deploy, the first user to hit a WCVP-dependent page (host range admin, POWO diff review) gets a slow response while the connection initializes.

Fix: run a trivial query (`SELECT 1`) against the WCVP repo after it starts, either via a Task in the supervision tree or an after-startup hook. Keeps the first real request fast.

Files: `lib/gallformers/application.ex`, `lib/gallformers/repo/wcvp.ex`

WCVP SQLite repo starts in the supervision tree but ecto_sqlite3 pools are lazy — no connection until first query. After a deploy, the first user to hit a WCVP-dependent page (host range admin, POWO diff review) gets a slow response while the connection initializes.

Fix: run a trivial query (`SELECT 1`) against the WCVP repo after it starts, either via a Task in the supervision tree or an after-startup hook. Keeps the first real request fast.

Files: `lib/gallformers/application.ex`, `lib/gallformers/repo/wcvp.ex`

---

Bug: On host range admin, when a host's range is unconfirmed, the "Save and Confirm" button doesn't appear until after a change is made AND the Save button is pressed. It should be visible immediately when viewing an unconfirmed host range.
