# Home Page (V1)

**Route**: `/`
**File**: `v1/pages/index.tsx`

## Summary

Welcome landing page for Gallformers. Displays a random gall from the database with image and links to main features: ID tool, reference library, explore data, and phenology tool. Includes a "Help Us Out" section with Patreon and contribution options.

## V1 vs V2 Comparison

### UI Layer

#### V1 UI Elements (v1/pages/index.tsx)

1. **Header/Welcome Section** (lines 16-21)
   - `<h1>` "Welcome to Gallformers"
   - Subtitle: "The place to identify and learn about galls on plants in the US and Canada."

2. **What is a Gall Card** (lines 23-35)
   - Card with header "What the heck is a gall?!"
   - Text explanation of plant galls
   - No link to learn more

3. **Things You Can Do Card** (lines 37-61)
   - Bulleted list of 4 links:
     - Identify Galls -> `/id`
     - Learn More About Galls -> `/refindex`
     - Explore the Data -> `/explore`
     - Phenology tool (external) -> `https://megachile.shinyapps.io/doycalc/`

4. **Random Gall Card** (lines 63-88)
   - Clickable image linking to `/gall/{id}`
   - Species name with italics, linked to gall page
   - Undescribed indicator (text "an undescribed species" if applicable)
   - Photo credit with:
     - Creator name with source link
     - License with optional license link

5. **Help Us Out Card** (lines 90-119)
   - List of 3 contribution options:
     - Patreon link (external)
     - Become an admin -> `/about#administrators`
     - GitHub link (external)

**V1 Layout**: React Bootstrap grid (12-column) with responsive breakpoints

#### V2 UI Elements (lib/gallformers_web/live/home_live.ex)

1. **Header/Welcome Section** (lines 128-141)
   - `<h1>` "Welcome to Gallformers"
   - **Enhanced**: Explanatory paragraph (moved from separate card)
   - **Added**: "Learn more" link to `/ref/idguide`

2. **Quick ID Tool Card** (lines 147-180)
   - **New in V2**: Interactive host plant typeahead for quick ID
   - "Find Galls" button that navigates to ID page with host pre-selected
   - Uses `.typeahead` component (lib/gallformers_web/components/form_components.ex)
   - Shows datacomplete status for hosts

3. **Things You Can Do Card** (lines 182-211)
   - **Changed to chip/pill buttons** instead of bulleted list
   - 4 quick action chips with icons:
     - Search (ph-magnifying-glass) -> `/globalsearch`
     - Identify (ph-crosshair) -> `/id`
     - Articles (ph-article) -> `/refindex`
     - Explore (ph-compass) -> `/explore`
   - **Removed**: External phenology tool link

4. **Help Us Out Card** (lines 214-244)
   - **Changed to chip/pill buttons** instead of list
   - Introductory text added
   - 3 contribution chips with icons:
     - Patreon (ph-heart)
     - Become an Admin (ph-users) -> `/about#administrators`
     - Contribute Code (ph-code) -> GitHub

5. **Random Gall Card** (lines 249-276)
   - Image with link to gall page
   - Species name in italics with "Undescribed" badge
   - Photo credit (creator only, simplified)
   - **Missing**: License information and license link
   - **Missing**: Source link for photographer
   - **Added**: Loading state ("Loading...")

6. **Stats Banner** (lines 279-303)
   - **New in V2**: Statistics display showing:
     - Gall count (with gf-gall icon)
     - Host plant count (with gf-host icon)
     - Source count (with gf-source icon)
     - Image count (with ph-image icon)

**V2 Layout**: Tailwind CSS grid with `lg:grid-cols-2` responsive layout

### Business Logic

#### V1 Data Fetching (v1/pages/index.tsx, v1/libs/db/gall.ts)

**Server-Side Props** (lines 127-135):
```typescript
export const getServerSideProps: GetServerSideProps = async () => {
    const gall = await getStaticPropsWith<RandomGall>(randomGall, 'gall');
    return {
        props: {
            randomGall: gall[0],
        },
    };
};
```

**randomGall Function** (v1/libs/db/gall.ts, lines 523-562):
- Raw SQL query joining gall, gallspecies, species, and image tables
- Filters for images where `default = true`
- Orders by `RANDOM()` with `LIMIT 1`
- Returns: id, name, undescribed, imagePath (via `makePath`), creator, license, sourceLink, licenseLink

**Image Path Construction** (v1/libs/images/images.ts, line 70):
```typescript
export const makePath = (path: string, size: ImageSize): string =>
    `${EDGE}/${path.replace(ORIGINAL, size)}`;
```
Uses CloudFront EDGE URL: `https://dhz6u1p7t6okk.cloudfront.net`

#### V2 Data Fetching (lib/gallformers_web/live/home_live.ex, lib/gallformers/species.ex)

**Mount Function** (lines 16-40):
- Defers data fetching until socket is connected (avoids double-fetch)
- Fetches `Species.random_gall()` and `fetch_stats()`
- Initial state shows zeros for stats, nil for random_gall

**random_gall Function** (lib/gallformers/species.ex, lines 29-57):
- Ecto query joining Gall, GallSpecies, Species, and Image
- Filters for images where `sort_order == 0` (not `default = true`)
- Orders by `fragment("RANDOM()")` with `limit: 1`
- Returns map with: id, name, undescribed, image_url, image_creator, image_license
- Constructs URL via `Image.base_url() <> "/" <> path`

