-- =============================================================================
-- Global Search Queries
-- =============================================================================
-- These queries support the unified global search endpoint that searches
-- across species (with aliases), glossary, sources, taxonomy, and places.

-- -----------------------------------------------------------------------------
-- Species Search (includes aliases)
-- -----------------------------------------------------------------------------

-- name: GlobalSearchSpecies :many
-- Search species by name (case-insensitive LIKE). Returns species with taxoncode.
SELECT
    s.id,
    s.name,
    s.taxoncode
FROM species s
WHERE s.name LIKE '%' || ? || '%'
ORDER BY s.name ASC
LIMIT 100;

-- name: GlobalSearchSpeciesByAlias :many
-- Search species via their aliases. Returns distinct species that match alias search.
SELECT DISTINCT
    s.id,
    s.name,
    s.taxoncode
FROM species s
INNER JOIN aliasspecies als ON s.id = als.species_id
INNER JOIN alias a ON als.alias_id = a.id
WHERE a.name LIKE '%' || ? || '%'
ORDER BY s.name ASC
LIMIT 100;

-- name: GetAliasesForSpecies :many
-- Get all alias names for a given species ID.
SELECT a.name
FROM alias a
INNER JOIN aliasspecies als ON a.id = als.alias_id
WHERE als.species_id = ?
ORDER BY a.name ASC;

-- -----------------------------------------------------------------------------
-- Glossary Search
-- -----------------------------------------------------------------------------

-- name: GlobalSearchGlossary :many
-- Search glossary entries by word or definition (case-insensitive LIKE).
SELECT
    id,
    word,
    definition
FROM glossary
WHERE word LIKE '%' || ? || '%' OR definition LIKE '%' || ? || '%'
ORDER BY word COLLATE NOCASE ASC
LIMIT 100;

-- -----------------------------------------------------------------------------
-- Source Search
-- -----------------------------------------------------------------------------

-- name: GlobalSearchSources :many
-- Search sources by title or author (case-insensitive LIKE).
SELECT
    id,
    title,
    author,
    pubyear,
    citation
FROM source
WHERE title LIKE '%' || ? || '%' OR author LIKE '%' || ? || '%'
ORDER BY title ASC
LIMIT 100;

-- -----------------------------------------------------------------------------
-- Taxonomy Search (genus, section, family)
-- -----------------------------------------------------------------------------

-- name: GlobalSearchTaxa :many
-- Search taxonomy entries (genus, section, family) by name or description.
SELECT
    id,
    name,
    description,
    type
FROM taxonomy
WHERE (name LIKE '%' || ? || '%' OR description LIKE '%' || ? || '%')
  AND type IN ('genus', 'section', 'family')
ORDER BY name ASC
LIMIT 100;

-- -----------------------------------------------------------------------------
-- Place Search
-- -----------------------------------------------------------------------------

-- name: GlobalSearchPlaces :many
-- Search places by name or code (case-insensitive LIKE).
SELECT
    id,
    name,
    code,
    type
FROM place
WHERE name LIKE '%' || ? || '%' OR code LIKE '%' || ? || '%'
ORDER BY name ASC
LIMIT 100;
