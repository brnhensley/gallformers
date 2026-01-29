# About Page (V1)

**Route**: `/about`
**File**: `v1/pages/about.tsx`

## Summary

Project information page with co-founder profiles (Adam Kranz, Jeff Clark), list of administrator contributors, current site statistics (galls, hosts, sources count), funding information (NSF grant), and citation guidelines. Includes an easter egg accordion ("Dare You Click?").

---

## V1 vs V2 Comparison

### UI Layer

#### V1 Implementation (`v1/pages/about.tsx`)

**Layout & Structure:**
- Uses React Bootstrap components (`Row`, `Col`, `Card`, `Accordion`)
- Two-column grid layout for co-founders and administrators
- Bootstrap Card components for co-founder profiles with Card.Body, Card.Title, Card.Text, Card.Footer, Card.Link
- Accordion component for easter egg ("Dare You Click?")

**Content Sections (in order):**
1. "About Us" heading (h2)
2. Introduction paragraphs with glossary links (parasitism, inquiline, cecidiology)
3. GitHub link
4. Patreon link
5. "Contacting Us" (h4) - email, Twitter
6. "Our Co-founders" (h4) - Adam Kranz, Jeff Clark cards
7. "Administrators" (h4) with anchor `#administrators` - hardcoded list of 5 admins
8. "Current Site Stats" (h4) - generated timestamp + stats
9. "Funding" (h4) - NSF logo (200x200px) + grant info
10. "Citing Gallformers" (h4) - CC-BY license info, citation templates
11. Build ID display (small, muted text: `process.env.BUILD_ID`)
12. Easter egg accordion with "Gall Me Maybe" image

**Admin List (V1 - hardcoded):**
- Joshua C'deBaca (inaturalist link)
- Tim Frey (inaturalist link)
- Yann Kemper (inaturalist link)
- Kimberlie Sasan (inaturalist link)
- Ramsey Sullivan (inaturalist link)

**Stats Display:**
- Galls count, gall families count, gall genera count, undescribed count
- Hosts count, host families count, host genera count
- Sources count

#### V2 Implementation (`lib/gallformers_web/live/about_live.ex`)

**Layout & Structure:**
- Uses Tailwind CSS utility classes
- `prose prose-lg max-w-none` for typography
- Grid layout for co-founders: `grid grid-cols-1 md:grid-cols-2 gap-6`
- Custom card styling with shadow and rounded corners
- Button with phx-click for easter egg (not accordion)

**Content Sections (in order):**
1. "About Us" heading (h1, styled with `text-gf-maroon`)
2. Introduction paragraphs with glossary links (parasitism, inquiline, cecidiology)
3. GitHub link
4. Patreon link
5. "Contacting Us" (h2) - email, Twitter
6. "Our Co-founders" (h2) - Adam Kranz, Jeff Clark cards
7. "Administrators" (h2) with `id="administrators"` - dynamic list from database
8. "Current Site Stats" (h2) - generated timestamp + stats
9. "Funding" (h2) - NSF logo (128x128px via `w-32 h-32`) + grant info
10. "Citing Gallformers" (h2) - CC-BY license info, citation templates
11. **"Public API" (h2)** - NEW SECTION - links to `/api/docs`
12. Version info (App version + API version)
13. Easter egg button with toggle behavior

**Admin List (V2 - dynamic):**
- Fetched from database via `Accounts.list_users_for_about_page()`
- Filters users where `show_on_about == true`
- Links to user profile pages: `/user/{nickname}`
- Uses `display_name` with `nickname` fallback

**Stats Display:**
- Same stats as V1: galls, gall_families, gall_genera, undescribed, hosts, host_families, host_genera, sources
- Numbers formatted with `format_number/1` (adds commas)

### Business Logic

#### V1 Data Flow

```
v1/pages/about.tsx
    |
    +-- getStaticProps (line 253-260)
        |
        +-- getCurrentStats() from v1/libs/db/stats.ts (line 13-92)
            |
            +-- Raw SQL query via Prisma.$queryRaw
                - Counts galls (species where taxoncode='gall')
                - Counts gall-genera (distinct genus names via taxonomy join)
                - Counts gall-family (distinct family names via parent taxonomy)
                - Counts hosts (species where taxoncode='plant')
                - Counts host-genera
                - Counts host-family
                - Counts sources
                - Counts undescribed (gall where undescribed=1)
```

