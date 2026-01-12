-- =============================================================================
-- Taxonomy Queries
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Basic Taxonomy CRUD
-- -----------------------------------------------------------------------------

-- name: GetTaxonomyByID :one
-- Get a taxonomy entry by ID with parent info
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.id = ?;

-- name: GetTaxonomyByName :many
-- Get taxonomy entries by exact name match
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.name = ?;

-- name: GetTaxonomyForSpecies :many
-- Get taxonomy entries (genus, family, section) for a species
-- Returns the genus, its parent family, and any sections
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM speciestaxonomy st
JOIN taxonomy t ON st.taxonomy_id = t.id
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE st.species_id = ?;

-- name: InsertTaxonomy :execlastid
-- Insert a new taxonomy entry
INSERT INTO taxonomy (name, description, type, parent_id)
VALUES (?, ?, ?, ?);

-- name: UpdateTaxonomy :exec
-- Update an existing taxonomy entry
UPDATE taxonomy
SET name = ?, description = ?, parent_id = ?
WHERE id = ?;

-- name: DeleteTaxonomy :exec
-- Delete a taxonomy entry (cascades to children via FK)
DELETE FROM taxonomy WHERE id = ?;

-- name: DeleteSpeciesForFamily :exec
-- Delete all species belonging to genera under a family
DELETE FROM species
WHERE id IN (
    SELECT s.id
    FROM taxonomy AS f
    INNER JOIN taxonomy AS g ON f.id = g.parent_id
    INNER JOIN speciestaxonomy AS st ON st.taxonomy_id = g.id
    INNER JOIN species AS s ON s.id = st.species_id
    WHERE f.id = ?
);

-- name: DeleteSpeciesTaxonomyByTaxonomyID :exec
-- Delete speciestaxonomy entries for a taxonomy
DELETE FROM speciestaxonomy WHERE taxonomy_id = ?;

-- name: InsertSpeciesTaxonomy :exec
-- Link a species to a taxonomy entry
INSERT INTO speciestaxonomy (species_id, taxonomy_id) VALUES (?, ?);

-- name: DeleteSpeciesTaxonomyForSpecies :exec
-- Delete all speciestaxonomy entries for a species
DELETE FROM speciestaxonomy WHERE species_id = ?;

-- -----------------------------------------------------------------------------
-- Family Queries
-- -----------------------------------------------------------------------------

-- name: ListFamilies :many
-- List all families ordered by name
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id
FROM taxonomy t
WHERE t.type = 'family'
ORDER BY t.name ASC;

-- name: GetFamilyByID :one
-- Get a family by ID
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id
FROM taxonomy t
WHERE t.id = ? AND t.type = 'family';

-- name: GetFamilyByName :one
-- Get a family by exact name match
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id
FROM taxonomy t
WHERE t.name = ? AND t.type = 'family';

-- name: SearchFamilies :many
-- Search families by name (case-insensitive LIKE)
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id
FROM taxonomy t
WHERE t.type = 'family' AND t.name LIKE ?
ORDER BY t.name ASC;

-- name: CountFamilies :one
-- Count total families
SELECT COUNT(*) as count FROM taxonomy WHERE type = 'family';

-- name: GetGeneraForFamily :many
-- Get all genera belonging to a family
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id
FROM taxonomy t
WHERE t.parent_id = ? AND t.type = 'genus'
ORDER BY t.name ASC;

-- name: InsertFamily :execlastid
-- Insert a new family
INSERT INTO taxonomy (name, description, type, parent_id)
VALUES (?, ?, 'family', NULL);

-- name: UpdateFamily :exec
-- Update a family
UPDATE taxonomy
SET name = ?, description = ?
WHERE id = ? AND type = 'family';

-- name: DeleteFamily :exec
-- Delete a family (also deletes child genera via cascade)
DELETE FROM taxonomy WHERE id = ? AND type = 'family';

-- -----------------------------------------------------------------------------
-- Genus Queries
-- -----------------------------------------------------------------------------

-- name: ListGenera :many
-- List all genera ordered by name
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.type = 'genus'
ORDER BY t.name ASC;

-- name: ListGeneraByTaxon :many
-- List genera that have species of a given taxoncode
SELECT DISTINCT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
JOIN speciestaxonomy st ON st.taxonomy_id = t.id
JOIN species s ON st.species_id = s.id
WHERE t.type = 'genus' AND s.taxoncode = ?
ORDER BY t.name ASC;

-- name: GetGenusByID :one
-- Get a genus by ID
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.id = ? AND t.type = 'genus';

