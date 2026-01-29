# Taxonomy System

This document describes how taxonomy works in Gallformers, including the data model, business rules, and admin operations.

## Overview

Gallformers uses a four-level taxonomic hierarchy to classify both **gall-forming organisms** (insects, mites, etc.) and **host plants**. The two taxonomies are separated by the **family type** field on Families.

## Hierarchy

```
Family
└── Genus (belongs to exactly 1 Family)
    └── Section (optional; belongs to exactly 1 Genus)
        └── Species (belongs to exactly 1 Genus and 0 or 1 Section)
```

**Key relationships:**
- A Family contains zero or more Genera
- A Genus contains zero or more Sections
- A Genus must belong to exactly 1 Family
- A Section must belong to exactly 1 Genus
- A Species must belong to exactly 1 Genus
- A Species may optionally belong to 1 Section within its Genus

**Note:** Sections exist only in **host (plant) taxonomy**. Gall-former taxonomy does not use sections.

## Attributes

| Level | Required Fields | Optional Fields |
|-------|-----------------|-----------------|
| Family | name, family type | - |
| Genus | name | description |
| Section | name | description |

- **name**: The taxonomic name (e.g., "Fagaceae", "Quercus")
- **description**: For genera/sections, usually a common name (e.g., "oaks" for Quercus)
- **family type**: For families only - categorizes what kind of organism the family contains (see below)

## Family Types

Families have a **type** that categorizes the kind of organism they contain. This is stored in the `description` field of the taxonomy table.

**Gall-former family types:**
- Aphid, Bacteria, Beetle, Fly, Fungus, Midge, Mite, Moth, Nematode, Oomycete, Psyllid, Sawfly, Scale, Thrips, True Bug, Unknown, Virus, Wasp

**Host family type:**
- Plant

The family type determines whether it's a **gall family** or **host family**:
- If family type = "Plant" → host family (contains host plants)
- If family type = anything else → gall family (contains gall-forming organisms)

**Note:** The `taxoncode` field exists on the **species** table (not taxonomy), with values "gall" or "plant". This is the fundamental binary classification at the species level.

## Uniqueness Rules

- **Family names**: Globally unique across all families
- **Genus names**: Unique within a Family (note: genus names can clash across different families - this happens in real taxonomy)
- **Section names**: Unique within a Genus

## Unknown Handling

The system has special handling for unclassified/undescribed species:

### Unknown Family
- One special "Unknown" Family exists for gall-formers
- Used when the family of an undescribed gall is not known
- Should not be editable (name is fixed)

### Unknown Genera
- Each Family should have an "Unknown" Genus
- Used when a species' family is known but genus is not
- The Unknown Family contains only its Unknown Genus
- Unknown genera should not be editable
- V2 should auto-create Unknown genera when Families are created

### Unknown Genus Display Filtering

Empty Unknown genera create UI noise if displayed everywhere. They should be **hidden by default** in:
- Browse pages (species listings by genus)
- Global search results
- Admin taxonomy views
- Any dropdown/typeahead that lists genera

**Exception:** Unknown genera with species assigned should be displayed normally.

**Implementation:** Query filters should exclude Unknown genera that have no species, or the UI should filter them client-side. Consider a toggle in admin views to show all genera including empty Unknown ones.

### Undescribed Species Workflow

When creating an undescribed species (gall), there are three scenarios:

1. **Family unknown**: Assign to Unknown Family → Unknown Genus
2. **Family known, Genus unknown**: Assign to known Family → Unknown Genus
3. **Family and Genus known**: Assign to known Family → known Genus

## Admin Operations

### Family Operations

| Operation | Supported | Notes |
|-----------|-----------|-------|
| Create | Yes | Requires name and taxoncode |
| Edit name | Yes | Must remain unique |
| Edit description | Yes | |
| Delete | Yes | **Cascades** - deletes all genera, sections, and species. Use with extreme caution. |
| Move | N/A | Families are top-level |

### Genus Operations

| Operation | Supported | Notes |
|-----------|-----------|-------|
| Create | Yes | Within a Family |
| Edit name | Yes | Updates species binomial names automatically |
| Edit description | Yes | |
| Delete | Yes | **Cascades** - deletes all sections and species |
| Move to different Family | Yes | Sections and species travel with the genus |

### Section Operations (Host Taxonomy Only)

Sections only exist for host plants, not gall-formers.

| Operation | Supported | Notes |
|-----------|-----------|-------|
| Create | Yes | Within a Genus |
| Edit name | Yes | |
| Edit description | Yes | |
| Delete | Yes | Species lose their section assignment but remain in genus |
| Move to different Genus | **No** | Not supported (V1 didn't support this either) |
| Assign species | Yes | Via Section admin page |

### Species-Section Assignment (Host Taxonomy Only)

Host species can be assigned to or removed from Sections. This is managed through a dedicated Section admin interface, not the Host detail pages.

**Constraint:** All species in a Section must belong to the same Genus (the Section's parent).

## Cascade Behavior on Delete

Deleting a taxonomy entry cascades to all children:

- **Delete Family** → Deletes all Genera → Deletes all Sections → Deletes all Species
- **Delete Genus** → Deletes all Sections → Deletes all Species
- **Delete Section** → Species remain but lose section assignment

**Warning:** These are destructive operations. The admin UI should require confirmation and clearly explain what will be deleted.

## Renaming and Species Names

When a Genus is renamed:
1. The genus record is updated
2. All species binomial names (Genus species) are automatically updated
3. Synonyms may be created for the old names (implementation-specific)

This automation was added to prevent orphaned species names.

## Two Taxonomies: Galls vs Hosts

The same taxonomy structure is used for both gall-formers and host plants. They are distinguished by the `taxoncode` field on Families:

- **Gall families**: taxoncode indicates gall-former (insects, mites, etc.)
- **Plant families**: taxoncode indicates plant

The admin UI should present these as separate views or clearly distinguish between them.

## V2 Implementation Status

| Feature | V1 | V2 Status |
|---------|-----|-----------|
| Family CRUD | Yes | Partial (needs taxoncode fix) |
| Genus CRUD | Yes | Yes |
| Genus move | Yes | **Missing** |
| Section CRUD | Yes | **Missing** (no Section admin page) |
| Species-Section assignment | Yes | **Missing** |
| Unknown auto-creation | Manual | **Planned** |
| Genus rename with species update | Yes | Yes (added recently) |

## Future Considerations

### Merge Operations
Neither V1 nor V2 support merging taxa (combining two genera into one when they turn out to be synonyms). This is a common taxonomic operation that could be valuable.

### Split Operations
Similarly, splitting a taxon into multiple new taxa is not supported but could be useful.

### Empty Section Handling
Sections with no species serve no purpose in the public UI. Consider:
- Preventing creation of empty sections
- Warning when a section becomes empty
- Hiding empty sections from non-admin views
