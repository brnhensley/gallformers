# What's New in Gallformers V2

Gallformers V2 is a ground-up rebuild of the site with a focus on speed, usability, and new features. Here's what's changed.

---

## For Everyone

### Smarter Search

Search now understands what you're looking for:
- **Relevance ranking**: The best matches appear first, not just alphabetically
- **Multi-word shortcuts**: Type "q alba" to find "Quercus alba"
- **Keyboard navigation**: Use arrow keys to move through results and Enter to select
- **Instant results**: Results appear as you type

### Faster ID Tool

The gall identification tool has been completely rebuilt:
- **Faster filtering**: Results update instantly as you change filters
- **Shareable URLs**: Share a link to your exact filter combination - bookmarks from V1 continue to work
- **Quick ID from home**: Start identifying galls right from the home page by selecting a host plant

### Explore Improvements

The taxonomic explorer now includes:
- **Search within trees**: Find specific families, genera, or species without scrolling
- **Expand/Collapse All**: Quickly open or close entire sections
- **Species counts**: See how many species are in each group

### Better Species Pages

Gall and host detail pages now feature:
- **Larger images** with improved gallery navigation
- **Adjustable text size** for source descriptions
- **Excluded range display**: See where a species is confirmed NOT to occur
- **Improved undescribed gall display**: Clearer presentation of undescribed species with their Gallformers codes and direct links to contribute observations

### User Profiles

Contributors now have optional public profile pages showing their contributions to the site.

### Instant Data Updates

Changes to galls, hosts, and other data now appear immediately on the site, no more waiting for cache timeouts. Coming soon: live updates will push directly to pages as you're viewing them. So an edit will show up live on a user's screen if the are viewing the edited data.

### Better Search Engine Visibility

V2 includes comprehensive SEO improvements:
- **Structured data**: Search engines better understand our content, leading to richer search results
- **Improved descriptions**: Each page has optimized metadata for search snippets
- **Faster indexing**: Instant updates mean search engines see current information

This helps more people discover Gallformers when searching for gall identification help.

---

## Reference Articles

The reference library has been completely reimagined:

- **Tag-based browsing**: Filter articles by topic (identification, keys, guides, etc.)
- **Related articles**: Discover similar content based on shared topics
- **Draft workflow**: Authors can save work-in-progress before publishing
- **Integrated images**: Upload and manage images directly within articles
- **Auto-linked glossary terms**: Technical terms automatically link to their definitions

---

## Accessibility

V2 represents a major commitment to accessibility that V1 lacked almost entirely:

- **Keyboard navigation**: Every feature is accessible without a mouse
- **Screen reader support**: Proper ARIA labels and semantic HTML throughout
- **Adjustable text sizes**: Increase font size for easier reading
- **Color contrast**: Meets WCAG guidelines for readability
- **Focus indicators**: Always see where you are on the page

We're striving for near-perfect accessibility compliance across the entire site.

---

## For Administrators

### New Admin Dashboard

The admin area now opens to a dashboard showing:
- **Live statistics**: Current counts of galls, hosts, sources, and images
- **Quick actions**: One-click access to common tasks
- **Persistent navigation**: Sidebar always available

### Integrated Browse

Browse functionality is now built directly into admin list pages - no need to switch between separate browse and edit views. Search, filter, and edit all in one place. This data is also now pagianted and searchable right from within the main Admin views.

### Image Management

Working with images is now much easier:
- **Drag-and-drop upload**: Drop files directly onto the page
- **Drag-and-drop reordering**: Arrange images by dragging (first image becomes the default)
- **Image audit tool**: Find orphaned images in S3 or images missing attribution
- **Incomplete warnings**: Visual indicators highlight images that need attention

### Species-Source Mapping

The tools for connecting species to their source references have been significantly improved:
- **Bulk addition**: Add source descriptions to multiple species at once
- **Quick find**: Search and edit existing mappings efficiently
- **Streamlined workflow**: Fewer clicks to accomplish common tasks

### Undescribed Galls & Gallformers Codes

Handling of undescribed species is now much cleaner:
- **Vastly improved display on Gall page**: Copy code, see observations from iNat, get help on how to use gallformers codes
- **Unknown family/genus handling**: The system manages "Unknown" placeholders automatically when creating undescribed galls
- **Dedicated workflow**: A specialized form guides you through adding undescribed galls correctly

### Articles Admin

Create and manage reference articles with a full editor:
- **Markdown with live preview**: See formatted output as you write
- **Image browser**: Insert images from the library or upload new ones
- **Tag management**: Organize articles with free-form tags
- **Publish controls**: Save drafts, then publish when ready

### Analytics Dashboard

Track how the site is being used (privacy-respecting):
- **Page view statistics**: See which pages are most popular
- **Visitor counts**: Unique visitors by day, week, or month
- **Top referrers**: See where traffic comes from
- **Device breakdown**: Desktop vs. mobile vs. tablet usage
- **Browser statistics**: Which browsers visitors use

No personal information is collected - visitors are counted using anonymous daily hashes.

### Dynamic About Page

The administrators are optinally shown on the About page are now managed through the admin interface - no code changes needed to add or remove team members.

### Real-time Collaboration

Changes made by one admin appear instantly for others:
- No need to refresh to see updates
- Reduces conflicts when multiple people are editing

### Expanded License Options

When attributing images and sources, you can now choose from all Creative Commons license variants:
- Public Domain, CC0, CC-BY, CC-BY-SA, CC-BY-NC, CC-BY-NC-SA, CC-BY-ND, All Rights Reserved
- License URLs are auto-filled for standard licenses

### Better List Views

All admin lists now include:
- **Search**: Find records quickly
- **Sorting**: Click column headers to sort
- **Pagination**: Handle large datasets smoothly

### User Management

Superadmins can now manage user accounts directly in the admin interface.

---

## Other Improvements

### Performance
- Pages load faster with optimized queries
- Images lazy-load as you scroll
- Real-time updates without page refreshes

### Mobile
- Improved layouts on phones and tablets
- Touch-friendly controls

---

## Under the Hood

One of the primary goals of V2 was to make Gallformers easier to maintain and enhance going forward:

- **Fewer dependencies**: V1 relied on dozens of third-party packages that constantly needed updates and threw security warnings. V2 is built on a minimal, stable foundation.
- **Simpler architecture**: The new codebase is more straightforward, making it easier to add features and fix issues.
- **Better testing**: Comprehensive test coverage catches problems before they reach users.

This means more time spent on features and less time fighting with outdated libraries.

---

## URL Changes

If you have bookmarked admin pages, note these route changes:

| Old URL | New URL |
|---------|---------|
| `/admin/gall` | `/admin/galls` |
| `/admin/host` | `/admin/hosts` |
| `/admin/source` | `/admin/sources` |
| `/admin/place` | `/admin/places` |
| `/admin/filterterms` | `/admin/filter-terms` |
