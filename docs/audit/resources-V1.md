# Resources Page - V1 vs V2 Comparison

## Overview

| Attribute | V1 | V2 |
|-----------|----|----|
| **Route** | `/resources` | `/resources` |
| **File** | `v1/pages/resources/index.tsx` | `lib/gallformers_web/live/resources_live.ex` |
| **Framework** | Next.js (React) | Phoenix LiveView |
| **Rendering** | Static (no SSR/ISR) | LiveView |
| **Lines of Code** | 76 | 221 |

## UI Layer Analysis

### Page Structure

| Section | V1 | V2 | Notes |
|---------|----|----|-------|
| **Header/Title** | `<h1>` inline | `<h1>` with Tailwind styling | V2 has larger, styled header |
| **Intro Text** | None | Introduction paragraph about cecidiology | V2 adds context |
| **General Resources** | Section with 6 links | Reorganized into "Identification Tools" and "Learning Resources" | Different organization |
| **Books** | Section with 2 book recommendations | Removed | Books section not in V2 |
| **Non-North American** | Section with 1 link | Removed | Not present in V2 |
| **Online Databases** | Not present | Section with 4 links | New in V2 |
| **Community** | Not present | Section with 3 links | New in V2 |
| **Related Projects** | Not present | Section with 1 link (GitHub) | New in V2 |

### Internal Links Comparison

| Link | V1 | V2 |
|------|----|----|
| ID Guide (`/ref/IDGuide`) | Yes (line 16-17) | No |
| Filter Guide (`/filterguide`) | Yes (line 19-20) | Yes (lines 133-138) |
| Glossary (`/glossary`) | Yes (line 22-23) | Yes (lines 125-130) |
| Reference Library (`/refindex`) | Yes (line 25-26) | Yes (lines 141-146) as "Reference Articles" |
| ID Tool (`/id`) | No | Yes (lines 38-44) - new |

### External Links Comparison

| Link | V1 | V2 |
|------|----|----|
| iNaturalist gall hunting tips | Yes (line 28-29) | No |
| Oak identification journal | Yes (line 31-34) | No |
| Charley Eiseman site | Yes (line 43) | No |
| Tracks & Signs book (bookshop.org) | Yes (lines 44-48) | No |
| Russo's Western US guide | Yes (lines 51-53) | No |
| bladmineerders.nl (Europe) | Yes (lines 64-66) | No |
| Gall Phenology Tool (megachile.shinyapps.io) | No | Yes (lines 47-57) |
| iNaturalist main site | No | Yes (lines 67-76) |
| BugGuide | No | Yes (lines 78-89) |
| Biodiversity Heritage Library | No | Yes (lines 91-103) |
| Google Scholar | No | Yes (lines 104-116) |
| Galls of North America iNat project | No | Yes (lines 156-167) |
| Twitter @gallformers | No | Yes (lines 169-180) |
| Patreon | No | Yes (lines 182-193) |
| GitHub repository | No | Yes (lines 202-214) |

### Styling

| Aspect | V1 | V2 |
|--------|----|----|
| **Container** | React Bootstrap `<Container>` with padding | Tailwind `max-w-4xl mx-auto` |
| **Sections** | Bootstrap `<Row>/<Col>` | Tailwind sections with `mb-10` |
| **Cards** | None - plain `<ul>` lists | White rounded cards with shadow and dividers |
| **Link styling** | Default Next.js Link | Phoenix `.link` with `hover:underline` |
| **Descriptions** | None | Each link has descriptive text below it |

## Business Logic

| Aspect | V1 | V2 |
|--------|----|----|
| **Content Type** | 100% static | 100% static |
| **Data Fetching** | None | None |
| **getStaticProps** | No | N/A |
| **getServerSideProps** | No | N/A |
| **mount/0** | N/A | Yes - sets page metadata only |
| **handle_event** | N/A | None defined |
| **JavaScript hooks** | None | None |

## Data Layer

Both implementations are purely static with no database queries:

| Aspect | V1 | V2 |
|--------|----|----|
| **Database queries** | None | None |
| **Context calls** | None | None |
| **API calls** | None | None |
| **PubSub** | N/A | Not used |

