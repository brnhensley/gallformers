# Tasks: Svelte Public Site

## Prerequisites

- [ ] `define-v2-foundation` completed (Svelte app scaffold)
- [ ] `add-go-api` endpoints available for all entity types
- [x] Base component library from umbrella (Button, Input, Modal, etc.)

## 1. Site Layout

- [x] 1.1 Create `Header.svelte` - logo, navigation links, search input, login link
- [x] 1.2 Create `Footer.svelte` - copyright, GitHub/Patreon links, license info
- [x] 1.3 Create `Layout.svelte` - wrapper combining header/footer
- [x] 1.4 Implement mobile-responsive navigation (hamburger menu)
- [x] 1.5 Implement header search that navigates to `/globalsearch?q={term}`

## 2. Shared Components

- [x] 2.1 Create `ImageGallery.svelte` - carousel with attribution, lightbox, placeholder fallback
- [x] 2.2 Create `RangeMap.svelte` - shared map component (view-only + editable modes, d3-geo projection)
- [x] 2.3 Create `SourceList.svelte` - citation list with selection state
- [x] 2.4 Create `ExternalLinks.svelte` - links to iNaturalist, BugGuide, Google Scholar, BHL (described vs undescribed behavior)
- [x] 2.5 Create `TaxonomyBreadcrumb.svelte` - Family → Genus → Species nav
- [x] 2.6 Create `TreeMenu.svelte` - custom hierarchical tree browser (recursive component)
- [x] 2.7 Create `Typeahead.svelte` - search-as-you-type select
- [x] 2.8 Create `DataTable.svelte` - sortable, paginated table
- [x] 2.9 Create `SpeciesSynonymy.svelte` - aliases/synonyms display
- [x] 2.10 Create `DataCompletenessIndicator.svelte` - accessible icon + text with tooltip
- [x] 2.11 Create `LoadingSpinner.svelte` - loading indicator
- [x] 2.12 Create `ErrorMessage.svelte` - user-friendly error display with retry option
- [x] 2.13 Create `EditButton.svelte` - admin edit link (hidden for public users)
- [x] 2.14 Create `InfoTip.svelte` - tooltip information icons
- [x] 2.15 Create `Toast.svelte` - notification toast for user feedback (e.g., "Copied to clipboard")
- [x] 2.16 Create `Tabs.svelte` - tab navigation component (used by Explore page)

## 3. Static Pages

- [x] 3.1 Implement home page (`/`) with random gall feature and phenology link
- [x] 3.2 Implement about page (`/about`)
- [x] 3.3 Implement resources page (`/resources`)
- [x] 3.4 Implement filter guide page (`/filterguide`)
- [x] 3.5 Implement 404 page
- [x] 3.6 Implement stub reference articles page (`/refindex`) - "Coming Soon" placeholder until `add-articles-system`

## 4. Dynamic Pages

- [ ] 4.1 Implement glossary page (`/glossary`)
  - [ ] Load entries from database
  - [ ] Sortable table display
  - [ ] Cross-link terms within definitions
  - [ ] Anchor links for direct term navigation
  - [ ] Edit buttons for authenticated admins

## 5. Entity Detail Pages

- [ ] 5.1 Implement gall detail page (`/gall/{id}`)
  - [ ] Species name, taxonomy hierarchy, hosts
  - [ ] Morphological characteristics (detachable, color, texture, shape, etc.)
  - [ ] Image gallery integration (with placeholder fallback)
  - [ ] Range map integration
  - [ ] Source list with selection
  - [ ] Related galls (internal links)
  - [ ] External links (iNat, BugGuide, etc.)
  - [ ] Species aliases/synonyms
  - [ ] Data completeness indicator (accessible design)
  - [ ] Undescribed species warning + copy gallformers code button
  - [ ] Phenology tool link
  - [ ] Edit buttons for authenticated admins
- [ ] 5.2 Implement host detail page (`/host/{id}`)
  - [ ] Host info, taxonomy
  - [ ] Associated galls list
  - [ ] Range map
  - [ ] Species aliases/synonyms
  - [ ] Data completeness indicator
  - [ ] Edit buttons for authenticated admins
- [ ] 5.3 Implement family page (`/family/{id}`)
- [ ] 5.4 Implement genus page (`/genus/{id}`)
- [ ] 5.5 Implement source page (`/source/{id}`)
- [ ] 5.6 Implement section page (`/section/{id}`)
- [ ] 5.7 Implement place page (`/place/{id}`)

## 6. Search and Browse

- [ ] 6.1 Implement global search page (`/globalsearch`)
  - [ ] Search input with query param sync
  - [ ] Results table with type icons
  - [ ] Links to appropriate detail pages
  - [ ] Empty state handling
- [ ] 6.2 Implement explore page (`/explore`)
  - [ ] Tree menu for galls by family
  - [ ] Tree menu for undescribed galls
  - [ ] Tree menu for hosts by family
  - [ ] Tab navigation between views

## 7. ID Tool

### 7.1 Foundation
- [x] 7.1.1 Port `gallsearch.ts` filter logic to v2
- [x] 7.1.2 Create filter state store (`stores/filters.js`)
- [x] 7.1.3 Create URL state sync (`stores/url.js`)
- [x] 7.1.4 Create results derived store (`stores/results.js`)

### 7.2 Components
- [ ] 7.2.1 Create `HostPicker.svelte` - host typeahead
- [ ] 7.2.2 Create `GenusPicker.svelte` - genus typeahead
- [ ] 7.2.3 Create `FilterPanel.svelte` - all filter controls
- [ ] 7.2.4 Create `FilterChips.svelte` - active filter display
- [ ] 7.2.5 Create `ResultsGrid.svelte` - filtered results display

### 7.3 Integration
- [ ] 7.3.1 Assemble ID tool page (`/id`)
- [ ] 7.3.2 Verify filter combinations match current behavior
- [ ] 7.3.3 Verify URL state persistence works

## 8. SEO and Metadata

- [ ] 8.1 Add page titles and meta descriptions to all pages
- [ ] 8.2 Add Open Graph tags for social sharing
- [ ] 8.3 Verify URL structure matches current site exactly
- [ ] 8.4 Configure pre-rendering for static/entity pages per design.md
- [ ] 8.5 Test with SEO validation tools

## 9. Mobile and Accessibility

- [ ] 9.1 Verify responsive layout on all pages
- [ ] 9.2 Test keyboard navigation
- [ ] 9.3 Verify screen reader compatibility
- [ ] 9.4 Test touch interactions on mobile
- [ ] 9.5 Verify WCAG color contrast on all indicators

## 10. Validation

- [ ] 10.1 Visual comparison testing against current site
- [ ] 10.2 API response comparison for entity detail pages
- [ ] 10.3 ID tool filter result comparison
- [ ] 10.4 Search result comparison
- [ ] 10.5 Performance testing (load times, navigation)
- [ ] 10.6 Loading and error state testing
