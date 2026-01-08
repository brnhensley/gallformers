# Capability: Public Site

Public-facing pages for gallformers.org that do not require authentication.

## ADDED Requirements

### Requirement: Home Page

The system SHALL display a home page at `/` that includes:
- Welcome message explaining what galls are
- Navigation links to key features (ID tool, reference articles, explore)
- A random gall with image, name, and attribution
- Information about contributing to the project

#### Scenario: Home page loads with random gall
- **WHEN** a user visits `/`
- **THEN** the page displays a random gall from the database
- **AND** the gall image, name, and photo attribution are shown
- **AND** clicking the gall links to its detail page

---

### Requirement: Gall Detail Page

The system SHALL display gall species information at `/gall/{id}` including:
- Species name (italicized, with undescribed indicator if applicable)
- Taxonomic hierarchy (family, genus)
- Host plant associations with links
- Morphological characteristics (shape, color, texture, location, etc.)
- Image gallery with attribution
- Geographic range map
- Source citations
- Related galls (species sharing the same binomial name prefix, e.g., "Andricus quercuscalifornicus" and "Andricus quercuscalifornicus asexual")
- External links to iNaturalist, BugGuide, Google Scholar, BHL

Host associations SHALL be sorted alphabetically by name.

#### Scenario: Gall detail page displays all information
- **WHEN** a user visits `/gall/{id}` with a valid gall ID
- **THEN** all species information is displayed
- **AND** host names link to their detail pages
- **AND** taxonomic names link to their detail pages

#### Scenario: Invalid gall ID returns 404
- **WHEN** a user visits `/gall/{id}` with an invalid ID
- **THEN** a 404 page is displayed

---

### Requirement: Host Detail Page

The system SHALL display host plant information at `/host/{id}` including:
- Plant name (italicized)
- Taxonomic hierarchy
- Common names/aliases
- Associated galls with links (sorted alphabetically by name)
- Geographic range map
- Source citations

#### Scenario: Host detail page displays associated galls
- **WHEN** a user visits `/host/{id}` with a valid host ID
- **THEN** all galls associated with this host are listed
- **AND** gall names link to their detail pages

#### Scenario: Invalid host ID returns 404
- **WHEN** a user visits `/host/{id}` with an invalid ID
- **THEN** a 404 page is displayed

---

### Requirement: Taxonomy Pages

The system SHALL display taxonomy pages at:
- `/family/{id}` - Family detail with genera and species
- `/genus/{id}` - Genus detail with species
- `/section/{id}` - Section detail with species

Each page SHALL show:
- Taxonomy name and description
- Child taxa or species list with links

#### Scenario: Family page lists genera
- **WHEN** a user visits `/family/{id}` with a valid family ID
- **THEN** all genera in the family are listed with links

#### Scenario: Invalid taxonomy ID returns 404
- **WHEN** a user visits `/family/{id}`, `/genus/{id}`, or `/section/{id}` with an invalid ID
- **THEN** a 404 page is displayed

---

### Requirement: Source Detail Page

The system SHALL display source/reference information at `/source/{id}` including:
- Citation details (author, title, publication, year)
- DOI or URL if available
- Species associated with this source

#### Scenario: Source page lists associated species
- **WHEN** a user visits `/source/{id}` with a valid source ID
- **THEN** all species citing this source are listed with links

---

### Requirement: Place Detail Page

The system SHALL display geographic place information at `/place/{id}` including:
- Place name and code
- Species with ranges including this place

#### Scenario: Place page lists species in range
- **WHEN** a user visits `/place/{id}` with a valid place ID
- **THEN** all species with this place in their range are listed

---

### Requirement: ID Tool

The system SHALL provide a gall identification tool at `/id` that allows users to filter galls by:
- Host plant (typeahead selection)
- Genus (typeahead selection)
- Location on plant (leaf, stem, bud, etc.)
- Detachability
- Texture
- Alignment
- Walls
- Cells
- Shape
- Color
- Season
- Form
- Undescribed status
- Geographic place

Filter state SHALL be persisted in URL query parameters for shareability.

#### Scenario: Filter by host plant
- **WHEN** a user selects a host plant from the typeahead
- **THEN** only galls associated with that host are shown
- **AND** the URL query parameter is updated

#### Scenario: Multiple filters combine with AND logic
- **WHEN** a user selects multiple filter criteria
- **THEN** only galls matching ALL criteria are shown

#### Scenario: Clear filters
- **WHEN** a user clears all filters
- **THEN** all galls are shown
- **AND** URL query parameters are removed

