# Gallformers — System Context

## What Gallformers Is

Gallformers is an online database and identification tool for plant galls — abnormal growths on plants caused by insects, mites, fungi, bacteria, and other organisms. It serves researchers, taxonomists, and naturalists who need to identify galls, look up what's known about them, and contribute new data.

The site lives at gallformers.org. It covers gall-forming organisms worldwide.

## The Domain

### Galls

A gall is a structure that a plant grows in response to manipulation by another organism. The plant does the building; the organism (the "inducer") hijacks the plant's growth. Galls are specific — a given inducer typically makes a recognizable gall on a specific set of host plants.

Each gall in the system is characterized by:

- **Host plants** — which plant species it occurs on (often multiple)
- **Location on the plant** — leaf, stem, bud, petiole, root, flower, fruit, etc.
- **Morphology** — shape, color, texture, alignment (clustered vs. solitary), wall structure, internal cells
- **Seasonality** — when the gall appears
- **Detachability** — whether it falls from the plant
- **Form** — the broad category of gall type
- **Abundance** — how commonly encountered

About 37% of gall records in the system are "undescribed" — the gall is known to exist (often documented via iNaturalist observations) but the inducing organism hasn't been formally described by taxonomists. These are tracked with internal codes that link back to iNaturalist observation pages.

### Host Plants

The plants that galls form on. Each host has taxonomy (family, genus, species), geographic range data, and associations to the galls found on it. Host range data comes from the World Checklist of Vascular Plants (WCVP) and manual curation.

### Taxonomy

Both galls and hosts follow standard biological classification: Family → Genus → Species, with optional intermediate ranks (subfamily, tribe, subtribe) between family and genus, and optional sections within genera. The system tracks scientific synonyms and common names for both galls and hosts.

Taxonomy is not static — species get renamed, reclassified into different genera, split into multiple species, or merged. The system supports renaming and reclassifying species but does not yet have formal merge/split operations or taxonomic versioning.

### Sources

Scientific literature references. Each species can be linked to multiple sources with per-species descriptions of what that source says about that species. Sources are the evidentiary backbone — every claim in the system should be traceable to a published reference.

### Geographic Range

Species have geographic ranges expressed as place codes (countries, states, provinces). Gall ranges are computed from both direct assignments and the ranges of their host plants. Ranges can include exclusions — "this gall occurs wherever its host does, except in these specific places."

### Images

Photographs of galls and host plants, stored with creator attribution and license information. Images are the primary visual identification aid.

## What the System Does Today

### For Visitors

**Identification.** The central feature. A multi-filter tool that lets someone describe a gall they've found — pick the host plant, the plant part, the shape, color, texture, season, location — and narrow down to matching species. Filters combine to progressively reduce the candidate list. Filter state is encoded in the URL, so a search can be bookmarked and shared. The system can also be scoped to a geographic region.

**Browsing.** Hierarchical browsing of all gall species and host plants organized by family and genus. Full-text search across all entity types (galls, hosts, sources, glossary, taxonomy).

**Species profiles.** Each gall and host has a detail page showing its traits, taxonomy, range map, images, synonyms, related species, and scientific sources with inline descriptions. Gall pages link to their hosts; host pages link to their galls with a one-click path to the ID tool filtered by that host.

**Identification keys.** Interactive dichotomous keys — click-through couplets where each choice leads to the next question or a terminal identification. Keys can be downloaded as PDFs.

**Reference material.** A glossary of gall terminology (with tooltips used throughout the site), articles, and a filter guide explaining what each ID tool option means.

**Public API.** A documented REST API providing access to galls, hosts, taxonomy, sources, glossary, places, images, search, and site statistics. Rate-limited and CORS-enabled for third-party use.

**Public analytics.** Site usage statistics are visible to anyone — page views, visitors, top pages, referrers.

### For Administrators

**Species data management.** Create and edit gall and host records with full trait entry, taxonomy assignment, alias management, and reclassification. A streamlined flow exists for quickly creating undescribed gall records linked to iNaturalist observations.

**Gall-host mapping.** A dedicated tool for managing which galls occur on which hosts, with geographic exclusion controls.

