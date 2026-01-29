# Filter Guide Page Comparison: V1 vs V2

**Route**: `/filterguide`
**V1 File**: `v1/pages/filterguide.tsx` (lines 1-135)
**V2 File**: `lib/gallformers_web/live/filter_guide_live.ex` (lines 1-167)

## Summary

Educational page explaining ID tool filter terms. Displays definitions for filter categories used in gall identification: alignment, cells, detachable, forms, location, shape, texture, and walls.

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Route** | `/filterguide` | `/filterguide` | Complete | Same route |
| **Page Title** | "Filter Guide" | "Filter Guide" | Complete | Same title |
| **Meta Description** | "A Guide to all of the terms that used on the gallformers ID page." | "Guide to the filter terms used in the Gallformers gall identification tool - explanations of alignment, cells, forms, location, shape, texture, and walls." | Complete | V2 is more descriptive |
| **UI Layout** | React Bootstrap Accordion | Flat sections with headers | Different | V2 uses visible sections vs collapsible accordion |
| **Jump Navigation** | None | Yes - pill-style links to sections | Enhanced | V2 adds quick navigation |
| **Data Source** | Database via `getStaticProps` | Database via `IDTool` context | Complete | Both load from DB |
| **Filter: Alignment** | From DB | From DB | Complete | Same data source |
| **Filter: Cells** | From DB | From DB | Complete | Same data source |
| **Filter: Detachable** | Hardcoded JSX | Hardcoded HEEx | Complete | Both have static content |
| **Filter: Forms** | From DB | From DB | Complete | Same data source |
| **Filter: Location** | From DB | From DB | Complete | Same data source |
| **Filter: Shape** | From DB | From DB | Complete | Same data source |
| **Filter: Texture** | From DB | From DB | Complete | Same data source |
| **Filter: Walls** | From DB | From DB | Complete | Same data source |
| **Cells Note** | Links to `/glossary#inquiline` | Plain text, no link | **Gap** | V2 missing glossary link |
| **Sorting** | Client-side `localeCompare` | Elixir `Enum.sort_by/2` | Complete | Both sort alphabetically |
| **SEO** | Basic meta tags via `<Head>` | Full assigns for layout SEO | Complete | V2 integrated with layout |
| **Sitemap** | N/A | Included, priority 0.7 | Complete | V2 properly indexed |
| **Static Generation** | Yes (`getStaticProps`, revalidate: 1) | No (LiveView mount) | Different | See notes |

---

## Detailed Analysis

### 1. UI Layer

#### V1 Implementation (lines 44-113)
- Uses React Bootstrap `<Accordion>` component
- Each filter category is a collapsible `<Accordion.Item>`
- Content hidden by default, user clicks to expand
- Uses `<ListGroup>` for definition lists
- Bold term name with description inline

```tsx
<Accordion.Item eventKey="alignment">
    <Accordion.Header>Alignment</Accordion.Header>
    <Accordion.Body>
        <ListGroup>{filterFieldsToItems(alignments)}</ListGroup>
    </Accordion.Body>
</Accordion.Item>
```

#### V2 Implementation (lines 43-127)
- Uses flat sections with `<section>` elements and anchor IDs
- All content visible by default (no accordion)
- Adds jump navigation links at top (lines 52-62)
- Uses semantic `<dl>/<dt>/<dd>` for definitions
- Custom `filter_section` component for reusability (lines 149-165)

```elixir
<.filter_section
  id="alignment"
  title="Alignment"
  items={sort_by_field(@filter_fields.alignment)}
/>
```

**Assessment**: V2 has better accessibility with semantic HTML and visible content. The jump links improve navigation for long pages. However, the accordion pattern may be preferred on mobile for space savings.

### 2. Business Logic

#### V1 Data Fetching (lines 119-132)
- Uses `getStaticProps` for static site generation
- Fetches all filter fields at build time
- Uses `fp-ts` TaskEither for error handling
- Revalidates every 1 second (ISR)

```typescript
export const getStaticProps: GetStaticProps = async () => {
    return {
        props: {
            alignments: await mightFailWithArray<FilterField>()(getAlignments()),
            // ... other fields
        },
        revalidate: 1,
    };
};
```

#### V2 Data Fetching (lines 12-35)
- Fetches in LiveView `mount/3`
- Direct Ecto queries via `IDTool` context
- Data transformed in mount to `%{field, description}` format
- No caching (fresh on each page load)

```elixir
def mount(_params, _session, socket) do
  filter_fields = %{
    alignment:
      IDTool.list_alignments() |> Enum.map(&%{field: &1.alignment, description: &1.description}),
    // ... other fields
  }
```

**Assessment**: V1's static generation is more efficient for this content since filter definitions rarely change. V2 queries the database on every page load. Consider adding caching or moving to a controller-rendered page.

### 3. Data Layer

