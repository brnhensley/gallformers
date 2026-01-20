# Tasks: add-articles-system

**NOTE**: Implementation uses Phoenix LiveView instead of Go/Svelte. Tasks below are marked
complete based on equivalent Phoenix/Elixir functionality.

## 1. Database

- [x] Add article table to database schema (`v2/priv/repo/migrations/20260115010357_create_articles.exs`)
- [x] Create indexes on slug and is_published (included in migration)
- [x] Add migration script (same file)

## 2. ~~Go API - Models~~ Elixir Schema

- [x] Create Article schema in `lib/gallformers/articles/article.ex`
- [x] Add JSON/DB serialization via `TagsType` custom Ecto type

## 3. ~~Go API - Database Layer~~ Elixir Context

- [x] Create `lib/gallformers/articles.ex` context
- [x] Implement create_article (with slug generation)
- [x] Implement get_article_by_slug!/1
- [x] Implement list_articles (with published filter, tag filter)
- [x] Implement update_article
- [x] Implement delete_article
- [x] Implement list_tags/0 and list_all_tags/0
- [x] Add tests for context operations (`test/gallformers/articles_test.exs`)

## 4. ~~Go API - Handlers~~ LiveView Modules

- [x] Create `lib/gallformers_web/live/ref_index_live.ex` (article list)
- [x] Create `lib/gallformers_web/live/ref_article_live.ex` (single article view)
- [x] Create `lib/gallformers_web/live/admin/article_admin_live.ex` (CRUD)
- [x] Register routes in router.ex
- [x] Add auth via admin live_session (requires authentication)
- [ ] ~~Implement pagination helper~~ N/A for LiveView pattern

## 5. ~~Svelte~~ Phoenix Components

- [x] Create Markdown module (`lib/gallformers/markdown.ex`) using Earmark
- [x] Create MarkdownEditor equivalent (edit/preview tabs in ArticleAdminLive)
- [x] Create TypeaheadMultiSelect component - uses `multi_select_dropdown` from FormComponents
- [x] Add prose styling via Tailwind
- [x] Add Earmark dependency for markdown

## 6. ~~Svelte - API Client~~ N/A

N/A - LiveView calls context functions directly, no separate API client needed.

## 7. ~~Svelte~~ LiveView - Article Pages

- [x] Create /refindex route (RefIndexLive)
- [x] Create article list UI in RefIndexLive
- [x] Create /ref/:slug route (RefArticleLive)
- [x] Create article view UI in RefArticleLive

## 8. ~~Svelte~~ LiveView - Article Editing

- [x] Create ArticleEditForm (modal in ArticleAdminLive)
- [x] Wire up create flow from admin page
- [x] Wire up edit flow from admin page
- [x] Handle author field default (logged-in user's display name)

## 9. Navigation

- [x] Add "Reference" link to main navigation (`lib/gallformers_web/components/layouts.ex`)

## 10. Migration

- [x] Create migration task (`lib/mix/tasks/migrate_articles.ex`)
- [x] Parse frontmatter from ref/*.md files
- [x] Generate slugs from filenames
- [x] Insert into article table as published
- [x] Test with all 7 existing articles (seed migration `20260115203624_seed_articles.exs`)
- [x] Document migration procedure (inline comments in task)

## 11. Testing & Verification

- [x] Test article CRUD via context (`test/gallformers/articles_test.exs`)
- [x] Test list filtering (published, tags)
- [ ] ~~Test pagination~~ N/A for LiveView pattern
- [x] Test markdown rendering via Markdown module
- [x] Auth enforced via admin live_session
- [x] Test author field defaults and editability
- [x] Verify migrated articles display correctly (seed migration)

## 12. Additional Improvements (Jan 2026)

- [x] Add `description` field for article previews and SEO meta
- [x] Add `published_at` field with auto-set on publish transition
- [x] Add slug collision handling (auto-appends -2, -3, etc.)
- [x] Add `published_only` option to `list_tags/1` for public vs admin views
- [x] Replace comma-separated tag input with `multi_select_dropdown` component
- [x] Update public views to prefer `description` over content preview
- [x] Update public views to display `published_at` instead of `inserted_at`
- [x] Update JSON-LD to use `published_at` for `datePublished`
