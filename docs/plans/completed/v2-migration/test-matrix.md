# Gallformers V2 Test Matrix

Comprehensive manual testing checklist for the Phoenix/LiveView rewrite.

**Last Updated**: 2025-01-22
**Test Environment**: http://localhost:4000
**Production**: https://gallformers.org

---

## Table of Contents

1. [Public Pages](#1-public-pages)
2. [Authentication](#2-authentication)
3. [Admin Features](#3-admin-features)
4. [Search Functionality](#4-search-functionality)
5. [Image Handling](#5-image-handling)
6. [Interactive Components](#6-interactive-components)
7. [Navigation](#7-navigation)
8. [Edge Cases & Error Handling](#8-edge-cases--error-handling)
9. [API Endpoints](#9-api-endpoints)
10. [Accessibility](#10-accessibility)
11. [Performance](#11-performance)

---

## 1. Public Pages

### 1.1 Home Page (`/`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads without errors | Stats display, featured gall shows | N/A |
| [ ] | Featured gall displays random gall | Image, name, and link work | N/A |
| [ ] | Statistics show correct counts | Species, hosts, sources, images counts | Verify against DB |
| [ ] | Quick ID tool host search | Typeahead shows matching hosts | Type "Oak" |
| [ ] | Select host from quick ID | Redirects to ID tool with host pre-selected | Select "Quercus alba" |
| [ ] | Clear host selection | X button clears selection | After selecting |
| [ ] | "Things You Can Do" section links | All links navigate correctly | Click each |
| [ ] | JSON-LD structured data | Valid JSON-LD in page source | View source |

### 1.2 About Page (`/about`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | About content displays | N/A |
| [ ] | Team/contributor info visible | Names and roles shown | N/A |
| [ ] | License information | CC license details shown | N/A |
| [ ] | External links work | Links open in new tabs | Click each |

### 1.3 Filter Guide (`/filterguide`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Documentation content displays | N/A |
| [ ] | All filter categories explained | Each ID tool filter documented | Review all sections |
| [ ] | Images/examples display | Visual aids for filters | N/A |

### 1.4 Resources (`/resources`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Resource list displays | N/A |
| [ ] | External links work | Links open correctly | Click each |
| [ ] | Categorization visible | Resources grouped logically | N/A |

### 1.5 Glossary Index (`/glossary`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Term list displays | N/A |
| [ ] | Search functionality | Terms filter as you type | Type "gall" |
| [ ] | Alphabetical navigation | Jump to letter sections | Click letter |
| [ ] | Term links work | Navigate to term detail | Click term |
| [ ] | Definitions visible | Full definitions shown | N/A |

### 1.6 Reference Index (`/refindex`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Article list displays | N/A |
| [ ] | Tag filtering | Filter by selected tag | Click a tag |
| [ ] | Article links work | Navigate to article | Click article title |
| [ ] | Article count visible | Shows number of articles | N/A |

### 1.7 Reference Article (`/ref/:slug`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Article loads | Content renders | Use existing slug |
| [ ] | Markdown renders correctly | Headers, lists, links work | Various formatting |
| [ ] | Tags display | Article tags shown | N/A |
| [ ] | Back navigation | Return to refindex | Click back |

### 1.8 Explore Page (`/explore`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Browse categories display | N/A |
| [ ] | Statistics visible | Counts per category | N/A |
| [ ] | Category links work | Navigate to filtered view | Click category |
| [ ] | Pagination works | Navigate through pages | Click page numbers |

### 1.9 ID Tool (`/id`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads empty | All filters unset, no results | N/A |
| [ ] | Host typeahead search | Shows matching hosts | Type "Quercus" |
| [ ] | Select host filter | Results filter to host | Select "Quercus alba" |
| [ ] | Genus typeahead search | Shows matching genera | Type "Amphibolips" |
| [ ] | Select genus filter | Results filter to genus | Select a genus |
| [ ] | Location multi-select | Select multiple locations | Select "leaf", "stem" |
| [ ] | Color filter | Results filter by color | Select "green" |
| [ ] | Shape filter | Results filter by shape | Select "spherical" |
| [ ] | Texture multi-select | Select multiple textures | Select 2+ textures |
| [ ] | Alignment filter | Results filter by alignment | Select option |
| [ ] | Walls filter | Results filter by walls | Select option |
| [ ] | Cells filter | Results filter by cells | Select option |
| [ ] | Form filter | Results filter by form | Select option |
| [ ] | Season filter | Results filter by season | Select option |
| [ ] | Detachable filter | Results filter by detachability | Select yes/no |
| [ ] | Place filter (checkboxes) | Results filter by geographic range | Check a state |
| [ ] | Multiple filters combined | Results match ALL criteria | Set 3+ filters |
| [ ] | Clear individual filter | That filter resets | Click X |
| [ ] | Clear all filters | All filters reset | Click "Clear All" |
| [ ] | URL state preserved | Refresh keeps filters | Set filters, refresh |
| [ ] | Share URL works | Opening URL restores filters | Copy and paste URL |
| [ ] | Result count updates | Shows matching gall count | Add/remove filters |
| [ ] | Result cards display | Species info visible | N/A |
| [ ] | Click result | Navigate to gall page | Click a result |

### 1.10 Gall Detail Page (`/gall/:id`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Full gall data displays | Use valid ID |
| [ ] | Species name displays | Scientific name shown | N/A |
| [ ] | Aliases/synonyms shown | Alternative names visible | Gall with aliases |
| [ ] | Host plants listed | Links to host pages | Gall with hosts |
| [ ] | Image gallery displays | Primary image shown | Gall with images |
| [ ] | Gallery prev/next buttons | Navigate images | Click arrows |
| [ ] | Gallery keyboard navigation | Arrow keys work | Press left/right |
| [ ] | Lightbox opens | Click image opens modal | Click image |
| [ ] | Lightbox close | X, ESC, backdrop all close | Test each |
| [ ] | Image counter | Shows "X of Y" | N/A |
| [ ] | Image info button | Shows metadata dialog | Click info icon |
| [ ] | Copyright/license shown | Attribution visible | N/A |
| [ ] | Morphology section | Color, shape, texture, etc. | N/A |
| [ ] | Location on plant | Leaf, stem, etc. shown | N/A |
| [ ] | Season information | When gall appears | N/A |
| [ ] | Detachability | Detachable status shown | N/A |
| [ ] | Range map displays | States/provinces highlighted | Gall with places |
| [ ] | Range map interactive | Hover shows region name | Hover over state |
| [ ] | Sources section | Citations listed | Gall with sources |
| [ ] | Source links work | Navigate to source page | Click citation |
| [ ] | External links | iNaturalist, BugGuide, etc. | N/A |
| [ ] | Data completeness indicator | Shows missing fields | Gall with gaps |
| [ ] | Taxonomy breadcrumb | Family > Genus > Species | N/A |
| [ ] | Breadcrumb links work | Navigate taxonomy | Click each level |
| [ ] | Edit button (admin only) | Shows for admins | Login as admin |
| [ ] | Edit button (hidden) | Hidden for public | Not logged in |
| [ ] | SEO meta tags | Title, description correct | View source |
| [ ] | JSON-LD data | Valid structured data | View source |

### 1.11 Host Detail Page (`/host/:id`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Host data displays | Use valid ID |
| [ ] | Scientific name shown | Plant name visible | N/A |
| [ ] | Common names shown | Vernacular names | Host with common names |
| [ ] | Taxonomy breadcrumb | Family > Genus | N/A |
| [ ] | Associated galls listed | Galls on this host | Host with galls |
| [ ] | Gall links work | Navigate to gall pages | Click gall |
| [ ] | Edit button (admin only) | Shows for admins | Login as admin |

### 1.12 Taxonomy Pages

#### Family Page (`/family/:id`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Family info displays | Use valid ID |
| [ ] | Family description | Text content shown | N/A |
| [ ] | Genera listed | All genera in family | N/A |
| [ ] | Genus links work | Navigate to genus page | Click genus |
| [ ] | Statistics shown | Species count | N/A |

#### Genus Page (`/genus/:id`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Genus info displays | Use valid ID |
| [ ] | Genus description | Text content shown | N/A |
| [ ] | Species listed | All species in genus | N/A |
| [ ] | Species links work | Navigate to species page | Click species |
| [ ] | Family breadcrumb | Navigate to family | Click family |

### 1.13 Source Detail Page (`/source/:id`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Citation displays | Use valid ID |
| [ ] | Full citation | Author, year, title, etc. | N/A |
| [ ] | External URL | Link to original source | Source with URL |
| [ ] | Linked species | Species citing this source | N/A |
| [ ] | Species links work | Navigate to species pages | Click species |

### 1.14 Place Detail Page (`/place/:id`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Region info displays | Use valid ID |
| [ ] | Region name shown | State/province name | N/A |
| [ ] | Species in region | Galls found here | N/A |
| [ ] | Species links work | Navigate to gall pages | Click species |

### 1.15 User Profile Page (`/user/:nickname`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Public profile displays | Valid nickname |
| [ ] | User info shown | Name, join date | N/A |
| [ ] | Contributions visible | User's contributions | User with activity |
| [ ] | Invalid user | 404 error page | Invalid nickname |

---

## 2. Authentication

### 2.1 Login Flow

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Login link visible | Shows in header | Not logged in |
| [ ] | Click login | Redirects to Auth0 | N/A |
| [ ] | Auth0 login | Can enter credentials | Valid credentials |
| [ ] | Successful login | Returns to site, session created | N/A |
| [ ] | User info displayed | Name/avatar in header | After login |
| [ ] | Session persists | Refresh keeps logged in | After login |
| [ ] | Admin gets admin access | Can access /admin | Login as admin |
| [ ] | Non-admin blocked from admin | Redirects away from /admin | Login as regular user |

### 2.2 Logout Flow

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Logout link visible | Shows when logged in | Logged in |
| [ ] | Click logout | Session cleared | N/A |
| [ ] | Redirect after logout | Returns to home page | N/A |
| [ ] | Admin pages inaccessible | Redirects to login | After logout |
| [ ] | Login link returns | Shows after logout | N/A |

### 2.3 Session Handling

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Session timeout | Eventually requires re-login | Wait extended time |
| [ ] | Multiple tabs | Session consistent | Open multiple tabs |
| [ ] | Clear cookies | Logged out | Clear browser cookies |

---

## 3. Admin Features

### 3.1 Admin Dashboard (`/admin`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Dashboard displays | Login as admin |
| [ ] | Statistics cards | Counts for entities | N/A |
| [ ] | Quick links work | Navigate to admin sections | Click each |
| [ ] | Unauthorized redirect | Non-admin redirected | Not admin |

### 3.2 Galls Admin (`/admin/galls`)

#### Index Page

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Gall list displays | Login as admin |
| [ ] | Pagination works | Navigate pages | Click next/prev |
| [ ] | Sorting works | Click column headers | Click "Name" |
| [ ] | Search filter | Filter by name | Type in search |
| [ ] | Create button | Navigate to new form | Click "New Gall" |
| [ ] | Edit button | Navigate to edit form | Click edit icon |
| [ ] | Delete button | Confirmation dialog | Click delete |
| [ ] | Delete confirmation | Gall removed | Confirm delete |

#### Create/Edit Form

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Form loads (new) | Empty form displays | /admin/galls/new |
| [ ] | Form loads (edit) | Populated form | /admin/galls/:id |
| [ ] | Species name required | Validation error if empty | Leave blank |
| [ ] | Genus selection | Typeahead picker works | Type genus name |
| [ ] | Undescribed checkbox | Toggle works | Check/uncheck |
| [ ] | Add alias | Alias added to list | Click add alias |
| [ ] | Edit alias | Modify existing alias | Click edit |
| [ ] | Remove alias | Alias removed | Click X |
| [ ] | Host picker | Multi-select typeahead | Search hosts |
| [ ] | Add host | Host added to list | Select host |
| [ ] | Remove host | Host removed | Click X |
| [ ] | Location selection | Multi-select checkboxes | Select locations |
| [ ] | Color selection | Multi-select | Select colors |
| [ ] | Shape selection | Multi-select | Select shapes |
| [ ] | Texture selection | Multi-select | Select textures |
| [ ] | Alignment selection | Single select | Select option |
| [ ] | Walls selection | Single select | Select option |
| [ ] | Cells selection | Single select | Select option |
| [ ] | Form selection | Single select | Select option |
| [ ] | Season selection | Multi-select | Select seasons |
| [ ] | Detachable toggle | Yes/No/Unknown | Select option |
| [ ] | Place selection | Checkboxes for states | Check states |
| [ ] | Abundance selection | Dropdown | Select option |
| [ ] | Rename modal | Opens rename dialog | Click rename |
| [ ] | Rename with alias | Creates alias on save | Check "create alias" |
| [ ] | Deferred changes shown | Pending changes indicator | Make changes |
| [ ] | Save form | Changes persisted | Click save |
| [ ] | Cancel form | Changes discarded | Click cancel |
| [ ] | Validation errors | Field-level errors shown | Invalid data |

### 3.3 Hosts Admin (`/admin/hosts`)

#### Index Page

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Host list displays | Login as admin |
| [ ] | Pagination works | Navigate pages | Click next/prev |
| [ ] | Sorting works | Click column headers | Click "Name" |
| [ ] | Search filter | Filter by name | Type in search |
| [ ] | Create button | Navigate to new form | Click "New Host" |
| [ ] | Edit button | Navigate to edit form | Click edit icon |
| [ ] | Delete button | Confirmation dialog | Click delete |

#### Create/Edit Form

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Form loads (new) | Empty form displays | /admin/hosts/new |
| [ ] | Form loads (edit) | Populated form | /admin/hosts/:id |
| [ ] | Species name required | Validation error | Leave blank |
| [ ] | Genus selection | Typeahead picker | Type genus name |
| [ ] | Common name field | Text input works | Enter name |
| [ ] | Save form | Changes persisted | Click save |
| [ ] | Validation errors | Field-level errors | Invalid data |

### 3.4 Taxonomy Admin (`/admin/taxonomy`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Index loads | Taxonomy list displays | Login as admin |
| [ ] | Filter by type | Family/Genus/Section | Select type |
| [ ] | Create new | Form displays | Click create |
| [ ] | Edit existing | Populated form | Click edit |
| [ ] | Parent selection | Typeahead for parent | Select parent |
| [ ] | Save changes | Persisted to DB | Click save |
| [ ] | Delete | Confirmation, then removed | Click delete |

### 3.5 Sources Admin (`/admin/sources`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Index loads | Source list displays | Login as admin |
| [ ] | Pagination works | Navigate pages | Click next/prev |
| [ ] | Search filter | Filter by title/author | Type in search |
| [ ] | Create new | Empty form | Click create |
| [ ] | Edit existing | Populated form | Click edit |
| [ ] | Author field | Text input | Enter author |
| [ ] | Year field | Number input | Enter year |
| [ ] | Title field | Text input | Enter title |
| [ ] | URL field | URL validation | Enter URL |
| [ ] | Publisher field | Text input | Enter publisher |
| [ ] | DOI field | Text input | Enter DOI |
| [ ] | Save changes | Persisted | Click save |
| [ ] | Delete | Removed | Click delete |

### 3.6 Species-Source Admin

#### Add from Source (`/admin/species-sources/add`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Form displays | Login as admin |
| [ ] | Source search | Find sources | Type source name |
| [ ] | Species multi-select | Add multiple species | Select species |
| [ ] | Bulk add | Links created | Click add |
| [ ] | Success message | Confirmation shown | After add |

#### Quick Find (`/admin/species-sources/find`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Search form | Login as admin |
| [ ] | Search by species | Shows linked sources | Enter species |
| [ ] | Search by source | Shows linked species | Enter source |
| [ ] | Edit links | Can modify | Click edit |
| [ ] | Remove link | Association deleted | Click remove |

### 3.7 Glossary Admin (`/admin/glossary`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Index loads | Term list displays | Login as admin |
| [ ] | Search filter | Filter terms | Type in search |
| [ ] | Create new | Empty form | Click create |
| [ ] | Edit existing | Populated form | Click edit |
| [ ] | Word field | Required text | Enter word |
| [ ] | Definition field | Rich text/markdown | Enter definition |
| [ ] | Section selection | Dropdown | Select section |
| [ ] | Save changes | Persisted | Click save |
| [ ] | Delete | Removed | Click delete |

### 3.8 Images Admin (`/admin/images`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Species search displays | Login as admin |
| [ ] | Species search | Typeahead works | Type species name |
| [ ] | Select species | Shows species images | Select species |
| [ ] | Images display | Gallery of current images | Species with images |
| [ ] | Drag-drop upload | File dropped, uploads | Drag image file |
| [ ] | Click upload | File dialog opens | Click upload area |
| [ ] | Upload progress | Progress indicator | During upload |
| [ ] | Upload success | Image added to gallery | After upload |
| [ ] | Upload failure | Error message shown | Invalid file |
| [ ] | MIME validation | Only jpg/png accepted | Try pdf |
| [ ] | Image reorder | Drag to reorder | Drag images |
| [ ] | Sort order saved | Order persists on refresh | Reorder, refresh |
| [ ] | Set primary image | sort_order = 0 | Drag to first |
| [ ] | Edit metadata | Opens modal | Click edit button |
| [ ] | Metadata fields | Creator, license, caption | Edit each |
| [ ] | Save metadata | Changes persisted | Click save |
| [ ] | Delete image | Confirmation dialog | Click delete |
| [ ] | Confirm delete | Image removed | Confirm |

### 3.9 Articles Admin (`/admin/articles`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Index loads | Article list | Login as admin |
| [ ] | Create new | Empty form | Click create |
| [ ] | Edit existing | Populated form | Click edit |
| [ ] | Title field | Required text | Enter title |
| [ ] | Slug field | Auto-generated | From title |
| [ ] | Body field | Markdown editor | Enter content |
| [ ] | Tag selection | Multi-select | Add tags |
| [ ] | Publication status | Published toggle | Toggle on/off |
| [ ] | Preview | Rendered markdown | Click preview |
| [ ] | Save draft | Unpublished save | Save as draft |
| [ ] | Publish | Article live | Toggle published |
| [ ] | Delete | Removed | Click delete |

### 3.10 Gall-Host Admin (`/admin/gallhost`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Mapping interface | Login as admin |
| [ ] | Search gall | Find galls | Type gall name |
| [ ] | Select gall | Shows current hosts | Select gall |
| [ ] | Add host | Association created | Add host |
| [ ] | Remove host | Association deleted | Remove host |
| [ ] | Save changes | Persisted | Click save |

### 3.11 Admin Profile (`/admin/profile`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Profile form | Login as admin |
| [ ] | View current settings | Current values shown | N/A |
| [ ] | Update settings | Changes saved | Modify field |
| [ ] | Validation | Invalid data rejected | Bad input |

### 3.12 Super Admin Features

#### Places Admin (`/admin/places`) - SuperAdmin Only

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Place list | Login as superadmin |
| [ ] | Access denied | Non-superadmin blocked | Login as admin |
| [ ] | Create new | Empty form | Click create |
| [ ] | Name field | Required | Enter name |
| [ ] | Postal code | Two-letter code | Enter code |
| [ ] | Save changes | Persisted | Click save |
| [ ] | Delete | Removed | Click delete |

#### Filter Terms Admin (`/admin/filter-terms`) - SuperAdmin Only

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Term list by category | Login as superadmin |
| [ ] | Access denied | Non-superadmin blocked | Login as admin |
| [ ] | Filter by category | Shows category terms | Select category |
| [ ] | Create new | Empty form | Click create |
| [ ] | Term name | Required | Enter name |
| [ ] | Category selection | Dropdown | Select category |
| [ ] | Save changes | Persisted | Click save |
| [ ] | Delete | Removed | Click delete |

#### Users Admin (`/admin/users`) - SuperAdmin Only

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | User list | Login as superadmin |
| [ ] | Access denied | Non-superadmin blocked | Login as admin |
| [ ] | View user details | User info shown | Click user |
| [ ] | Assign admin role | Role changed | Toggle admin |
| [ ] | Remove admin role | Role removed | Toggle admin off |
| [ ] | Assign superadmin | Role changed | Toggle superadmin |
| [ ] | Disable user | User deactivated | Click disable |
| [ ] | Enable user | User reactivated | Click enable |

---

## 4. Search Functionality

### 4.1 Global Search (`/globalsearch`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page loads | Search interface | N/A |
| [ ] | Empty search | Prompt to enter query | No input |
| [ ] | Search execution | Results display | Enter "oak" |
| [ ] | Debounced input | Waits before searching | Type quickly |
| [ ] | Result categories | Galls, hosts, sources, etc. | Broad search |
| [ ] | Result count | Shows per category | N/A |
| [ ] | Sort by relevance | Default sort | N/A |
| [ ] | Sort by name | Alphabetical | Select sort |
| [ ] | Sort by type | Grouped by entity | Select sort |
| [ ] | Keyboard nav - down | Moves to next result | Press down arrow |
| [ ] | Keyboard nav - up | Moves to previous | Press up arrow |
| [ ] | Keyboard nav - enter | Opens selected | Press enter |
| [ ] | Click result | Navigate to detail | Click result |
| [ ] | No results | "No results" message | Search "zzzzzzz" |
| [ ] | URL state | Query in URL | Search, check URL |
| [ ] | Refresh preserves | Query restored | Search, refresh |

### 4.2 ID Tool Search

See [ID Tool section](#19-id-tool-id) above for comprehensive ID tool tests.

### 4.3 Admin Search (Various)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Galls admin search | Filters gall list | Type in search |
| [ ] | Hosts admin search | Filters host list | Type in search |
| [ ] | Sources admin search | Filters by author/title | Type in search |
| [ ] | Glossary admin search | Filters terms | Type in search |
| [ ] | Case insensitive | Matches regardless of case | "Oak" vs "oak" |
| [ ] | Partial match | Matches substrings | "Quer" for Quercus |

---

## 5. Image Handling

### 5.1 Image Display

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Gallery on gall page | Images display | Gall with images |
| [ ] | Primary image first | sort_order=0 shown first | Gall with ordered images |
| [ ] | Image lazy loading | Images load on scroll | Many images |
| [ ] | CDN URLs | Images from CDN | Check network |
| [ ] | Multiple sizes | Appropriate size loaded | Check network |
| [ ] | Missing image | Placeholder shown | Gall without images |
| [ ] | Image info | Metadata accessible | Click info icon |

### 5.2 Image Gallery Component

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Prev/next buttons | Navigate images | Click arrows |
| [ ] | Keyboard arrows | Navigate with keys | Press left/right |
| [ ] | Image counter | "X of Y" displays | N/A |
| [ ] | Single image | No nav buttons | Gall with 1 image |
| [ ] | Many images | Counter updates | Gall with 10+ images |
| [ ] | Wrap around | Last to first, first to last | Navigate past end |

### 5.3 Lightbox

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Open lightbox | Click image opens modal | Click image |
| [ ] | Full-size image | Larger image displayed | N/A |
| [ ] | Close - X button | Modal closes | Click X |
| [ ] | Close - ESC key | Modal closes | Press ESC |
| [ ] | Close - backdrop | Modal closes | Click outside |
| [ ] | Navigate in lightbox | Arrows work | Click arrows |
| [ ] | Keyboard in lightbox | Arrow keys work | Press left/right |

### 5.4 Image Upload (Admin)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Drag-drop | File uploads | Drag jpg file |
| [ ] | Click to select | File dialog | Click upload area |
| [ ] | Multiple files | All upload | Drag 3 files |
| [ ] | JPEG accepted | Uploads successfully | .jpg file |
| [ ] | PNG accepted | Uploads successfully | .png file |
| [ ] | Invalid type rejected | Error message | .pdf file |
| [ ] | Large file | Either works or size error | 10MB+ file |
| [ ] | Upload progress | Indicator shown | During upload |
| [ ] | S3 presigned URL | Generated correctly | Check network |
| [ ] | Resized versions | Multiple sizes created | After upload |

---

## 6. Interactive Components

### 6.1 Typeahead (Single-Select)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Focus shows placeholder | Placeholder text | Click input |
| [ ] | Typing triggers search | Results appear | Type 3+ chars |
| [ ] | Debounced | Waits before searching | Type quickly |
| [ ] | Results dropdown | Options displayed | Type query |
| [ ] | Keyboard - down | Highlights next option | Press down |
| [ ] | Keyboard - up | Highlights previous | Press up |
| [ ] | Keyboard - enter | Selects highlighted | Press enter |
| [ ] | Keyboard - escape | Closes dropdown | Press escape |
| [ ] | Click option | Selects option | Click option |
| [ ] | Selected displays | Selection shown | After select |
| [ ] | Clear button | Clears selection | Click X |
| [ ] | No results | "No results" message | Type "zzzzz" |
| [ ] | ARIA attributes | Proper accessibility | Inspect DOM |

### 6.2 Multi-Select Typeahead

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | All single-select tests | Same behavior | See above |
| [ ] | Multiple selections | Chips displayed | Select multiple |
| [ ] | Remove chip | Click X removes | Click chip X |
| [ ] | Deduplication | Can't add same twice | Try duplicate |
| [ ] | Continue typing | Can add more | After selection |

### 6.3 Multi-Select Dropdown

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Click opens dropdown | Options displayed | Click input |
| [ ] | Check option | Added to selection | Check box |
| [ ] | Uncheck option | Removed from selection | Uncheck box |
| [ ] | Chips displayed | Shows selections | Select multiple |
| [ ] | Remove via chip X | Unchecks option | Click chip X |
| [ ] | Search/filter | Options filtered | Type in search |
| [ ] | Close dropdown | Click outside | Click outside |

### 6.4 Modal Dialogs

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Modal opens | Displayed on trigger | Trigger modal |
| [ ] | Close - X button | Modal closes | Click X |
| [ ] | Close - ESC | Modal closes | Press ESC |
| [ ] | Close - backdrop | Modal closes | Click outside |
| [ ] | Focus trap | Tab stays in modal | Press tab |
| [ ] | Scroll lock | Body doesn't scroll | Scroll attempt |
| [ ] | Nested modal | Both work correctly | If applicable |

### 6.5 Tabs Component

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Default tab active | First tab content shown | N/A |
| [ ] | Click tab | Content switches | Click other tab |
| [ ] | Active state | Visual indicator | N/A |
| [ ] | Keyboard nav | Arrow keys work | Focus, press arrows |
| [ ] | ARIA attributes | Proper roles | Inspect DOM |

### 6.6 Toast Notifications

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Success toast | Green styling | Trigger success |
| [ ] | Error toast | Red styling | Trigger error |
| [ ] | Warning toast | Yellow styling | Trigger warning |
| [ ] | Info toast | Blue styling | Trigger info |
| [ ] | Auto-dismiss | Disappears after time | Wait |
| [ ] | Manual dismiss | X button closes | Click X |
| [ ] | Multiple toasts | Stacked display | Trigger multiple |

### 6.7 Forms

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Required field empty | Validation error | Leave blank |
| [ ] | Invalid email | Validation error | Enter "bad" |
| [ ] | Invalid URL | Validation error | Enter "bad" |
| [ ] | Server validation | Error from server | Submit invalid |
| [ ] | Field-level errors | Error under field | Invalid field |
| [ ] | Form-level errors | Error at top | General error |
| [ ] | Submit success | Success message | Valid submit |
| [ ] | Submit button state | Disabled during submit | Watch button |

### 6.8 Toggle Switches

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Click toggle | State changes | Click toggle |
| [ ] | Visual feedback | On/off appearance | N/A |
| [ ] | Keyboard - space | Toggles | Focus, press space |
| [ ] | Disabled state | Cannot toggle | If applicable |

---

## 7. Navigation

### 7.1 Main Navigation

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Logo link | Goes to home | Click logo |
| [ ] | Nav links | Each navigates correctly | Click each |
| [ ] | Active state | Current page highlighted | N/A |
| [ ] | Mobile menu | Hamburger works | Resize to mobile |
| [ ] | Mobile links | All accessible | Open mobile menu |

### 7.2 Breadcrumbs

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Breadcrumb displays | Path shown | Gall page |
| [ ] | Each level clickable | Navigates correctly | Click each |
| [ ] | Current page | Not linked | Last item |

### 7.3 Back Links

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Back link shows | Arrow and text | Detail pages |
| [ ] | Click back | Returns to list/previous | Click back |
| [ ] | Correct destination | Right page | N/A |

### 7.4 Internal Links

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Host links from gall | Navigate to host | Click host link |
| [ ] | Gall links from host | Navigate to gall | Click gall link |
| [ ] | Source links | Navigate to source | Click source |
| [ ] | Taxonomy links | Navigate correctly | Click family/genus |

### 7.5 External Links

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | iNaturalist link | Opens iNat | Click link |
| [ ] | BugGuide link | Opens BugGuide | Click link |
| [ ] | Scholar link | Opens Google Scholar | Click link |
| [ ] | BHL link | Opens BHL | Click link |
| [ ] | New tab | Links open new tab | Check target |

---

## 8. Edge Cases & Error Handling

### 8.1 404 Errors

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Invalid gall ID | 404 page | /gall/999999 |
| [ ] | Invalid host ID | 404 page | /host/999999 |
| [ ] | Invalid route | 404 page | /nonexistent |
| [ ] | Invalid article slug | 404 page | /ref/nonexistent |
| [ ] | 404 page content | Helpful message | Any 404 |
| [ ] | 404 navigation | Can return home | Click home link |

### 8.2 Empty States

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | No search results | "No results" message | Search "zzzzz" |
| [ ] | No images | Placeholder or message | Gall without images |
| [ ] | No hosts | Appropriate message | Gall without hosts |
| [ ] | No sources | Appropriate message | Gall without sources |
| [ ] | Empty admin list | "No items" message | Empty category |

### 8.3 Server Errors

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | 500 error | Error page shown | Trigger error |
| [ ] | Error page helpful | Message + home link | N/A |
| [ ] | Form submission error | Error message | Submit bad data |
| [ ] | Upload failure | Error message | Fail upload |

### 8.4 Network Issues

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Slow connection | Loading states shown | Throttle network |
| [ ] | Image load failure | Fallback/placeholder | Block images |
| [ ] | LiveView disconnect | Reconnect attempt | Disable network |
| [ ] | Reconnect success | State restored | Re-enable network |

### 8.5 Data Validation

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | XSS prevention | Scripts not executed | Enter `<script>` |
| [ ] | SQL injection | Query escaped | Enter `'; DROP` |
| [ ] | Long input | Truncated or error | Very long string |
| [ ] | Special characters | Handled correctly | Enter `<>&"'` |
| [ ] | Unicode | Displays correctly | Enter emoji, accents |

---

## 9. API Endpoints

### 9.1 Public API (`/api/v2/*`)

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | GET /api/v2/species | List species | N/A |
| [ ] | GET /api/v2/species/:id | Single species | Valid ID |
| [ ] | GET /api/v2/galls | List galls | N/A |
| [ ] | GET /api/v2/galls/random | Random gall | N/A |
| [ ] | GET /api/v2/galls/id | ID tool API | With filters |
| [ ] | GET /api/v2/galls/:id | Single gall | Valid ID |
| [ ] | GET /api/v2/galls/:id/images | Gall images | Valid ID |
| [ ] | GET /api/v2/hosts | List hosts | N/A |
| [ ] | GET /api/v2/hosts/:id | Single host | Valid ID |
| [ ] | GET /api/v2/families | List families | N/A |
| [ ] | GET /api/v2/families/:id | Single family | Valid ID |
| [ ] | GET /api/v2/genera/:id | Single genus | Valid ID |
| [ ] | GET /api/v2/sources | List sources | N/A |
| [ ] | GET /api/v2/sources/:id | Single source | Valid ID |
| [ ] | GET /api/v2/glossary | List terms | N/A |
| [ ] | GET /api/v2/glossary/:id | Single term | Valid ID |
| [ ] | GET /api/v2/places | List places | N/A |
| [ ] | GET /api/v2/search | Global search | Query param |
| [ ] | GET /api/v2/stats | Database stats | N/A |
| [ ] | GET /api/v2/filter-fields | ID tool options | N/A |

### 9.2 API Response Format

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Content-Type | application/json | Check header |
| [ ] | Valid JSON | Parses correctly | All endpoints |
| [ ] | Pagination | limit/offset work | List endpoints |
| [ ] | 404 response | JSON error | Invalid ID |
| [ ] | Rate limiting | 429 after limit | Many requests |

### 9.3 Documentation

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | OpenAPI spec | Valid JSON | /api/docs/openapi.json |
| [ ] | Swagger UI | Renders | /api/docs/ |
| [ ] | Try endpoints | Execute from docs | Use Swagger |

---

## 10. Accessibility

### 10.1 Keyboard Navigation

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Tab order | Logical flow | Tab through page |
| [ ] | Focus visible | Clear indicator | Tab through |
| [ ] | Skip link | Jump to content | First tab |
| [ ] | All interactive reachable | Keyboard only | No mouse |
| [ ] | Modal focus trap | Stays in modal | Tab in modal |
| [ ] | Dropdown keyboard | Arrow keys work | Focus dropdown |
| [ ] | Form submission | Enter submits | In form |

### 10.2 Screen Reader

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Page titles | Descriptive | Check `<title>` |
| [ ] | Heading hierarchy | Logical h1-h6 | Check structure |
| [ ] | Image alt text | Meaningful | Check images |
| [ ] | Link text | Descriptive | Check links |
| [ ] | Form labels | Associated | Check forms |
| [ ] | Error messages | Announced | Trigger error |
| [ ] | ARIA labels | Present where needed | Inspect DOM |
| [ ] | Live regions | Updates announced | Dynamic content |

### 10.3 Visual

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Color contrast | WCAG AA (4.5:1) | Check text |
| [ ] | No color-only info | Icons/text too | Check indicators |
| [ ] | Text resizable | Up to 200% | Zoom browser |
| [ ] | Responsive | Usable at all sizes | Resize window |
| [ ] | Focus indicators | Visible at all times | Tab through |

---

## 11. Performance

### 11.1 Page Load

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Home page load | < 2s | Measure |
| [ ] | Gall page load | < 2s | Measure |
| [ ] | ID tool load | < 2s | Measure |
| [ ] | Admin dashboard | < 2s | Measure |
| [ ] | Large list (1000+) | Pagination, < 3s | Admin galls |

### 11.2 Interactions

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | Search response | < 500ms | Type query |
| [ ] | Filter apply | < 500ms | Apply filter |
| [ ] | Modal open | Instant | Trigger modal |
| [ ] | Image gallery nav | Instant | Click arrows |

### 11.3 Assets

| Status | Test Case | Expected Behavior | Test Data |
|--------|-----------|-------------------|-----------|
| [ ] | CSS bundled | Single file | Check network |
| [ ] | JS bundled | Single file | Check network |
| [ ] | Images from CDN | CloudFront URLs | Check network |
| [ ] | Gzip enabled | Compressed | Check headers |

---

## Test Data Requirements

### Species/Galls

- Gall with all fields populated
- Gall with minimal fields (empty state testing)
- Gall with many images (10+)
- Gall with single image
- Gall with no images
- Gall with many hosts
- Gall with aliases/synonyms
- Gall with sources
- Undescribed species

### Hosts

- Host with many associated galls
- Host with no galls
- Host with common names
- Host in multiple families/genera

### Other

- Source with URL
- Source without URL
- Glossary term with definition
- Published article
- Draft article (admin testing)
- User with admin role
- User with superadmin role
- Regular user (no admin)

---

## Testing Notes

### Environment Setup

1. Start local server: `mix phx.server`
2. Ensure database seeded: `mix ecto.reset` or `make download-db`
3. Create test users with various roles in Auth0

### Browser Testing

Test on:
- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Mobile Chrome
- Mobile Safari

### Tools

- Browser DevTools for network/performance
- axe or WAVE for accessibility
- Postman/curl for API testing
- VoiceOver/NVDA for screen reader testing

---

## Sign-Off

| Area | Tester | Date | Status |
|------|--------|------|--------|
| Public Pages | | | |
| Authentication | | | |
| Admin Features | | | |
| Search | | | |
| Images | | | |
| Components | | | |
| Navigation | | | |
| Edge Cases | | | |
| API | | | |
| Accessibility | | | |
| Performance | | | |