#### Scenario: Share filtered results via URL
- **WHEN** a user copies the URL with filter parameters
- **AND** another user visits that URL
- **THEN** the same filters are applied and same results shown

---

### Requirement: Global Search

The system SHALL provide a global search at `/globalsearch` that searches across:
- Species (by name)
- Aliases (results merged into species)
- Sources (by author, title)
- Glossary entries (by word, definition)
- Places (by name, code)
- Taxa (by name, description)

Results SHALL be displayed in a single sortable table with two columns:
- **Type**: Icon indicating result type
- **Name**: Linked to the appropriate detail page

Type icons (SVG images):
| Type | Icon | Size |
|------|------|------|
| Gall | `cynipid_R.svg` | 45x45 |
| Host/Plant | `host.svg` | 25x25 |
| Glossary entry | `entry.svg` | 25x25 |
| Source | `source.svg` | 25x25 |
| Genus/Section/Family | `taxon.svg` | 25x25 |
| Place | `place.svg` | 25x25 |

Results are NOT grouped into sections - all types appear in a single mixed list.

#### Scenario: Search returns results from multiple types
- **WHEN** a user searches for "oak"
- **THEN** results include matching species, hosts, and sources
- **AND** each result displays a type icon and linked name

#### Scenario: Empty search shows no results
- **WHEN** a user submits an empty search
- **THEN** no results are shown

---

### Requirement: Explore Page

The system SHALL provide an explore/browse page at `/explore` with:
- Tree view of galls organized by family → genus → species
- Tree view of undescribed galls
- Tree view of hosts organized by family → genus → species
- Tab navigation between views

#### Scenario: Browse galls by taxonomy
- **WHEN** a user expands a family in the galls tree
- **THEN** genera within that family are shown
- **WHEN** a user expands a genus
- **THEN** species within that genus are shown
- **WHEN** a user clicks a species
- **THEN** they navigate to the species detail page

---

### Requirement: Static Information Pages

The system SHALL provide static information pages:
- `/about` - About gallformers, team, contact info
- `/resources` - External resources and links
- `/filterguide` - Guide to using filter fields

#### Scenario: About page displays team info
- **WHEN** a user visits `/about`
- **THEN** information about gallformers and the team is displayed

---

### Requirement: Glossary Page

The system SHALL provide a dynamic glossary page at `/glossary` that:
- Loads glossary entries from the database
- Displays terms alphabetically in a sortable table
- Auto-hyperlinks glossary terms within definitions (cross-linking within the glossary page)
- Provides anchor links for direct navigation to terms (e.g., `/glossary#term`)
- Shows an Edit button next to each glossary entry for authenticated admin users (links to `/admin/glossary?id={entryId}`)

**Note:** Cross-linking glossary terms in other content pages (gall descriptions, etc.) is out of scope for this spec and requires a separate design.

#### Scenario: Glossary displays all terms
- **WHEN** a user visits `/glossary`
- **THEN** all glossary terms are loaded from the database
- **AND** terms are displayed alphabetically with definitions
- **AND** terms within definitions link to their own entries

#### Scenario: Direct link to glossary term
- **WHEN** a user visits `/glossary#detachable`
- **THEN** the page scrolls to the "detachable" term

---

### Requirement: 404 Page

The system SHALL display a user-friendly 404 page for invalid URLs that:
- Indicates the page was not found
- Provides navigation options (home, search)

#### Scenario: Invalid URL shows 404
- **WHEN** a user visits a non-existent URL
- **THEN** the 404 page is displayed

---

### Requirement: URL Structure Preservation

The system SHALL preserve the exact URL structure for SEO:
- `/gall/{id}` - numeric ID
- `/host/{id}` - numeric ID
- `/family/{id}` - numeric ID
- `/genus/{id}` - numeric ID
- `/source/{id}` - numeric ID
- `/place/{id}` - numeric ID
- `/section/{id}` - numeric ID

#### Scenario: URLs match current site
- **WHEN** a user visits a URL from the current site
- **THEN** the v2 site handles the same URL
- **AND** displays the same content

---

### Requirement: SEO Metadata

Each page SHALL include:
- Descriptive `<title>` tag
- Meta description
- Open Graph tags for social sharing

#### Scenario: Species pages have descriptive titles
- **WHEN** a user visits `/gall/{id}`
- **THEN** the page title includes the species name
- **AND** the meta description summarizes the gall characteristics

---

### Requirement: Mobile Responsiveness

All pages SHALL be responsive and usable on:
- Desktop (1200px+)
- Tablet (768px - 1199px)
- Mobile (< 768px)

