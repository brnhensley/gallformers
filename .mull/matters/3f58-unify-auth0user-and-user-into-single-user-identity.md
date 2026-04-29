---
status: raw
created: 2026-03-26
updated: 2026-04-25
epic: admin
relates: [0fc6]
---

# Unify Auth0User and User into single user identity

Auth0 is an implementation detail. The web layer should see a single "User" concept and go through the Accounts context for everything.

## Current state

Three representations of "a user":
- **Auth0User** — session struct from Auth0 (id, email, name, nickname, picture, roles). Not persisted. Stored in session as `@current_user`.
- **User** — Ecto schema in `users` table. Profile preferences (display_name, about_me, URLs, show_on_about). Linked via `auth0_id`.
- **Accounts** — context that manages both, plus session lifecycle, role checks, and Auth0↔DB sync.

`display_name` exists in three places with different semantics:
1. `Auth0User.display_name/1` — name→nickname→email fallback from Auth0
2. `User.display_name` — DB field, user-editable, synced from Auth0 on login
3. `Accounts.db_display_name/1` — reads DB display_name from session map

The web layer passes `@current_user` as Auth0User and directly calls `Auth0User.display_name`. 8 call sites across layouts, controllers, and LiveViews. This leaks the auth provider abstraction into every admin page.

## Direction

Collapse into a single user identity. The web layer sees one struct, asks Accounts for everything. Auth0 becomes internal to Accounts. The `@current_user` assign should be a unified concept merging auth data + profile data.

Discovered during 82f8 (boundary violations) — Auth0User dirty_xref in GallformersWeb.
