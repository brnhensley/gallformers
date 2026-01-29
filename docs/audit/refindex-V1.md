# Reference Index Page Comparison: V1 vs V2

**Route**: `/refindex`
**Analyzed**: 2026-01-28

## Overview

The Reference Index page displays a list of reference articles with metadata. V1 uses static file-based content with Next.js SSG, while V2 uses database-stored articles with Phoenix LiveView.

---

## File Locations

| Layer | V1 | V2 |
|-------|-----|-----|
| **Page/View** | `v1/pages/refindex.tsx` | `lib/gallformers_web/live/ref_index_live.ex` |
| **Data Fetching** | `v1/libs/pages/refposts.ts` | `lib/gallformers/articles.ex` |
| **Type/Schema** | `v1/types/post.ts`, `v1/types/author.ts` | `lib/gallformers/articles/article.ex` |
| **Content Storage** | `v1/ref/*.md` (filesystem) | `articles` table (SQLite) |
| **Markdown Rendering** | `v1/libs/pages/mdtoHtml.ts` (remark) | `lib/gallformers/markdown.ex` (Earmark) |
| **Router** | Next.js file-based routing | `lib/gallformers_web/router.ex:135` |

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| **Route** | `/refindex` | `/refindex` | Same | |
| **Rendering** | SSG with hourly revalidation | LiveView (server-rendered) | Different | V2 is always fresh |
| **Content Source** | Markdown files in `v1/ref/` | Database `articles` table | Different | V2 is database-driven |
| **Article Fields** | title, date, slug, author, description, content | slug, title, author, description, content, tags, is_published, published_at | Enhanced | V2 adds tags, publication status |
| **Author Model** | Object: `{name, picture}` | String field | Simplified | V2 stores author as simple string |
| **Date Display** | From frontmatter `date` field | `published_at` or `inserted_at` | Different | V2 has explicit publish tracking |
| **Tag Filtering** | None | Tag-based filtering with counts | New in V2 | Filter chips with article counts |
| **Publication Status** | All articles published | `is_published` boolean | New in V2 | Draft/published workflow |
| **Empty State** | None (always has articles) | Empty state with icon | New in V2 | UX improvement |
| **Article Count** | Not shown | Shows count at bottom | New in V2 | "Showing X articles" |
| **Ordering** | Descending by date | Descending by `inserted_at` | Similar | V1 sorts by parsed date string |
| **Page Title** | "Gallformers Reference Library" | "Reference Library" | Slightly different | V2 is shorter |
| **Meta Description** | None | Full SEO metadata | New in V2 | V2 sets page_description |
| **Styling** | React Bootstrap | Tailwind CSS | Different | Complete redesign |
| **Preview Text** | Uses `description` field | Falls back to content preview | Enhanced | V2 strips markdown for preview |
| **Related Articles** | Not implemented | On article page via tags | New in V2 | Cross-linking feature |

---

## UI Layer Analysis

### V1 Implementation (`v1/pages/refindex.tsx:11-37`)

```tsx
const Index = ({ allPosts }: Props) => {
    return (
        <Container className="mx-0 mt-4">
            <h1 className="my-4">The Gallformers Reference Library</h1>
            {allPosts.map((p) => (
                <article key={p.slug}>
                    <header>
                        <Link href={`/ref/${p.slug}`}>
                            <h5>{p.title}</h5>
                        </Link>
                        <span className="small">
                            <em>{`${p.author.name} - ${p.date}`}</em>
                        </span>
                    </header>
                    <section>
                        <p className="small">{p.description}</p>
                    </section>
                </article>
            ))}
        </Container>
    );
};
```

**Characteristics:**
- Simple list layout with Bootstrap Container
- Author shown as `author.name` (nested object)
- Date displayed as raw string from frontmatter
- No filtering or empty states
- Minimal styling

### V2 Implementation (`lib/gallformers_web/live/ref_index_live.ex:95-206`)

**Characteristics:**
- Card-based layout with Tailwind shadows and hover effects
- Tag filter chips at top (lines 106-136)
- Empty state with icon and contextual message (lines 139-171)
- Article cards with:
  - Title as link (group hover underline)
  - Author and formatted date
  - Tag badges
  - Preview text (from description or stripped markdown content)
- Article count footer

**Tag Filtering UI:**
```elixir
<.link
  :for={tag_info <- @tags}
  patch={~p"/refindex?tag=#{tag_info.tag}"}
  class={[
    "px-3 py-1 rounded-full text-sm font-medium transition-colors",
    if(@selected_tag == tag_info.tag,
      do: "bg-gf-maroon text-white",
      else: "bg-gray-200 text-gray-700 hover:bg-gray-300"
    )
  ]}
>
  {tag_info.tag} ({tag_info.count})
</.link>
```