**Source management.** Create sources and link them to species with per-species descriptions. A bulk workflow supports the common pattern of "I have a new paper and need to document all the species it covers" — the source stays pinned while cycling through species.

**Image management.** Upload, reorder, and annotate images per species. An audit tool finds orphaned images (in storage but not linked to any species) and unattributed images (missing license or creator).

**Taxonomy management.** Create and edit families, genera, intermediate ranks, and sections with parent-child relationships.

**Content management.** Edit articles (markdown), glossary entries, and identification keys.

**WCVP reconciliation.** Reports comparing Gallformers host data against the World Checklist of Vascular Plants — finds taxonomy mismatches, species not in WCVP, and range data that could be imported.

## Scale

| | Count |
|---|---|
| Gall species | ~3,700 |
| Host plant species | ~2,200 |
| Undescribed galls | ~1,400 |
| Gall-host associations | ~8,100 |
| Scientific sources | ~850 |
| Species-source citations | ~7,900 |
| Images | ~6,600 |
| Geographic places | ~4,500 |
| Identification keys | 4 |
| Glossary terms | 49 |

The database grows steadily as new galls are described in the literature and new observations surface undescribed galls. Most growth is in gall records, gall-host associations, and images.

## What "Possible" and "Hard" Mean Here

### The Constraints

Gallformers is maintained by one developer. There is no team, no budget for paid services beyond basic hosting, and no plans to change that. This isn't a limitation to apologize for — it's a design constraint that shapes every decision. Features that require ongoing operational attention or complex infrastructure are more costly than their code suggests.

The system runs on a single-server architecture with a file-based database. This is deliberately simple and keeps operational burden low. It handles current traffic fine. It means some things that are trivial in distributed systems (real-time collaboration, background job queues, full-text search with ranking) require more creative solutions here.

### What's Easy

- Adding new data fields to existing species records
- New filter dimensions in the identification tool
- New browsable/searchable content types (if they follow existing patterns)
- New identification keys
- Expanding the API to expose more of what the site already shows
- Geographic expansion (the infrastructure is already worldwide)
- Bulk data import from structured sources (CSV, standardized formats)
- New reports and views over existing data
- UI improvements to existing workflows

### What's Moderate

- New entity types with their own lifecycle (not just a field on a species)
- Cross-entity relationships beyond gall-host (e.g., parasitoid-gall, inquiline-gall)
- Integration with external databases (GBIF, iNaturalist, Wikidata) — API work plus ongoing data reconciliation
- Contributor workflows where non-admin users can submit data for review
- Notification systems

### What's Hard

- Anything requiring real-time synchronization with external services
- Machine learning / AI features that need model hosting or GPU
- Features requiring always-on background processing
- Multi-user simultaneous editing of the same data
- Features that would require fundamentally different infrastructure (e.g., graph databases, search engines)

### What Matters Most

The primary value is the data — gall records, images, host associations, and scientific sources. Code serves to make that data accessible and maintainable. Any feature discussion should ultimately come back to: does this help people find, understand, contribute, or use the data?

## How People Use the System

### Researchers and Taxonomists

Researchers use Gallformers as a reference when they encounter a gall, when they're writing papers, or when they need to understand what's already known. They care about:

- **Completeness** — is the species they're studying represented? Are the sources cited?
- **Accuracy** — are the taxonomic assignments current? Are synonyms tracked?
- **Traceability** — can every claim be traced to a published source?
- **Undescribed species** — the ~1,400 undescribed galls represent open research questions

### Naturalists and Identifiers

People who find galls in the field and want to know what they're looking at. They care about:

- **The ID tool working** — narrow down candidates quickly from observable traits
- **Good images** — visual comparison is how most identification happens
- **Host plant as entry point** — "I found something on this oak" is the most common starting point
- **Geographic relevance** — knowing what's expected in their region

### Data Contributors (Current: Admins Only)

Currently, only administrators can modify data. Contributors are expert volunteers who communicate what needs changing. They care about:

- **Efficient data entry** — especially bulk operations (new paper with 30 species)
- **Accuracy safeguards** — hard to accidentally break data
- **Source tracking** — everything linked to its evidence