-- name: SearchGenera :many
-- Search genera by name (case-insensitive LIKE)
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.type = 'genus' AND t.name LIKE ?
ORDER BY t.name ASC;

-- name: CountGenera :one
-- Count total genera
SELECT COUNT(*) as count FROM taxonomy WHERE type = 'genus';

-- name: InsertGenus :execlastid
-- Insert a new genus
INSERT INTO taxonomy (name, description, type, parent_id)
VALUES (?, ?, 'genus', ?);

-- name: UpdateGenus :exec
-- Update a genus
UPDATE taxonomy
SET name = ?, description = ?, parent_id = ?
WHERE id = ? AND type = 'genus';

-- name: MoveGenusToFamily :exec
-- Move a single genus to a new family (update parent_id)
UPDATE taxonomy
SET parent_id = ?
WHERE id = ? AND type = 'genus';

-- name: DeleteTaxonomyTaxonomyByChildID :exec
-- Delete taxonomytaxonomy entry for a single child ID and parent
DELETE FROM taxonomytaxonomy
WHERE child_id = ? AND taxonomy_id = ?;

-- name: InsertTaxonomyTaxonomy :exec
-- Insert a taxonomytaxonomy relationship
INSERT INTO taxonomytaxonomy (taxonomy_id, child_id) VALUES (?, ?);

-- name: UpdateSpeciesNamesForGenus :exec
-- Update species names when genus name changes (replace genus part of binomial)
-- @new_genus: the new genus name to use
-- @taxonomy_id: the taxonomy ID of the genus
UPDATE species
SET name = REPLACE(name, SUBSTR(name, 1, INSTR(name, ' ') - 1), sqlc.arg(new_genus))
WHERE id IN (
    SELECT st.species_id
    FROM taxonomy AS t
    INNER JOIN speciestaxonomy AS st ON t.id = st.taxonomy_id
    WHERE t.id = sqlc.arg(taxonomy_id)
);

-- -----------------------------------------------------------------------------
-- Section Queries
-- -----------------------------------------------------------------------------

-- name: ListSections :many
-- List all sections ordered by name
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.type = 'section'
ORDER BY t.name ASC;

-- name: GetSectionByID :one
-- Get a section by ID
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.id = ? AND t.type = 'section';

-- name: GetSectionByName :one
-- Get a section by exact name match
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.name = ? AND t.type = 'section';

-- name: SearchSections :many
-- Search sections by name (case-insensitive LIKE)
SELECT
    t.id,
    t.name,
    t.description,
    t.type,
    t.parent_id,
    p.name AS parent_name,
    p.type AS parent_type
FROM taxonomy t
LEFT JOIN taxonomy p ON t.parent_id = p.id
WHERE t.type = 'section' AND t.name LIKE ?
ORDER BY t.name ASC;

-- name: CountSections :one
-- Count total sections
SELECT COUNT(*) as count FROM taxonomy WHERE type = 'section';

-- name: GetSpeciesForTaxonomy :many
-- Get all species linked to a taxonomy entry (section or genus)
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id
FROM speciestaxonomy st
JOIN species s ON st.species_id = s.id
WHERE st.taxonomy_id = ?
ORDER BY s.name ASC;

-- name: GetAliasesForTaxonomy :many
-- Get all aliases for a taxonomy entry
SELECT
    a.id,
    a.name,
    a.type,
    a.description
FROM taxonomyalias ta
JOIN alias a ON ta.alias_id = a.id
WHERE ta.taxonomy_id = ?
ORDER BY a.name ASC;

-- name: InsertSection :execlastid
-- Insert a new section
INSERT INTO taxonomy (name, description, type, parent_id)
VALUES (?, ?, 'section', ?);

-- name: UpdateSection :exec
-- Update a section
UPDATE taxonomy
SET name = ?, description = ?, parent_id = ?
WHERE id = ? AND type = 'section';

-- name: DeleteSection :exec
-- Delete a section (removes speciestaxonomy links but not the species themselves)
DELETE FROM taxonomy WHERE id = ? AND type = 'section';

-- name: InsertTaxonomyAlias :exec
-- Link an alias to a taxonomy entry
INSERT INTO taxonomyalias (taxonomy_id, alias_id) VALUES (?, ?);

-- name: DeleteTaxonomyAlias :exec
-- Remove an alias from a taxonomy entry
DELETE FROM taxonomyalias WHERE taxonomy_id = ? AND alias_id = ?;

-- name: DeleteAllTaxonomyAliases :exec
-- Remove all aliases from a taxonomy entry
DELETE FROM taxonomyalias WHERE taxonomy_id = ?;