**Key V1 characteristics:**
- Static Site Generation (SSG) with 5-minute revalidation (ISR)
- Single optimized SQL query returns all stats at once
- Timestamp stored in props, not generated per-request
- Admins are hardcoded in JSX
- Build ID displayed via `process.env.BUILD_ID`

#### V2 Data Flow

```
lib/gallformers_web/live/about_live.ex
    |
    +-- mount/3 (line 12-30)
        |
        +-- get_site_stats() (line 38-49)
        |   |
        |   +-- Species.count_galls() (lib/gallformers/species.ex:131-136)
        |   +-- Hosts.count_hosts() (lib/gallformers/hosts.ex:56-61)
        |   +-- Sources.count_sources() (lib/gallformers/sources.ex:42-47)
        |   +-- count_families_for_taxoncode/1 (line 51-54) - SIMPLIFIED
        |   +-- count_genera_for_taxoncode/1 (line 56-59) - SIMPLIFIED
        |   +-- Species.count_undescribed_galls() (lib/gallformers/species.ex:142+)
        |
        +-- Accounts.list_users_for_about_page() (lib/gallformers/accounts.ex:252-257)
            |
            +-- Filters users by show_on_about == true
            +-- Orders by COALESCE(display_name, nickname)
```

**Key V2 characteristics:**
- LiveView with data loaded on mount
- Multiple separate queries instead of single raw SQL
- Timestamp generated fresh on each mount
- Admins loaded dynamically from database
- Version info from `Gallformers.Version` module (CalVer + git hash)

### Data Layer

#### V1 Stats Query (`v1/libs/db/stats.ts:14-79`)

Single optimized SQL query using UNION to get all stats:

```sql
SELECT 'hosts' AS type, count(*) AS count FROM species WHERE taxoncode = 'plant'
UNION
SELECT 'host-genera', count(DISTINCT t.name) FROM species s
    INNER JOIN speciestaxonomy st ON s.id = st.species_id
    INNER JOIN taxonomy t ON t.id = st.taxonomy_id
    WHERE s.taxoncode = 'plant' AND t.type = 'genus'
UNION
SELECT 'host-family', count(DISTINCT pt.name) FROM species s
    INNER JOIN speciestaxonomy st ON s.id = st.species_id
    INNER JOIN taxonomy t ON t.id = st.taxonomy_id
    INNER JOIN taxonomy pt ON t.parent_id = pt.id
    WHERE s.taxoncode = 'plant' AND pt.type = 'family'
-- ... similar for galls, sources, undescribed
```

#### V2 Stats Queries

**Multiple separate queries:**

1. `Species.count_galls()` - Simple count where taxoncode='gall'
2. `Hosts.count_hosts()` - Simple count where taxoncode='plant'
3. `Sources.count_sources()` - Simple count from source table
4. `count_families_for_taxoncode/1` - **SIMPLIFIED** - calls `Taxonomy.list_families() |> length()` (counts ALL families, not just those for galls/hosts)
5. `count_genera_for_taxoncode/1` - **SIMPLIFIED** - calls `Taxonomy.list_genera() |> length()` (counts ALL genera, not just those for galls/hosts)
6. `Species.count_undescribed_galls()` - Count via gall join where undescribed=true

**Important V2 Issue:** The `count_families_for_taxoncode` and `count_genera_for_taxoncode` functions have `_taxoncode` parameters that are ignored. They return counts of ALL families/genera in the taxonomy table, not filtered by whether they have galls or hosts. This means:
- V2 `gall_families` and `host_families` will be identical (and higher than V1)
- V2 `gall_genera` and `host_genera` will be identical (and higher than V1)

---

## Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Route** | `/about` | `/about` | Same | |
| **Framework** | Next.js SSG/ISR | Phoenix LiveView | Different | V1 pre-renders, V2 loads on mount |
| **CSS** | React Bootstrap | Tailwind CSS | Different | Visual parity maintained |
| **Heading levels** | h2, h4 | h1, h2, h3 | Different | V2 uses more semantic hierarchy |
| **Intro text** | Glossary links | Glossary links | Same | |
| **GitHub link** | Yes | Yes | Same | |
| **Patreon link** | Yes | Yes | Same | |
| **Contact section** | Email + Twitter | Email + Twitter | Same | |
| **Co-founder cards** | Bootstrap Card | Tailwind card | Same | Content identical |
| **Admin list** | Hardcoded (5 people) | Dynamic from DB | V2 Enhanced | Uses `show_on_about` flag |
| **Admin links** | iNaturalist only | Internal profile pages | Different | V2 links to `/user/{nickname}` |
| **Stats: galls** | Via raw SQL | Via `Species.count_galls()` | Same | |
| **Stats: gall families** | Filtered by taxoncode='gall' | ALL families | **V2 Bug** | V2 ignores taxoncode param |
| **Stats: gall genera** | Filtered by taxoncode='gall' | ALL genera | **V2 Bug** | V2 ignores taxoncode param |
| **Stats: hosts** | Via raw SQL | Via `Hosts.count_hosts()` | Same | |
| **Stats: host families** | Filtered by taxoncode='plant' | ALL families | **V2 Bug** | Same as gall families |
| **Stats: host genera** | Filtered by taxoncode='plant' | ALL genera | **V2 Bug** | Same as gall genera |
| **Stats: sources** | Via raw SQL | Via `Sources.count_sources()` | Same | |
| **Stats: undescribed** | `gall.undescribed=1` | Via join to gall table | Same | |
| **Number formatting** | None | Commas via `format_number/1` | V2 Enhanced | |
| **Funding section** | NSF logo + grant | NSF logo + grant | Same | |
| **NSF logo size** | 200x200px | 128x128px (`w-32 h-32`) | Different | V2 slightly smaller |
| **Citation section** | Two citation templates | Two citation templates | Same | |
| **Citation styling** | `className="citation"` | `bg-gray-50 font-mono` | Different | V2 has better visual distinction |
| **Public API section** | Not present | Links to `/api/docs` | V2 Enhanced | New feature |
| **Build/version info** | `BUILD_ID` env var | App version + API version | Different | V2 shows both versions |
| **Easter egg** | Bootstrap Accordion | Button + toggle | Different | Same functionality, different UI |
| **Easter egg image** | 300x532px | `max-w-xs` | Similar | |
| **Data loading** | SSG + ISR (5 min) | On mount (fresh) | Different | |
| **Caching** | 5 minute revalidation | No caching | Different | V1 more efficient |

---

## Key Findings

### V2 Missing Features

None - V2 actually has more features than V1.

### V2 Bugs

1. **Stats Family/Genera Counts Are Incorrect** (`lib/gallformers_web/live/about_live.ex:51-59`)
   - The `count_families_for_taxoncode/1` function ignores the taxoncode parameter
   - Returns count of ALL families in taxonomy table, not filtered by gall/host species
   - Same issue with `count_genera_for_taxoncode/1`
   - **Impact**: V2 will show the same (higher) number for both gall and host families/genera
   - **V1 Reference**: `v1/libs/db/stats.ts:22-68` shows correct filtered queries

### Implementation Differences

1. **Admin List Management**
   - V1: Hardcoded in JSX (static, requires code change to update)
   - V2: Dynamic from database with `show_on_about` user flag
   - V2 improvement: Admins can be added/removed via admin UI

2. **Admin Links**
   - V1: Links to external iNaturalist profiles
   - V2: Links to internal user profile pages (`/user/{nickname}`)
   - Different approach to user identity

3. **Data Loading Strategy**
   - V1: SSG with ISR (5-minute revalidation) - fewer DB queries, better performance
   - V2: Fresh data on every mount - multiple DB queries per page load
   - Performance impact depends on traffic

4. **Stats Query Efficiency**
   - V1: Single optimized SQL query with UNIONs
   - V2: 8 separate queries (could be reduced)

### Recommendations

1. **Fix V2 Family/Genera Stats** (High Priority)
   The `count_families_for_taxoncode` and `count_genera_for_taxoncode` functions need to be implemented properly to filter by species taxoncode. Should replicate V1's join logic:
   ```elixir
   # For gall families, need to:
   # 1. Join species (taxoncode='gall') to speciestaxonomy
   # 2. Join to taxonomy (genus)
   # 3. Join to parent taxonomy (family)
   # 4. Count distinct family names
   ```

2. **Consider Caching Stats** (Low Priority)
   V2 loads stats fresh on every mount. Consider caching or using a scheduled job to update stats periodically (like V1's ISR approach).

3. **Consolidate Stats Queries** (Low Priority)
   Could combine multiple simple count queries into a single query for efficiency.

4. **Admin iNaturalist Links** (Enhancement)
   V1 links admins to their iNaturalist profiles. V2 could add this alongside the internal profile link, or pull iNaturalist URL from user profile.