## SEO/Metadata

| Aspect | V1 | V2 |
|--------|----|----|
| **Meta description** | `"Resources about plant galls"` (line 9) | `"External resources for learning about plant galls..."` (lines 14-16) |
| **Page title** | Not set (browser default) | `"Resources"` (line 13) |
| **page_url** | Not set | `"/resources"` (line 17) |
| **page_image** | Not set | `nil` (line 18) |
| **page_json_ld** | Not set | `nil` (line 19) |

## Detailed Comparison Table

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| Route | `/resources` | `/resources` | Matched | Same URL |
| Page title | Not set | "Resources" | V2 Better | V2 has proper title |
| Meta description | Brief | Detailed | V2 Better | V2 more descriptive |
| Intro text | None | Yes | V2 Better | V2 provides context |
| ID Guide link | Yes (`/ref/IDGuide`) | No | V1 Only | Missing in V2 |
| Filter Guide link | Yes | Yes | Matched | Same content |
| Glossary link | Yes | Yes | Matched | Same content |
| Reference Library | Yes | Yes | Matched | Same content |
| ID Tool link | No | Yes | V2 Better | New internal link |
| iNat tips links | Yes (2 links) | No | V1 Only | Specific gall-hunting advice |
| Books section | Yes (2 books) | No | V1 Only | Book recommendations lost |
| Non-NA resources | Yes | No | V1 Only | bladmineerders.nl link lost |
| Online databases | No | Yes (4 links) | V2 Better | New section |
| Community links | No | Yes (3 links) | V2 Better | Twitter, Patreon, iNat project |
| GitHub link | No | Yes | V2 Better | Open source visibility |
| Phenology tool | No | Yes | V2 Better | New external tool |
| Card styling | None | White cards | V2 Better | Better visual hierarchy |
| Link descriptions | None | Yes | V2 Better | Each link explained |
| Layout framework | Bootstrap | Tailwind | Changed | Different styling system |

## Summary

### V2 Improvements
1. **Better organization** - Content reorganized into logical sections (Identification Tools, Online Databases, Learning Resources, Community, Related Projects)
2. **Improved SEO** - Proper page title and detailed meta description
3. **Better UX** - Each link has descriptive text explaining what users will find
4. **Modern styling** - Card-based layout with visual hierarchy
5. **New content** - Added links to iNaturalist, BugGuide, Biodiversity Heritage Library, Google Scholar, Phenology Tool, community links (Twitter, Patreon), GitHub

### V2 Regressions (Missing Content from V1)
1. **ID Guide link** (`/ref/IDGuide`) - Internal gall identification guide not linked
2. **iNaturalist tips links** - Two helpful iNaturalist journal posts removed:
   - Tips for gall hunting (line 28-29 in V1)
   - Documenting trees for identification (line 31-34 in V1)
3. **Books section** - Book recommendations completely removed:
   - Eiseman & Charney's "Tracks & Signs of Insects" (lines 43-48 in V1)
   - Russo's "Plant Galls of the Western United States" (lines 51-53 in V1)
4. **Non-North American Resources** - Section removed:
   - bladmineerders.nl link for European gall ID (lines 64-66 in V1)

## Recommendations

### High Priority
1. **Add Books section to V2** - The book recommendations are valuable for users new to galls. Consider adding:
   - Eiseman & Charney's "Tracks & Signs" with bookshop.org link
   - Russo's Western US guide with Princeton Press link

2. **Add ID Guide link** - The internal `/ref/IDGuide` link should be added to either "Identification Tools" or "Learning Resources" section

### Medium Priority
3. **Add Non-North American Resources section** - The bladmineerders.nl link is valuable for users interested in European galls

4. **Add iNaturalist tip links** - The specific journal posts about gall hunting and oak documentation are helpful practical guides

### Low Priority
5. **Consider JSON-LD** - Could add structured data for the page (Organization or WebPage type)

## File References

### V1
- Main file: `v1/pages/resources/index.tsx` (76 lines)

### V2
- LiveView: `lib/gallformers_web/live/resources_live.ex` (221 lines)
- Route: `lib/gallformers_web/router.ex` (line 133)
