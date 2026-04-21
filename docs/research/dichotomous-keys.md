# Dichotomous Keys: Research and Design

**Date**: 2026-01-23
**Status**: In Progress
**Purpose**: Explore storage and display of dichotomous keys for parasitoid/inquiline identification

---

## Background

Gallformers is expanding to include parasitoids and inquilines of galls. Unlike gall-formers (identifiable by gall morphology), these species often require dichotomous keys for identification. This document captures research on how to store, author, and display these keys.

---

## Existing Approaches Surveyed

### 1. WaspWeb (Static HTML)

**URL**: https://www.waspweb.org/Cynipoidea/Keys/Dichotomus_keys/Herb%20gall%20wasp%20tribes/index.htm

- Hand-crafted HTML with numbered couplets
- Each couplet has two choices (marked with bullets/daggers)
- Choices lead to either terminal identification or next couplet number
- Diagnostic images inline with arrows pointing to key features
- Terminal taxa link to detailed pages
- Simple, readable, but no interactivity

### 2. Flora of the Southeastern US (Database-driven)

**URL**: https://fsus.ncbg.unc.edu/main.php?pg=show-key.php&highlighttaxonid=65629

- Powered by **"Flora Manager"** - proprietary database system by Michael T. Lee at UNC
- Click-to-highlight mechanism for navigating couplets
- Glossary terms hyperlinked to definitions
- Keys can branch to sub-keys (nested structure)
- Permalink support for sharing specific positions
- JavaScript-driven UI state
- Covers 10,000+ taxa
- "Living database" - keys update when taxonomy changes
- **Completely undocumented, proprietary**

### 3. Current Gallformers Keys (Markdown)

Located in `v1/ref/`:
- `populusmidgekey.md` - Traditional numbered couplets with sub-numbering
- `populusaphidkey.md` - HTML `<details>`/`<summary>` for collapsible sections
- `vitisgallkey.md` - Simple numbered outline

**Common features**:
- Inline links to gallformers species pages
- External links to European references (bladmineerders.nl)
- Extensive prose with caveats ("may represent multiple species", "DNA evidence likely necessary")
- No diagnostic images
- Hand-authored by Adam Kranz

**Observations**:
- Midge key has couplet with **three choices** (not strictly binary)
- Aphid key has sections with 4+ choices
- `<details>` nesting getting deep (4+ levels) - markdown becoming unwieldy
- Links to species by URL (fragile if names change)

---

## Existing Software/Standards

| System | Type | Storage | Web-native? | Open Source? | Status |
|--------|------|---------|-------------|--------------|--------|
| **Flora Manager** | Custom | Database | Yes | No | Active, no docs |
| **DELTA/INTKEY** | Standard | Text format | No | Yes | Dated (2000s) |
| **DKey** | Editor | XML | No (Windows) | Yes | Active |
| **Lucid** | Platform | Proprietary | Yes (player) | No (commercial) | Active |

### DELTA (DEscription Language for TAxonomy)

- Standardized format from CSIRO (1971-2000)
- Adopted by TDWG (Biodiversity Information Standards)
- Separates data (characters × taxa) from presentation
- Can generate: natural-language descriptions, dichotomous keys, interactive keys
- **Problem**: Format is archaic, tooling dated, not web-native
- Resources:
  - https://www.tdwg.org/standards/delta/
  - https://www.delta-intkey.com/
  - https://freedelta.sourceforge.net/

### DKey

- Desktop XML editor for dichotomous keys
- Data model: numbered couplets, two leads each, pointer or endpoint
- Import text keys, export to HTML/RTF
- Windows-only, not web-native
- Paper: https://pmc.ncbi.nlm.nih.gov/articles/PMC5904324/
- Site: https://drawwing.org/dkey

### Lucid

- Commercial platform with two products:
  - **Lucid Matrix** - multi-access keys (answer questions in any order)
  - **Lucid Phoenix** - converts printed dichotomous keys to interactive format
- Has web player and mobile apps
- Proprietary, commercial licensing
- Site: https://www.lucidcentral.org/

---

## The Gap

There is no **modern, open-source, web-native system** for:
1. Storing dichotomous keys in a structured database
2. Allowing multiple authors to edit
3. Generating interactive web views
4. Linking to external taxonomic databases

We would be building something novel.

---

## Design Decisions

### Not Constrained to Binary Couplets

Real-world identification isn't always binary. Examples from our own keys:
- Midge key couplet 2 has three choices
- Aphid key has sections with 4+ choices
- Need to handle "these species are indistinguishable without DNA"

### Flexible Entry Methods

