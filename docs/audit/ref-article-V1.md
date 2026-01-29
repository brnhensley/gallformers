# Reference Article Page - V1 vs V2 Comparison

**V1 Route**: `/ref/[slug]`
**V2 Route**: `/ref/:slug`

## Summary

Displays individual reference articles from the reference library with rendered markdown content, metadata (title, author, date), and related article suggestions.

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Data Storage** | Markdown files in `v1/ref/` | Database (`articles` table) | Enhanced | V2 enables CRUD, draft/publish workflow |
| **Content Retrieval** | File system read via `gray-matter` | Ecto query by slug | Enhanced | V2 is more scalable |
| **Markdown Rendering** | `remark-html` (server-side) | `Earmark` library | Equivalent | Both render markdown to HTML |
| **Markdown Features** | Basic remark processing | GFM + glossary auto-linking | Enhanced | V2 auto-links glossary terms |
| **Content Sanitization** | DOMPurify (client-side) | None (server-rendered) | Different | V2 trusts admin-created content |
| **SEO Metadata** | Basic `<title>` only | Full SEO + JSON-LD | Enhanced | V2 has structured data |
| **Related Articles** | Not implemented | Tag-based suggestions | Enhanced | V2 shows up to 5 related articles |
| **Tags** | Frontmatter only (not displayed) | Displayed + filterable links | Enhanced | V2 tags link to `/refindex?tag=X` |
| **Draft Support** | No | Yes (is_published flag) | Enhanced | V2 admins can preview drafts |
| **Updated Date** | No | Shows if different from created | Enhanced | Better change tracking |
| **Description** | Frontmatter only | Displayed + auto-generated | Enhanced | V2 uses for SEO and previews |
| **Error Handling** | Next.js 404 page | Custom "not found" UI | Equivalent | Both handle missing articles |
| **Loading State** | "Loading..." text | N/A (LiveView mount) | Different | LiveView doesn't need loading states |
| **Rendering Mode** | Static (ISR hourly) | Server-side real-time | Different | V2 always fresh, V1 cached |
| **Admin Integration** | None | Full CRUD in `/admin/articles` | Enhanced | V2 has complete admin workflow |
| **Image Management** | Manual markdown | Integrated image browser/upload | Enhanced | V2 has S3 image workflow |
| **Author Info** | Name + picture in type | Name only in schema | Reduced | V2 simplified author model |

---

## File Locations

### V1 Files

| File | Purpose | Lines |
|------|---------|-------|
| `v1/pages/ref/[slug].tsx` | Page component + data fetching | 1-87 |
| `v1/components/ref/postBody.tsx` | Markdown content renderer with DOMPurify | 1-32 |
| `v1/components/ref/dateformatter.tsx` | Date formatting component | 1-26 |
| `v1/libs/pages/refposts.ts` | File system article retrieval | 1-51 |
| `v1/libs/pages/mdtoHtml.ts` | Markdown to HTML conversion | 1-7 |
| `v1/types/post.ts` | PostType definition | 1-12 |
| `v1/types/author.ts` | Author type definition | 1-6 |
| `v1/components/ref/markdown-styles.module.css` | Article styling | 1-19 |
| `v1/ref/*.md` | Article content files (7 files) | N/A |

### V2 Files

| File | Purpose | Lines |
|------|---------|-------|
| `lib/gallformers_web/live/ref_article_live.ex` | LiveView for article display | 1-250 |
| `lib/gallformers_web/live/ref_index_live.ex` | Reference library index | 1-207 |
| `lib/gallformers/articles.ex` | Articles context (business logic) | 1-301 |
| `lib/gallformers/articles/article.ex` | Article Ecto schema | 1-105 |
| `lib/gallformers/articles/tags_type.ex` | Custom Ecto type for JSON tags | 1-51 |
| `lib/gallformers/markdown.ex` | Markdown rendering with glossary links | 1-197 |
| `lib/gallformers_web/live/admin/article_live/index.ex` | Admin article list | 1-299 |
| `lib/gallformers_web/live/admin/article_live/form.ex` | Admin article editor | 1-1073 |
| `lib/gallformers_web/router.ex:135-136` | Route definitions | 2 lines |

---

## UI Layer Analysis

### V1 UI Implementation (`v1/pages/ref/[slug].tsx:22-42`)

