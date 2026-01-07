# Tasks: add-articles-system

## 1. Database

- [ ] Add article table to database schema
- [ ] Create indexes on slug and is_published
- [ ] Add migration script

## 2. Go API - Models

- [ ] Create Article model in `internal/models/`
- [ ] Add JSON/DB serialization

## 3. Go API - Database Layer

- [ ] Create `internal/db/articles.go`
- [ ] Implement InsertArticle (with slug generation)
- [ ] Implement GetArticle (by slug)
- [ ] Implement ListArticles (with published filter, tag filter)
- [ ] Implement UpdateArticle
- [ ] Implement DeleteArticle
- [ ] Implement ListArticleTags
- [ ] Add tests for database operations

## 4. Go API - Handlers

- [ ] Create `internal/handlers/articles.go`
- [ ] Implement handleListArticles (GET /api/v1/articles)
- [ ] Implement handleGetArticle (GET /api/v1/articles/{slug})
- [ ] Implement handleCreateArticle (POST /api/v1/articles)
- [ ] Implement handleUpdateArticle (PUT /api/v1/articles/{slug})
- [ ] Implement handleDeleteArticle (DELETE /api/v1/articles/{slug})
- [ ] Implement handleListArticleTags (GET /api/v1/articles/tags)
- [ ] Register routes in server.go
- [ ] Add auth middleware to write endpoints
- [ ] Implement pagination helper (limit/offset parsing, response envelope)
- [ ] Apply pagination to ListArticles as pilot pattern

## 5. Svelte - Shared Components

- [ ] Create MarkdownRenderer.svelte (marked + DOMPurify)
- [ ] Create MarkdownEditor.svelte (write/preview tabs)
- [ ] Create TypeaheadMultiSelect.svelte (general-purpose autocomplete with multi-select)
- [ ] Add prose styling to app.css
- [ ] Add marked and dompurify dependencies

## 6. Svelte - API Client

- [ ] Add fetchArticles function
- [ ] Add fetchArticle function
- [ ] Add createArticle function
- [ ] Add updateArticle function
- [ ] Add deleteArticle function
- [ ] Add fetchArticleTags function

## 7. Svelte - Article Pages

- [ ] Create /articles route (+page.svelte, +page.server.js)
- [ ] Create ArticleList.svelte component
- [ ] Create /articles/[slug] route
- [ ] Create ArticleView.svelte component

## 8. Svelte - Article Editing

- [ ] Create ArticleEditForm.svelte (modal)
- [ ] Wire up create flow from list page
- [ ] Wire up edit flow from view page
- [ ] Handle author field default (logged-in user)

## 9. Navigation

- [ ] Add "Articles" link to main navigation

## 10. Migration

- [ ] Create migration script (cmd/migrate-articles or standalone)
- [ ] Parse frontmatter from ref/*.md files
- [ ] Generate slugs from filenames
- [ ] Insert into article table as published
- [ ] Test with all 7 existing articles
- [ ] Document migration procedure

## 11. Testing & Verification

- [ ] Test article CRUD via API
- [ ] Test list filtering (published, tags)
- [ ] Test pagination (limit, offset, has_more)
- [ ] Test markdown rendering (headings, lists, links, code)
- [ ] Test auth requirements on write endpoints
- [ ] Test auth integration (stub → real auth transition)
- [ ] Test author field defaults and editability
- [ ] Verify migrated articles display correctly