#### V1 Database Access (`v1/libs/db/filterfield.ts`)
- Uses Prisma ORM
- Each filter type has its own table (alignment, cells, form, etc.)
- Returns `FilterField` type with `id`, `field`, `description` (Option type)
- Queries ordered by field name

```typescript
export const getAlignments = (): TaskEither<Error, FilterField[]> => {
    const alignments = () =>
        db.alignment.findMany({
            orderBy: { alignment: 'asc' },
        });
    return pipe(TE.tryCatch(alignments, handleError), TE.map(adaptAlignments));
};
```

#### V2 Database Access (`lib/gallformers/id_tool.ex`, lines 199-224)
- Uses Ecto with SQLite
- Same table structure as V1
- Each schema has `field` + `description` columns
- Queries ordered by field name

```elixir
@spec list_alignments() :: [Alignment.t()]
def list_alignments, do: Repo.all(from a in Alignment, order_by: a.alignment)
```

**Assessment**: Data layer is functionally equivalent. Both use the same underlying database tables with the same schema structure.

### 4. Content Differences

#### Detachable Section (Hardcoded in both)
Both have identical content for the "Detachable" filter since it has only two values (Yes/No) with explanatory notes.

V1 (lines 63-80):
```tsx
<Item key="yes">
    <b>Yes -</b> the gall could be removed from the plant without destroying the tissue it's
    attached to (detachable).
</Item>
```

V2 (lines 80-104):
```elixir
<dt class="inline font-medium text-gray-900">Yes</dt>
<dd class="inline text-gray-700">
  – the gall could be removed from the plant without destroying the tissue it's attached to (detachable).
</dd>
```

#### Cells Section Note - **GAP IDENTIFIED**
V1 links "inquilines" to the glossary (line 58):
```tsx
<Link href="/glossary#inquiline">inquilines</Link>
```

V2 has plain text (line 77):
```elixir
note="If multiple larvae are found in one space, these may be inquilines rather than gall-inducers."
```

---

## Identified Gaps

### 1. Missing Glossary Link for "Inquilines"
- **V1**: Links "inquilines" to `/glossary#inquiline` in the Cells section note
- **V2**: Plain text without link
- **Priority**: Low (usability enhancement)
- **Fix**: Update the `note` content in `filter_section` or handle rich content in notes

### 2. No Content Caching
- **V1**: Uses static generation with ISR (revalidate: 1 second)
- **V2**: Queries database on every page load
- **Priority**: Low (filter definitions rarely change, page is simple)
- **Fix**: Consider adding ETS caching or using `cache_static_pages` if available

---

## V2 Enhancements Over V1

1. **Jump Navigation**: Pill-style links at top for quick section access
2. **Semantic HTML**: Uses `<dl>/<dt>/<dd>` instead of styled divs
3. **Better SEO Metadata**: More descriptive page description
4. **Sitemap Integration**: Properly indexed with priority 0.7
5. **Consistent Styling**: Uses Tailwind with project color tokens (gf-maroon)
6. **Reusable Components**: `filter_section` and `jump_link` function components

---

## File References

| Component | V1 Path | V2 Path |
|-----------|---------|---------|
| Main Page | `v1/pages/filterguide.tsx` | `lib/gallformers_web/live/filter_guide_live.ex` |
| DB Access | `v1/libs/db/filterfield.ts` | `lib/gallformers/id_tool.ex` |
| Alignment Schema | Prisma schema | `lib/gallformers/filter_fields/alignment.ex` |
| Cells Schema | Prisma schema | `lib/gallformers/filter_fields/cells.ex` |
| Form Schema | Prisma schema | `lib/gallformers/filter_fields/form.ex` |
| Location Schema | Prisma schema | `lib/gallformers/filter_fields/location.ex` |
| Shape Schema | Prisma schema | `lib/gallformers/filter_fields/shape.ex` |
| Texture Schema | Prisma schema | `lib/gallformers/filter_fields/texture.ex` |
| Walls Schema | Prisma schema | `lib/gallformers/filter_fields/walls.ex` |
| Router | N/A (file-based) | `lib/gallformers_web/router.ex:132` |
| Sitemap | N/A | `lib/gallformers_web/controllers/sitemap_controller.ex:52` |
| Navigation | N/A | `lib/gallformers_web/components/layouts.ex:65` |

---

## Recommendations

1. **Add glossary link for "inquilines"** in the Cells section note to match V1 behavior. This requires either:
   - Making the `note` attribute accept HEEx/HTML
   - Creating a special case for the Cells section with a custom note

2. **Consider caching** the filter field data if performance becomes a concern, though the current implementation is likely fine for this simple page.

3. **Accessibility audit**: Verify screen reader compatibility with the new section-based layout vs the accordion.

---

## Status: Complete with Minor Gap

The V2 implementation is functionally complete with all filter categories displaying their descriptions from the database. The only missing feature is the glossary link for "inquilines" in the Cells section note.