```tsx
<article className="m-4">
    <Head>
        <title>{post.title}</title>
    </Head>
    <h1 className="my-2">{post.title}</h1>
    <em>
        <DateFormatter dateString={post.date} /> - {post.author.name}
    </em>
    <hr />
    <PostBody content={post.content} />
</article>
```

**Features**:
- Simple article wrapper with margin
- Title in browser tab only
- Date and author on single line
- Horizontal rule separator
- PostBody component handles sanitization

### V2 UI Implementation (`lib/gallformers_web/live/ref_article_live.ex:137-249`)

**Features**:
- Draft preview banner for admins (lines 166-184)
- Back link to reference library (lines 187-202)
- Title with `text-gf-maroon` styling (line 206)
- Author and date with separator dots (lines 207-214)
- Updated date shown when different (lines 211-213)
- Clickable tag chips linking to filtered index (lines 215-223)
- Prose styling via Tailwind (`prose prose-lg`) (line 227)
- Related articles section with cards (lines 232-244)
- Custom 404 UI with illustration (lines 141-163)

### UI Enhancements in V2

1. **Tags as Navigation**: Tags are clickable and filter the reference index
2. **Related Articles**: Shows up to 5 articles sharing tags
3. **Draft Indicator**: Yellow banner for admin draft preview
4. **Visual Hierarchy**: Better typography with consistent styling
5. **Responsive Layout**: `max-w-4xl` container with proper spacing

---

## Business Logic Analysis

### V1 Content Loading (`v1/libs/pages/refposts.ts:13-41`)

```typescript
export function getPostBySlug(slug: string, fields: string[] = []) {
    const realSlug = sanitize(slug.replace(/\.md$/, ''));
    const fullPath = join(postsDirectory, `${realSlug}.md`);
    const fileContents = fs.readFileSync(fullPath, 'utf8');
    const { data, content } = matter(fileContents);
    // Returns only requested fields
}
```

**Characteristics**:
- File system based storage
- `sanitize-filename` for security
- `gray-matter` parses frontmatter
- Field filtering for performance
- Throws on missing file

### V2 Content Loading (`lib/gallformers/articles.ex:126-131`)

```elixir
def get_article_by_slug(slug) do
  Repo.get_by(Article, slug: slug)
end
```

**Characteristics**:
- Database query via Ecto
- Returns nil on not found (no exception)
- Full record always loaded
- Supports complex queries (related articles)

### V2 Related Articles (`lib/gallformers/articles.ex:240-261`)

```elixir
def list_related_articles(%Article{} = article, opts \\ []) do
  limit = Keyword.get(opts, :limit, 5)

  if article.tags == [] do
    []
  else
    tags_json = Jason.encode!(article.tags)

    from(a in Article,
      where: a.id != ^article.id and a.is_published == true,
      where: fragment(
        "EXISTS (SELECT 1 FROM json_each(?) WHERE value IN (SELECT value FROM json_each(?)))",
        a.tags, ^tags_json
      ),
      order_by: [desc: a.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end
end
```

**Note**: Uses SQLite JSON functions for tag intersection - a capability V1 doesn't have.

---

## Data Layer Analysis

### V1 Data Model (`v1/types/post.ts`)

```typescript
type PostType = {
    slug: string;
    title: string;
    date: string;
    description: string;
    author: Author;
    content: string;
};

type Author = {
    name: string;
    picture: string;
};
```

### V2 Data Model (`lib/gallformers/articles/article.ex:29-43`)

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

### Schema Differences

| Field | V1 | V2 | Notes |
|-------|----|----|-------|
| `slug` | From filename | Generated from title | V2 auto-generates |
| `title` | Frontmatter | Database field | Equivalent |
| `date` | Frontmatter string | `published_at` datetime | V2 more precise |
| `description` | Frontmatter | Database field | Equivalent |
| `author` | Object with name/picture | String | V2 simplified |
| `content` | Markdown body | Database field | Equivalent |
| `tags` | Not in V1 schema | JSON array | V2 addition |
| `is_published` | N/A | Boolean | V2 draft support |
| `published_at` | N/A | Datetime | V2 addition |
| `inserted_at` | N/A | Timestamp | V2 auto |
| `updated_at` | N/A | Timestamp | V2 auto |