#### Scenario: ID tool usable on mobile
- **WHEN** a user visits `/id` on a mobile device
- **THEN** filter controls are accessible
- **AND** results are displayed in a scrollable format

---

### Requirement: Geographic Range Map

Species detail pages SHALL display a geographic range map showing:
- US states and Canadian provinces
- Highlighted regions where species is present (green)
- Non-highlighted regions where species is absent (white)

The map component SHALL be implemented as a shared component (`RangeMap.svelte`) that supports both view-only mode (public pages) and editable mode (admin pages - see `add-svelte-admin`).

#### Scenario: Range map shows species distribution
- **WHEN** a user views a gall detail page
- **THEN** the range map highlights states/provinces where the gall is found in green
- **AND** states/provinces not in range are shown in white

#### Scenario: Hover shows place name
- **WHEN** a user hovers over a state/province on the map
- **THEN** a tooltip displays the place code and name

---

### Requirement: Image Gallery

Species detail pages SHALL display images with:
- Carousel navigation between images
- Photo attribution (creator, license)
- Link to original source
- Lightbox view for larger display
- Default image sorted first, then grouped by source

When a species has no images, a placeholder image SHALL be displayed:
- Gall species: gall-specific placeholder image
- Host species: host-specific placeholder image

#### Scenario: Navigate between images
- **WHEN** a user clicks next/previous on the image gallery
- **THEN** the next/previous image is displayed
- **AND** attribution updates to match the current image

#### Scenario: Species with no images
- **WHEN** a user views a species page that has no images
- **THEN** a placeholder image appropriate to the species type is displayed
- **AND** no carousel navigation controls are shown

---

### Requirement: External Links

Species detail pages SHALL display external research links including:
- iNaturalist (species search or Gallformers Code for undescribed)
- BugGuide (species search)
- Google Scholar (academic papers)
- Biodiversity Heritage Library (historical literature)

For undescribed species, only iNaturalist SHALL be shown with the Gallformers Code observation field link.

**URL formats for described species** (using binomial name only - first two words of species name):
- iNaturalist: `https://www.inaturalist.org/search?q={genus}%20{species}`
- BugGuide: `https://bugguide.net/index.php?q=search&keys={genus}%20{species}&search=Search`
- Google Scholar: `https://scholar.google.com/scholar?hl=en&q={genus}%20{species}`
- BHL: `https://www.biodiversitylibrary.org/search?SearchTerm={genus}%20{species}&SearchCat=M&return=ADV#/names`

**URL format for undescribed species** (using Gallformers Code - second word of species name):
- iNaturalist: `https://www.inaturalist.org/observations?verifiable=any&place_id=any&field:Gallformers%20Code={code}`

Example: For "Undescribed oakleafgall", the code is "oakleafgall".

#### Scenario: External links for described species
- **WHEN** a user views a described gall species page
- **THEN** links to iNaturalist, BugGuide, Google Scholar, and BHL are displayed
- **AND** each link searches for the species name on the respective site

#### Scenario: External links for undescribed species
- **WHEN** a user views an undescribed gall species page
- **THEN** only an iNaturalist link is displayed
- **AND** the link searches by Gallformers Code observation field

---

### Requirement: Admin Edit Links

Public pages SHALL display Edit buttons/links for authenticated admin users that navigate to the corresponding admin page:
- Gall detail → Edit gall, Edit gall-host mappings
- Host detail → Edit host
- Source detail → Edit source
- Glossary entries → Edit entry
- Taxonomy pages → Edit taxonomy (super admin only)

Edit buttons SHALL be hidden for unauthenticated users.

#### Scenario: Admin sees Edit buttons
- **WHEN** an authenticated admin views a gall detail page
- **THEN** Edit buttons are displayed next to editable sections
- **AND** clicking Edit navigates to the admin edit page for that entity

#### Scenario: Public user does not see Edit buttons
- **WHEN** an unauthenticated user views a gall detail page
- **THEN** no Edit buttons are displayed

---

### Requirement: Data Completeness Indicator

Gall and host detail pages SHALL display a data completeness indicator showing whether all relevant sources have been incorporated:
- **Complete**: All sources have been added and data is comprehensive
- **Incomplete**: Data is still being added, some information may be missing

The indicator SHALL be accessible:
- Use an icon with visible text label (not emoji-only)
- Include a tooltip with detailed explanation
- Meet WCAG color contrast requirements

#### Scenario: Complete data indicator
- **WHEN** a user views a species page with `datacomplete = true`
- **THEN** a "Data complete" indicator with checkmark icon is displayed
- **AND** hovering shows tooltip explaining completeness status

