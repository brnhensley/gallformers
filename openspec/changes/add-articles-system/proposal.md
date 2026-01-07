# Proposal: add-articles-system

## Why

The current workflow for reference articles is untenable: authors must write markdown, push to GitHub, open a PR, wait for review/merge, then an admin must SSH to the server and run `git pull`. This friction discourages contributions and creates operational burden.

V2 needs an in-app article authoring system (like oaks) where authenticated users can create, edit, and publish articles directly through the web interface.

## What Changes

- **ADDED** `article` table in database (id, slug, title, author, description, content, tags, is_published, timestamps)
- **ADDED** Go API endpoints for article CRUD operations
- **ADDED** Svelte article list page (`/articles`)
- **ADDED** Svelte article view page (`/articles/[slug]`)
- **ADDED** Svelte article edit form with markdown editor
- **ADDED** MarkdownRenderer component (marked + DOMPurify)
- **ADDED** MarkdownEditor component (write/preview tabs)
- **ADDED** One-time migration script to import existing `ref/*.md` files

## Impact

- **Specs affected**: New `articles` capability
- **Code affected**: `v2/api/` and `v2/web/` (no v1 changes)
- **Risk**: Low - new feature, existing `ref/*.md` files remain until v1 removed

## Auth Model

- **Unauthenticated**: View published articles only
- **Authenticated**: Create, edit, publish articles
- **Author field**: Defaults to logged-in user's name, editable (for publishing on behalf of others)

## Dependencies

- `define-v2-foundation` minimum requirements:
  - Go API skeleton with chi router and basic middleware
  - Svelte app with routing and layout
  - SQLite database connection
  - Auth system (can be stubbed initially, real auth integrated later)