---

## Markdown Processing Comparison

### V1 Markdown (`v1/libs/pages/mdtoHtml.ts`)

```typescript
import { remark } from 'remark';
import html from 'remark-html';

export default async function markdownToHtml(markdown: string) {
    const result = await remark().use(html).process(markdown);
    return result.toString();
}
```

**Features**:
- Basic remark processing
- No syntax highlighting
- No glossary integration
- Client-side DOMPurify sanitization

### V2 Markdown (`lib/gallformers/markdown.ex`)

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

**Features**:
- GFM (GitHub Flavored Markdown) support
- Line breaks preserved
- Glossary term auto-linking with ETS cache
- Graceful error handling (returns partial HTML)
- No client-side sanitization needed

### Glossary Auto-Linking (V2 Only)

```elixir
defp linkify_word(html, word, word_map) do
  original_word = Map.get(word_map, word)
  anchor = String.downcase(original_word) |> URI.encode()

  pattern = ~r/(?<![<\/\w])(?<!\w)\b(#{Regex.escape(word)})\b(?![^<]*>)(?![^<]*<\/a>)/i

  Regex.replace(pattern, html, fn _full, match ->
    ~s(<a href="/glossary##{anchor}" class="glossary-link" title="View definition">#{match}</a>)
  end)
end
```

---

## SEO Comparison

### V1 SEO

```tsx
<Head>
    <title>{post.title}</title>
</Head>
```

**Limited to**: Page title only

### V2 SEO (`lib/gallformers_web/live/ref_article_live.ex:56-88, 102-129`)

```elixir
# Page metadata
assign(socket,
  page_title: article.title,
  page_description: page_description,
  page_url: "/ref/#{article.slug}",
  page_json_ld: article_json_ld(article),
  page_noindex: noindex
)

# JSON-LD structured data
defp article_json_ld(article) do
  %{
    "@context" => "https://schema.org",
    "@type" => "Article",
    "headline" => article.title,
    "author" => %{
      "@type" => "Person",
      "name" => article.author
    },
    "datePublished" => date_published,
    "dateModified" => NaiveDateTime.to_iso8601(article.updated_at),
    "publisher" => %{
      "@type" => "Organization",
      "name" => "Gallformers",
      "url" => "https://gallformers.org"
    }
  }
end
```

**V2 Includes**:
- Page title
- Meta description (auto-generated if not provided)
- Canonical URL
- JSON-LD Article schema
- `noindex` for draft articles

---

## Admin Workflow (V2 Only)

V2 provides a complete admin interface at `/admin/articles`:

### Features (`lib/gallformers_web/live/admin/article_live/form.ex`)

1. **Edit/Preview Tabs**: Live markdown preview with glossary linking
2. **Tag Management**: Multi-select dropdown with autocomplete
3. **Image Integration**:
   - Upload images directly to S3
   - Browse existing article images
   - Insert with alt text, caption, size options
4. **Draft/Publish Workflow**: Toggle publication status
5. **Auto-slug Generation**: From title if not specified
6. **Delete with Confirmation**: Modal confirmation

### Admin Routes

```elixir
live "/articles", Admin.ArticleLive.Index, :index
live "/articles/new", Admin.ArticleLive.Form, :new
live "/articles/:id", Admin.ArticleLive.Form, :edit
```

---

## Recommendations

### Migration Complete

The V2 implementation is a significant enhancement over V1:

1. **Database storage** enables proper CRUD operations
2. **Draft support** allows content review before publishing
3. **Tag system** improves content organization and discovery
4. **Related articles** keeps users engaged
5. **Glossary integration** provides educational value
6. **Full SEO** improves search visibility
7. **Admin interface** streamlines content management

### Considerations

1. **Author pictures**: V2 removed author pictures. If needed, could add back via user profile lookup.
2. **Content migration**: V1 markdown files would need to be imported to database with appropriate tags.
3. **URL compatibility**: Routes are identical (`/ref/:slug`), ensuring backward compatibility.

### Data Migration Required

To complete migration, the 7 markdown files in `v1/ref/` need to be imported:
- `IDGuide.md`
- `contributing.md`
- `populusmidgekey.md`
- `undescribedfaq.md`
- `vitisgallkey.md`
- `populusaphidkey.md`
- `patrons.md`