#### Scenario: Incomplete data indicator
- **WHEN** a user views a species page with `datacomplete = false`
- **THEN** an "Incomplete data" indicator with question/info icon is displayed
- **AND** hovering shows tooltip explaining that data is still being added

---

### Requirement: Undescribed Species Indicator

Gall detail pages for undescribed species SHALL display:
- A prominent warning message: "The inducer of this gall is unknown or undescribed."
- A "Copy gallformers code" button that copies the species code to clipboard

The gallformers code is used for tagging observations on iNaturalist with the Gallformers Code observation field.

#### Scenario: Undescribed species shows warning and copy button
- **WHEN** a user views a gall page where `undescribed = true`
- **THEN** a warning message about the undescribed status is displayed
- **AND** a "Copy gallformers code" button is shown

#### Scenario: Copy gallformers code to clipboard
- **WHEN** a user clicks "Copy gallformers code"
- **THEN** the species code is copied to the clipboard
- **AND** a success toast/notification confirms the copy

---

### Requirement: Phenology Tool Link

The system SHALL display a link to the external phenology tool (megachile.shinyapps.io/doycalc) that allows users to explore seasonal timing of gall development and emergence.

The link SHALL appear on:
- Home page (in the "Stuff you can do" section)
- Gall detail pages (prominently near the top)

#### Scenario: Phenology link on home page
- **WHEN** a user visits the home page
- **THEN** a link to the phenology tool is displayed in the navigation/features section

#### Scenario: Phenology link on gall page
- **WHEN** a user visits a gall detail page
- **THEN** a link to the phenology tool is displayed near the top of the page
- **AND** the link opens in a new tab

---

### Requirement: Site Layout

All public pages SHALL be wrapped in a consistent site layout that includes:

**Header:**
- Gallformers logo (links to home)
- Navigation links: ID Tool, Explore, Reference Articles, Glossary, About
- Global search input
- Login/account link (for admin access)

**Note:** The "Reference Articles" link SHALL display a stub "Coming Soon" page until `add-articles-system` is implemented.

**Footer:**
- Copyright notice
- Links to GitHub, Patreon, contact
- License information

The layout SHALL be responsive, adapting navigation to mobile-friendly format (e.g., hamburger menu) on smaller screens.

#### Scenario: Header navigation
- **WHEN** a user visits any public page
- **THEN** the header with logo, navigation, and search is displayed
- **AND** clicking the logo navigates to the home page

#### Scenario: Global search from header
- **WHEN** a user enters a search term in the header search box and submits
- **THEN** they are navigated to `/globalsearch?q={term}`

#### Scenario: Mobile navigation
- **WHEN** a user views the site on a mobile device
- **THEN** navigation collapses into a hamburger menu
- **AND** tapping the menu reveals navigation links

---

### Requirement: Loading and Error States

All pages that fetch data SHALL display appropriate loading and error states:

**Loading:**
- Display a loading indicator (spinner or skeleton) while data is being fetched
- Maintain layout structure to prevent layout shift when data loads

**Error:**
- Display a user-friendly error message if data fails to load
- Provide a retry option where appropriate
- Log errors for debugging (not visible to users)

#### Scenario: Loading state while fetching data
- **WHEN** a user navigates to a page that requires data fetching
- **THEN** a loading indicator is displayed
- **AND** the page layout remains stable (no content jump)

#### Scenario: Error state on fetch failure
- **WHEN** a data fetch fails (network error, API error)
- **THEN** a friendly error message is displayed
- **AND** the user is offered options (retry, go home, etc.)

#### Scenario: Partial data load
- **WHEN** some data loads successfully but related data fails
- **THEN** available data is displayed
- **AND** failed sections show appropriate error messaging

---

### Requirement: Species Aliases and Synonyms

Species detail pages (gall and host) SHALL display aliases and synonyms when present. There are two types of aliases:

**Common Names** (type = COMMON_NAME):
- Label: "Common Name(s): "
- Format: Comma-separated list, sorted alphabetically

**Synonyms** (type = SCIENTIFIC_NAME):
- Label: "Synonymy: "
- Format: Expandable section with "Click to see all synonym details" button
- When expanded: DataTable with Name and Notes columns, sortable, paginated

Aliases help users find species by names they may have encountered in older literature or other resources.

#### Scenario: Species with aliases
- **WHEN** a user views a species page that has aliases
- **THEN** common names are displayed as a comma-separated list
- **AND** synonyms are displayed in an expandable table with Name and Notes columns

#### Scenario: Species without aliases
- **WHEN** a user views a species page that has no aliases
- **THEN** the aliases section is not displayed (no empty section)