**Stats Functions**:
- `Species.count_galls()` (lib/gallformers/species.ex, lines 130-137)
- `Hosts.count_hosts()` (lib/gallformers/hosts.ex, lines 55-62)
- `Sources.count_sources()` (lib/gallformers/sources.ex, lines 39-47)
- `Images.count_images()` (lib/gallformers/images.ex, lines 419-423)

**Host Search for Quick ID** (lines 73-81):
- `Hosts.search_hosts(query, 8)` - searches hosts by name with aliases
- Multi-word search support (e.g., "q alba" matches "Quercus alba")
- Returns datacomplete status for each host

### Data Layer

#### V1 Database Query (v1/libs/db/gall.ts, lines 526-534)

```sql
SELECT s.id as id, g.undescribed, s.name, i.*
FROM gall as g
INNER JOIN gallspecies as gs ON gs.gall_id = g.id
INNER JOIN species as s ON gs.species_id = s.id
INNER JOIN image as i ON i.species_id = s.id
WHERE i.`default` = true
ORDER BY RANDOM() LIMIT 1
```

**Data returned** (RandomGall type, v1/libs/api/apitypes.ts, lines 484-493):
- id: number
- name: string
- undescribed: boolean
- imagePath: string (full CloudFront URL)
- creator: string
- license: string
- sourceLink: string
- licenseLink: string

#### V2 Database Query (lib/gallformers/species.ex, lines 30-48)

```elixir
from g in Gall,
  join: gs in GallSpecies, on: gs.gall_id == g.id,
  join: s in Species, on: gs.species_id == s.id,
  join: i in Image, on: i.species_id == s.id,
  where: i.sort_order == 0,
  order_by: fragment("RANDOM()"),
  limit: 1,
  select: %{
    id: s.id,
    name: s.name,
    undescribed: g.undescribed,
    image_path: i.path,
    image_creator: i.creator,
    image_license: i.license
  }
```

**Data returned**:
- id: integer
- name: string
- undescribed: boolean
- image_path: string (just path, URL constructed after)
- image_url: string (full CDN URL, added in code)
- image_creator: string
- image_license: string
- **Missing**: sourcelink (photographer's source URL)
- **Missing**: licenselink (license URL)

### Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Welcome header | h1 + subtitle | h1 + paragraph | Same | Text reworded slightly |
| Gall definition | Separate card | Integrated in header | Different | V2 more compact |
| "Learn more" link | Not present | Links to /ref/idguide | V2 Enhanced | |
| Quick ID tool | Not present | Host typeahead + button | V2 Enhanced | New feature |
| Navigation links | Bulleted list | Icon chip buttons | Different | V2 more visual |
| Phenology tool link | Present (external) | Removed | V2 Missing | External tool link dropped |
| Random gall image | Clickable with link | Clickable with link | Same | |
| Species name display | Italic, linked | Italic, linked, with badge | V2 Enhanced | Undescribed badge |
| Photo credit - creator | With source link | Creator name only | V2 Missing | No link to source |
| Photo credit - license | Linked if available | Not displayed | V2 Missing | License info dropped |
| Stats banner | Not present | Galls/Hosts/Sources/Images | V2 Enhanced | New feature |
| Loading state | Not applicable (SSR) | Shows "Loading..." | Different | LiveView pattern |
| Responsive layout | Bootstrap grid | Tailwind grid | Different | Same functionality |
| Default image selection | `default = true` | `sort_order == 0` | Different | V2 uses sort order |

## Key Findings

### V2 Missing Features

1. **Phenology Tool Link**: V1 links to `https://megachile.shinyapps.io/doycalc/` for exploring seasonal timing of gall development. This is removed in V2.

2. **Random Gall Photo Attribution**:
   - V1 displays: creator name (linked to source), copyright symbol, license (linked if licenselink exists)
   - V2 displays: only "Photo: {creator}"
   - Missing: source link, license name, license link

3. **License Information**: V2's `random_gall()` fetches `image_license` but doesn't display it in the template. The query also doesn't fetch `sourcelink` or `licenselink` from the image table.

### Implementation Differences

1. **Default Image Detection**:
   - V1: Uses `image.default = true` field
   - V2: Uses `image.sort_order == 0`
   - These may not always be equivalent if sort_order isn't guaranteed to be 0 for default images

2. **Data Fetching Strategy**:
   - V1: Server-side rendering via `getServerSideProps` - data loaded before page render
   - V2: LiveView with connected check - shows loading state, then fetches
   - V2 avoids double-fetch by checking `connected?(socket)`

3. **Navigation Style**:
   - V1: Traditional links in a bulleted list
   - V2: Chip/pill buttons with icons - more modern, touch-friendly

4. **Quick ID Tool**:
   - V2 adds an interactive host picker on the home page
   - Allows users to jump directly to ID tool with host pre-selected
   - This is a significant UX improvement

### Recommendations

1. **Add phenology tool link back** - Either in the "Things You Can Do" section or as an external resources link. Consider if this is still a maintained/relevant tool.

2. **Restore full photo attribution** for the random gall:
   - Add `sourcelink` and `licenselink` to the `random_gall()` query
   - Display the license with link (like V1)
   - Link the creator name to the source URL (like V1)

3. **Verify image selection logic**: Ensure that `sort_order == 0` correctly identifies the default/primary image. May need to use `default = true` field if it's the canonical source.

4. **Consider adding format_number helper**: The V2 stats use `format_number(@stats.galls)` but this function should handle locale-specific number formatting (e.g., commas for thousands).
