# Triaging Gall Species Data: Undescribed Status and Gallformers Codes

## What We're Doing and Why

We are separating two concepts that have been tangled together since V1: **taxonomic status** (is the species formally described in the literature?) and **data completeness** (does our Gallformers entry have all the information we want?). Today, these are conflated — a gall can be marked "undescribed" simply because it lacks a source in our database, even if the species is well-known to science.

At the same time, we're formalizing the **Gallformers Code** — the identifier we use to link undescribed galls to iNaturalist observations. Currently, the code is a hack: it's embedded in the species name as the specific epithet (the part with dashes, like `q-lobata-leaf-blister`). This coupling between naming and identification has created data inconsistencies that are difficult to detect and painful to fix.

The data audit below makes the case clearly: **we must formalize how we handle undescribed species and gallformers codes.** The current ad-hoc system has produced hundreds of mismatches between the undescribed flag, genus assignment, and name patterns. Without explicit data fields and enforced rules, these inconsistencies will continue to accumulate.

### What Changes

1. **Gallformers Code becomes a real database field** — no longer derived from the species name
2. **Undescribed means undescribed** — only locked by genus assignment (Unknown genera), not by missing sources
3. **Data completeness gets guardrails** — a gall cannot be marked "complete" without at least one source, and undescribed galls are never complete
4. The data migration will fix the existing inconsistencies documented below

### What We Need From Reviewers

Three items require human decisions before the migration can run. They are marked with **ACTION NEEDED** below. Everything else has been triaged and has clear automated rules.

---

## Data Audit Results

Data queried from production snapshot on 2026-02-15. Total gall species: 3,670.

### Epithet Dash Patterns

The specific epithet (second part of the binomial name) tells us a lot. Constructed gallformers codes use dashes to combine host abbreviation + gall description (e.g., `q-lobata-leaf-blister`). Real taxonomic epithets almost never contain dashes.

| Dashes in Epithet | Count | Interpretation |
|-------------------|-------|----------------|
| 0 | 2,283 | Normal taxonomic epithets |
| 1 | 27 | Mixed — some real epithets, some codes |
| 2 | 52 | Mixed — mostly codes, two real epithets |
| 3+ | 1,308 | All constructed gallformers codes |

**The 1-dash and 2-dash gray zone:**

All galls with 3+ dashes are undescribed with the epithet as the gallformers code. For 1 and 2 dashes, most follow the same rule, but the following are legitimate described species with naturally hyphenated epithets:

