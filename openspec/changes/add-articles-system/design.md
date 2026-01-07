# Design: add-articles-system

## Context

### Current Workflow (V1)
1. Author writes markdown file locally
2. Push to GitHub branch
3. Open PR, wait for review
4. Merge PR
5. Admin SSHs to server, runs `git pull`
6. Wait for server to pick up changes

This is slow, requires git knowledge, and creates operational burden.

### Target Workflow (V2)
1. Author logs in
2. Clicks "New Article"
3. Writes content in markdown editor with live preview
4. Clicks "Publish" (or saves as draft)
5. Article is immediately live

### Reference Implementation
The [oaks project](https://github.com/jeffdc/oaks) has a working article system:
- `api/internal/handlers/articles.go` - Go API handlers
- `api/internal/db/articles.go` - Database operations
- `web/src/routes/articles/` - Svelte pages
- `web/src/lib/components/MarkdownEditor.svelte` - Editor component
- `web/src/lib/components/MarkdownRenderer.svelte` - Display component

---

## Database Schema

```sql
CREATE TABLE article (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    description TEXT,
    content TEXT,
    tags TEXT,  -- JSON array stored as text
    is_published INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    published_at TEXT
);

CREATE INDEX idx_article_slug ON article(slug);
CREATE INDEX idx_article_is_published ON article(is_published);
```

**Slug generation**: Derived from title at creation time, lowercased, spaces to hyphens, special chars removed. Slugs are immutable after creation (title changes do not update slug).

---

## API Design

Following oaks pattern with chi router:

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/articles` | No | List articles (published only if unauth), paginated |
| GET | `/api/v1/articles/{slug}` | No | Get single article |
| POST | `/api/v1/articles` | Yes | Create article |
| PUT | `/api/v1/articles/{slug}` | Yes | Update article |
| DELETE | `/api/v1/articles/{slug}` | Yes | Delete article |
| GET | `/api/v1/articles/tags` | No | List all tags with counts |

### Pagination (pilot pattern for all v2 APIs)

**Query parameters:**
- `limit` - Max items to return (default: 20, max: 100)
- `offset` - Number of items to skip (default: 0)

**Response envelope:**
```json
{
  "data": [...],
  "pagination": {
    "total": 42,
    "limit": 20,
    "offset": 0,
    "has_more": true
  }
}
```

### Sort Order

Default: newest first (by `published_at`, falling back to `created_at` for drafts).

Sort parameter can be added later if needed.

**Request body (create/update)**:
```json
{
  "title": "Article Title",
  "author": "Author Name",
  "description": "Short one-sentence description",
  "content": "Markdown content...",
  "tags": ["guide", "identification"],
  "is_published": true
}
```

**Required fields:** `title`, `author`
**Optional fields:** `description`, `content`, `tags`, `is_published` (defaults to false)

**Response**:
```json
{
  "id": 1,
  "slug": "article-title",
  "title": "Article Title",
  "author": "Author Name",
  "description": "Short one-sentence description",
  "content": "Markdown content...",
  "tags": ["guide", "identification"],
  "is_published": true,
  "created_at": "2026-01-07T12:00:00Z",
  "updated_at": "2026-01-07T12:00:00Z",
  "published_at": "2026-01-07T12:00:00Z"
}
```

---

## Svelte Components

### Routes
- `/articles` - Article list (ArticleList component)
- `/articles/[slug]` - Article view (ArticleView component)

### Components (from oaks, adapt styling)
- `MarkdownRenderer.svelte` - Renders markdown to sanitized HTML using marked + DOMPurify
- `MarkdownEditor.svelte` - Write/Preview tabs with textarea
- `ArticleList.svelte` - Grid/list of article cards with tag filter
- `ArticleView.svelte` - Full article display with edit button (if auth)
- `ArticleEditForm.svelte` - Modal for create/edit (no separate routes)
- `TypeaheadMultiSelect.svelte` - General-purpose autocomplete with multi-select (reusable across UI)

### Tag Input
Tags are entered via `TypeaheadMultiSelect` component:
- Autocompletes from existing tags (fetched from `/api/v1/articles/tags`)
- Allows selecting multiple tags
- Allows creating new tags by typing (not restricted to existing)
- General-purpose component for reuse in other parts of the UI

### Markdown Rendering
```javascript
// MarkdownRenderer.svelte
import { marked } from 'marked';
import DOMPurify from 'dompurify';

marked.setOptions({ gfm: true, breaks: true });

let renderedHtml = $derived.by(() => {
  if (!content) return '';
  const rawHtml = marked.parse(content);
  return DOMPurify.sanitize(rawHtml);
});
```

---

## Auth Integration

### Gallformers Auth Model
- **Unauth**: Can view published articles
- **Auth**: Can create/edit/publish any article
- **Super Admin**: Same as auth (no special article permissions)

### Author Field Behavior
- On create: Default to logged-in user's display name
- Editable: User can change for "ghost writing" scenarios
- Stored as text (not foreign key to user table)

### Placeholder for Initial Implementation
If auth system not ready when implementing articles:
1. Stub `isAuthenticated()` to return true in dev
2. Add real auth check later
3. Author field uses placeholder until user context available

---

## Migration: Existing ref/*.md Files

### One-time Import Script
```go
// cmd/migrate-articles/main.go
// Reads ref/*.md, extracts frontmatter, inserts into article table
```

**Frontmatter mapping**:
| V1 Field | V2 Field |
|----------|----------|
| title | title |
| date | created_at, published_at |
| updated | updated_at (if present, else use date) |
| description | description |
| author.name | author |
| (content) | content |

**Tags**: Not present in v1, leave empty or infer from filename.

**Tag handling**: Case-insensitive. Store lowercase, compare lowercase.

**Tag filtering implementation**: Use SQLite's `json_each()` for correct matching:
```sql
WHERE EXISTS (SELECT 1 FROM json_each(tags) WHERE LOWER(value) = LOWER(?))
```

**Slug**: Derived from filename, lowercased (e.g., `IDGuide.md` → `idguide`).

### Files to Import (7 total)
- contributing.md
- IDGuide.md
- patrons.md
- populusaphidkey.md
- populusmidgekey.md
- undescribedfaq.md
- vitisgallkey.md

### Post-Migration
- Keep `ref/*.md` files in repo until v1 fully removed
- V1 continues reading from files
- V2 reads from database

---

## Non-Goals (Deferred)

| Feature | Reason |
|---------|--------|
| Full-text search | Future work - SQLite FTS5 when needed |
| Glossary auto-linking | Needs proper design, disabled in v1 too |
| Image upload in articles | Use external URLs for now (same as v1) |
| Revision history | Not needed initially |
| Collaborative editing | Out of scope |
| Article categories (beyond tags) | Tags sufficient |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Auth system not ready | Stub auth, add real check later |
| Markdown XSS | DOMPurify sanitization (proven in oaks) |
| Slug collisions | Add uniqueness check, append number if needed |
| Migration data loss | Validate import, keep original files |