---

## Business Logic Analysis

### V1: Static Generation (`v1/pages/refindex.tsx:41-48`)

```tsx
export const getStaticProps = () => {
    const allPosts = getAllPosts(['title', 'date', 'slug', 'author', 'description']);
    return {
        props: { allPosts },
        revalidate: 60 * 60, // republish hourly
    };
};
```

- Uses ISR (Incremental Static Regeneration)
- Rebuilds page every hour
- No runtime filtering

### V2: LiveView with URL-based Filtering (`lib/gallformers_web/live/ref_index_live.ex:12-42`)

```elixir
def mount(_params, _session, socket) do
  tags = Articles.list_tags(published_only: true)
  {:ok, assign(socket, tags: tags, selected_tag: nil, articles: [])}
end

def handle_params(params, _uri, socket) do
  selected_tag = params["tag"]
  articles =
    if selected_tag do
      Articles.list_articles(published_only: true, tag: selected_tag)
    else
      Articles.list_published_articles()
    end
  {:noreply, assign(socket, selected_tag: selected_tag, articles: articles)}
end
```

- Real-time data loading
- URL-based tag filtering (`/refindex?tag=biology`)
- Only shows published articles on public page
- Uses `patch` navigation for filter changes (no full page reload)

### Content Preview Logic (V2 Only)

V2 includes fallback logic when no description is provided (`lib/gallformers_web/live/ref_index_live.ex:45-92`):

```elixir
defp article_preview(article) do
  if article.description && article.description != "" do
    article.description
  else
    content_preview(article.content)
  end
end

defp content_preview(content) when is_binary(content) do
  content
  |> strip_markdown()
  |> String.slice(0, 200)
  |> String.trim()
  |> then(fn preview ->
    if String.length(content) > 200, do: preview <> "...", else: preview
  end)
end
```

The `strip_markdown/1` function removes headings, bold, italic, links, images, inline code, and blockquotes to produce clean preview text.

---

## Data Layer Analysis

### V1: File-based Storage (`v1/libs/pages/refposts.ts`)

```typescript
const postsDirectory = join(process.cwd(), 'ref');

export function getPostBySlug(slug: string, fields: string[] = []) {
    const realSlug = sanitize(slug.replace(/\.md$/, ''));
    const fullPath = join(postsDirectory, `${realSlug}.md`);
    const fileContents = fs.readFileSync(fullPath, 'utf8');
    const { data, content } = matter(fileContents);
    // ... extract requested fields
}

export function getAllPosts(fields: string[] = []) {
    const slugs = getPostSlugs();
    const posts = slugs
        .map((slug) => getPostBySlug(slug, fields))
        .sort((post1, post2) => post1.date?.split('-').join()
            .localeCompare(post2.date?.split('-').join()))
        .reverse();
    return posts;
}
```

**Data Model (V1):**
```typescript
// v1/types/post.ts
type PostType = {
    slug: string;
    title: string;
    date: string;
    description: string;
    author: Author;  // { name: string; picture: string; }
    content: string;
};
```

**Example Frontmatter:**
```yaml
---
title: 'Gall Identification Guide'
date: '2021-04-17'
description: 'An introduction to identifying galls...'
author:
    name: Adam Kranz
---
```

### V2: Database Storage (`lib/gallformers/articles.ex`)

**Schema (`lib/gallformers/articles/article.ex:29-43`):**
```elixir
schema "articles" do
  field :slug, :string
  field :title, :string
  field :author, :string
  field :description, :string
  field :content, :string
  field :tags, Gallformers.Articles.TagsType, default: []
  field :is_published, :boolean, default: false
  field :published_at, :utc_datetime
  timestamps()
end
```

**Database Table (`priv/repo/structure.sql:253-255`):**
```sql
CREATE TABLE IF NOT EXISTS "articles" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "slug" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "author" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "tags" TEXT,  -- JSON array stored as string
  "is_published" INTEGER DEFAULT false NOT NULL,
  "description" TEXT,
  "published_at" TEXT,
  "inserted_at" TEXT NOT NULL,
  "updated_at" TEXT NOT NULL
);
CREATE UNIQUE INDEX "articles_slug_index" ON "articles" ("slug");
CREATE INDEX "articles_is_published_index" ON "articles" ("is_published");
```