- **1 dash, described (21 species):** [Gymnosporangium juniperi-virginianae](https://gallformers.org/gall/778), [Hamamelistes spinosus (on-hamamelis)](https://gallformers.org/gall/1005), [Neuroterus quercusbatatus (sexgen) (q-bicolor)](https://gallformers.org/gall/1339), [Neuroterus quercusbatatus (agamic) (q-bicolor)](https://gallformers.org/gall/1340), [Albugo ipomoeae-panduratae](https://gallformers.org/gall/1373), [Heteroecus sanctae-clarae (agamic)](https://gallformers.org/gall/1906), [Neuroterus quercicola (pacificus) (sexgen) (q-lobata)](https://gallformers.org/gall/1996), [Hamamelistes spinosus (on-betula)](https://gallformers.org/gall/2255), [Eriosoma lanigerum (on-malus)](https://gallformers.org/gall/2688), [Neuroterus quercicola (pacificus) (sexgen) (q-douglasii)](https://gallformers.org/gall/3167), [Puccinia mariae-wilsoniae](https://gallformers.org/gall/3346), [Hormaphis cornu (on-hamamelis)](https://gallformers.org/gall/3979), [Hormaphis cornu (on-betula)](https://gallformers.org/gall/3981), [Taphrina populi-salicis](https://gallformers.org/gall/3992), [Eriosoma lanigerum (on-ulmus)](https://gallformers.org/gall/4089), [Prociphilus caryae (on-amelanchier)](https://gallformers.org/gall/4092), [Taphrina pruni-subcordatae](https://gallformers.org/gall/4603), [Exobasidium uvae-ursi](https://gallformers.org/gall/4792), [Exobasidium vaccinii-uliginosi](https://gallformers.org/gall/5027), [Gymnosporangium nidus-avis on Juniper](https://gallformers.org/gall/5578), [Hyaloperonospora sisymbrii-loeselii](https://gallformers.org/gall/5645)
- **2 dashes, described (2 species):** [Eriophyes cerasicrumena (on-p-serotina)](https://gallformers.org/gall/633), [Emaravirus rose-rosette-disease](https://gallformers.org/gall/4614)

Everything else with 1+ dashes is undescribed with the epithet as the gallformers code.

### Undescribed Flag vs. Genus Type

| Genus Type | Status | Count | Assessment |
|------------|--------|-------|------------|
| Real genus | described | 2,234 | Correct |
| Real genus | undescribed | 656 | Most are wrong — see below |
| Unknown genus | undescribed | 780 | Correct |
| Unknown genus | described | 0 | Good — no violations |

**656 galls with a real genus are marked undescribed.** The vast majority of these were auto-marked by a previous migration that equated "no sources" with "undescribed." That was incorrect — having a real genus and a real epithet means the species is described; we just haven't added the source yet. These will be fixed.

### Undescribed Galls Without Dashes

These are flagged `undescribed=true` but have a normal epithet (no dashes). All should be set to **described**, except one:

- [Unknown (Cynipidae) dentatae](https://gallformers.org/gall/1115) — genuinely undescribed (Unknown genus) but the name doesn't follow our conventions. See **ACTION NEEDED #1** below.

### Described Galls With Dashes

Two galls have dashes in their epithet but aren't in the exclusion list above:
- [Hamamelistes spinosus (on-hamamelis)](https://gallformers.org/gall/1005) — legitimate hyphenated epithet, confirmed described
- [Synergus deforming-pacificus](https://gallformers.org/gall/2235) — should actually be **undescribed** (will be fixed in migration)

### Former Undescribed Aliases

No `former_undescribed` aliases exist in the database as of this audit. The migration will still handle them defensively in case any are created before the migration runs.

### Data Completeness Without Sources

Some galls are marked `datacomplete=true` but have zero sources attached. All will be set to incomplete. Going forward, the system will enforce: **no sources = cannot be marked complete**, and **undescribed = cannot be marked complete**.

---

## Items Requiring Human Review

### ACTION NEEDED #1: Rename gall [Unknown (Cynipidae) dentatae](https://gallformers.org/gall/1115)

| Field | Value |
|-------|-------|
| Current name | `Unknown (Cynipidae) dentatae` |
| Genus | Unknown (Cynipidae) |
| Host | Castanea dentata |
| Problem | Epithet `dentatae` doesn't follow our code conventions — it's a Latin genitive of the host name, not a gallformers code |

**Needs:** A proper constructed name like `Unknown (Cynipidae) c-dentata-<descriptor>`. The descriptor should reflect a distinguishing trait of this gall. Please review the gall's traits and suggest an appropriate name.

The migration will skip this gall. It must be renamed manually before or after the migration.

### ACTION NEEDED #2: Resolve duplicate gallformers codes

Two pairs of galls share the same epithet (which becomes the gallformers code). A gallformers code must be unique — it's an identifier used in iNaturalist observation fields. Duplicates would make it impossible to link observations to the correct gall.

| Gallformers Code | Species | Host | Links |
|-----------------|---------|------|-------|
| `r-carolina-folded-terminal-leaflet` | [Dasineura r-carolina-folded-terminal-leaflet](https://gallformers.org/gall/4081) and [Contarinia r-carolina-folded-terminal-leaflet](https://gallformers.org/gall/4082) | Rosa carolina | |
| `c-americana-enlarged-bud-gall` | [Contarinia c-americana-enlarged-bud-gall](https://gallformers.org/gall/2747) and [Dasineura c-americana-enlarged-bud-gall](https://gallformers.org/gall/5443) | Corylus americana, C. cornuta | |

Each pair appears to be the same gall attributed to two candidate inducer genera. Options:

1. **Merge** — delete one entry per pair if they're truly the same gall (most likely correct)
2. **Disambiguate** — give each a distinct code (e.g., append `-d` / `-c` for Dasineura/Contarinia) if both entries should remain as separate galls
3. **Share the code** — allow duplicate codes (undermines the purpose of unique identification on iNat)

**These must be resolved before the migration runs.** The migration will add a unique constraint on gallformers codes.

---

## Migration Rules (Automated)

Once the action items above are resolved, the migration will apply these rules:

### 1. Populate gallformers_code field

For every gall with 1+ dashes in its epithet, set `gallformers_code` = epithet. **Exclude** the 23 legitimate described species listed above (21 with 1 dash, 2 with 2 dashes).

Also populate from `former_undescribed` aliases if any exist at migration time (none today).

### 2. Fix undescribed flags

- [Synergus deforming-pacificus](https://gallformers.org/gall/2235) → set undescribed = true
- **All undescribed galls with real genus AND no dashes in epithet** → set undescribed = false (except [Unknown (Cynipidae) dentatae](https://gallformers.org/gall/1115), which is skipped for manual fix)
- **All galls under Unknown genera** → ensure undescribed = true (already the case today)

### 3. Fix data completeness

- All galls without sources → set datacomplete = false
- All undescribed galls → set datacomplete = false

### 4. Enforce gallformers code uniqueness

- Add unique index on `gall_traits.gallformers_code` (only enforced when non-null)
- Add validation in the application to prevent collisions going forward

### 5. Clean up former_undescribed aliases

- Convert any `former_undescribed` aliases to `scientific` type
- None exist today; handled defensively