- Unknown import sources (Word docs? Markdown? PDFs?)
- Entry methods may evolve over time
- Start with authoring tool, add import later

### Validation Required

Keys need structural validation before publishing.

---

## Proposed Data Model

Think of it as a **decision tree**, not "couplets":
- **Nodes** - decision points with 2+ choices
- **Leads** - the choices at each node
- **Terminals** - endpoints (taxa, dead ends, sub-key links)

```
Key
├── id, title, author, description, target_group
├── source_citation, version, status (draft|published)
└── root_node_id

Node
├── id, key_id
├── display_number (flexible: "1", "2a", "3b-ii", or auto-generated)
├── prompt (optional: "Examine the gall location:")
└── leads[] (ordered, 2+)

Lead
├── id, node_id, position (ordering)
├── text (rich text description of this choice)
├── notes (the "easily confused with..." prose)
├── destination_type (:node | :taxon | :subkey | :dead_end)
├── destination_id (node_id, species_id, key_id, or null)
├── dead_end_reason ("DNA analysis required", etc.)
└── images[]

LeadImage
├── lead_id, image_url, caption
├── annotations (JSON: arrows, circles, labels)
```

This handles:
- Traditional binary couplets (node with 2 leads)
- Polytomous branching (node with 3+ leads)
- Dead ends with explanations
- Sub-key linking
- Rich annotations

---

## Authoring Tool Options

### Option 1: Tree-based Visual Editor

Display key as collapsible tree with inline editing:

```
[+] 1. Gall location
    ├─ Leaf edge roll → Prodiplosis morrisi
    └─ Not leaf edge roll
       [+] 2. Concentric circular spot?
           ├─ Yes, green spot
           │  [+] 3. Host identification
           │      ├─ P. balsamifera → p-balsamifera-leaf-gall
           │      ├─ P. tristis → p-tristis-leaf-spot
           │      └─ P. grandidentata → ?Harmandiola stebbinsae
           └─ No → [4. Larva concealment...]
```

**Pros**: Visual, intuitive structure
**Cons**: Complex to build, may be slow for large keys

### Option 2: Outline/Markdown Hybrid

Authors write in familiar outline format, system parses and validates:

```markdown
1. Leaf edge roll
   -> Prodiplosis morrisi

   1.1. Concentric circular spot with raised papilla
      -> [go to 2]

      2. Host identification
         a. P. balsamifera -> p-balsamifera-leaf-gall
         b. P. tristis -> p-tristis-leaf-spot
         c. P. grandidentata -> ?Harmandiola stebbinsae
```

**Pros**: Familiar to authors, good for bulk import
**Cons**: Parsing complexity, less visual feedback

### Option 3: Form-based Step-by-Step

Wizard: "Add a node" → "Add leads" → "Where does each lead go?"

**Pros**: Most guided, lowest learning curve
**Cons**: Slower for experienced authors

---

## Validation Rules

### Errors (blocking)

- [ ] All nodes reachable from root
- [ ] No orphan nodes
- [ ] All leads have destinations (or explicit dead_end)
- [ ] No circular references
- [ ] Referenced taxa exist in species table (if linked)

### Warnings (non-blocking)

- [ ] Single-lead nodes (why not skip to destination?)
- [ ] Very deep trees (>15 levels)
- [ ] Leads with no distinguishing text
- [ ] Taxa reachable by multiple paths (valid but worth flagging)

---

## Open Questions

1. **Species linking** - Must leads terminate at existing Species records, or allow free-text for taxa not yet in database?

2. **Collaboration model** - Can multiple authors edit same key? Need locking/versioning?

3. **Import formats** - What do incoming keys look like? Need to survey actual sources.

4. **Multi-access keys** - Do we need Lucid-style "answer in any order" or is traditional path-based sufficient?

5. **MVP scope** - What's the smallest useful thing? Suggested: one key, one author, basic tree editor, export to readable HTML.

---

## Resources

- TDWG DELTA Standard: https://www.tdwg.org/standards/delta/
- DKey paper: https://pmc.ncbi.nlm.nih.gov/articles/PMC5904324/
- DKey software: https://drawwing.org/dkey
- Lucid: https://www.lucidcentral.org/
- Flora of SE US: https://fsus.ncbg.unc.edu/
- FreeDelta: https://freedelta.sourceforge.net/

---

## Next Steps

- [ ] Survey actual key sources to understand import needs
- [ ] Decide on MVP scope
- [ ] Prototype authoring UI to understand what feels right
- [ ] Design database schema
- [ ] Consider integration with existing Species/Glossary tables