**Tag Filtering Query (`lib/gallformers/articles.ex:43-50`):**
```elixir
defp maybe_filter_by_tag(query, tag) do
  where(
    query,
    [a],
    fragment("EXISTS (SELECT 1 FROM json_each(?) WHERE value = ?)", a.tags, ^tag)
  )
end
```

Uses SQLite's `json_each()` function for efficient tag array searching.

**Tag Listing with Counts (`lib/gallformers/articles.ex:275-291`):**
```elixir
def list_tags(opts \\ []) do
  published_only = Keyword.get(opts, :published_only, false)
  query = if published_only do
    from(a in Article, where: a.is_published == true, select: a.tags)
  else
    from(a in Article, select: a.tags)
  end

  query
  |> Repo.all()
  |> Enum.flat_map(fn tags -> tags || [] end)
  |> Enum.frequencies()
  |> Enum.map(fn {tag, count} -> %{tag: tag, count: count} end)
  |> Enum.sort_by(& &1.tag)
end
```

---

## Markdown Rendering Comparison

### V1 (`v1/libs/pages/mdtoHtml.ts`)

```typescript
import { remark } from 'remark';
import html from 'remark-html';

export default async function markdownToHtml(markdown: string) {
    const result = await remark().use(html).process(markdown);
    return result.toString();
}
```

- Uses remark + remark-html
- Async processing
- No additional features

### V2 (`lib/gallformers/markdown.ex`)

```elixir
@earmark_options %Earmark.Options{
  breaks: true,
  gfm: true,
  smartypants: false
}

def render(markdown) when is_binary(markdown) do
  case Earmark.as_html(markdown, @earmark_options) do
    {:ok, html, _warnings} ->
      {:ok, linkify_glossary_terms(html)}
    {:error, html, _errors} ->
      {:ok, linkify_glossary_terms(html)}
  end
end
```

- Uses Earmark with GFM support
- **Glossary auto-linking**: Terms are automatically linked to glossary definitions
- ETS caching for glossary terms (15-minute TTL)
- Handles HTML parsing errors gracefully (returns partial HTML)

---

## V2 Enhancements Not in V1

1. **Tag System**
   - Free-form tags stored as JSON array
   - Tag filtering with URL parameters
   - Tag counts displayed on chips
   - Filter to specific tag via `/refindex?tag=tagname`

2. **Publication Workflow**
   - `is_published` boolean for draft/publish states
   - `published_at` timestamp for publication date tracking
   - Drafts only visible to admins

3. **SEO Improvements**
   - Full page metadata (title, description, URL, JSON-LD on article pages)
   - Proper `<title>` handling via Phoenix assigns

4. **Content Preview Fallback**
   - If no description, generates preview from content
   - Strips markdown syntax for clean text
   - Truncates at 200 characters with ellipsis

5. **Related Articles**
   - On article detail page (`ref_article_live.ex:57-58`)
   - Based on shared tags
   - Limit of 5 related articles

6. **Empty State Handling**
   - Icon and message when no articles
   - Context-aware message for tag filters

7. **Admin Article Management**
   - Full CRUD via `admin/articles/*` routes
   - Rich text editor for content
   - Tag management

---

## Migration Considerations

### Data Migration Path

Existing V1 articles in `v1/ref/*.md`:
1. `IDGuide.md` - Gall Identification Guide (2021-04-17)
2. `contributing.md` - Contributing guide
3. `populusmidgekey.md` - Populus Midge Key
4. `undescribedfaq.md` - Undescribed FAQ
5. `vitisgallkey.md` - Vitis Gall Key
6. `populusaphidkey.md` - Populus Aphid Key
7. `patrons.md` - Patrons

**Migration steps:**
1. Parse frontmatter from each `.md` file
2. Map `author.name` to `author` string
3. Map `date` to `published_at`
4. Set `is_published: true` for all
5. Assign appropriate tags based on content
6. Insert into `articles` table

### Breaking Changes

1. **Author structure**: V1 uses `{name, picture}` object; V2 uses simple string
2. **Date field**: V1 uses `date` string; V2 uses `published_at` DateTime
3. **No picture support**: V2 author field is just the name

---

## Recommendations

1. **Article Migration Script**: Create a mix task to import V1 markdown articles into the database with proper field mapping.

2. **Tag Assignment**: During migration, analyze content to suggest appropriate tags (e.g., "identification", "key", "guide").

3. **Author Picture**: If author pictures are needed, consider adding a separate `author_image` field or linking to user profiles.

4. **Redirect Handling**: Ensure `/ref/[slug]` routes work for both old and new slugs if any slug format changes occur.

5. **Content Parity**: Verify all V1 articles are migrated and display correctly with V2 markdown rendering (especially any HTML in markdown).
