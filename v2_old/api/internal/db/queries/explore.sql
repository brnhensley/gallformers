-- =============================================================================
-- Explore Page Queries
-- =============================================================================
-- These queries support the hierarchical tree browser on the explore page.
-- Returns families with their genera and species for building tree navigation.

-- name: GetGallFamiliesWithSpecies :many
-- Get all gall families with their genera and species for the explore tree.
-- Returns rows that can be assembled into a tree: family -> genus -> species
SELECT
    f.id AS family_id,
    f.name AS family_name,
    f.description AS family_description,
    g.id AS genus_id,
    g.name AS genus_name,
    g.description AS genus_description,
    s.id AS species_id,
    s.name AS species_name,
    s.taxoncode AS species_taxoncode
FROM taxonomy f
INNER JOIN taxonomy g ON g.parent_id = f.id AND g.type = 'genus'
INNER JOIN speciestaxonomy st ON st.taxonomy_id = g.id
INNER JOIN species s ON s.id = st.species_id
WHERE f.type = 'family'
  AND f.description != 'Plant'
  AND s.taxoncode = 'gall'
ORDER BY f.name ASC, g.name ASC, s.name ASC;

-- name: GetUndescribedGallFamiliesWithSpecies :many
-- Get gall families with genera and species, filtered to only undescribed galls.
SELECT
    f.id AS family_id,
    f.name AS family_name,
    f.description AS family_description,
    g.id AS genus_id,
    g.name AS genus_name,
    g.description AS genus_description,
    s.id AS species_id,
    s.name AS species_name,
    s.taxoncode AS species_taxoncode
FROM taxonomy f
INNER JOIN taxonomy g ON g.parent_id = f.id AND g.type = 'genus'
INNER JOIN speciestaxonomy st ON st.taxonomy_id = g.id
INNER JOIN species s ON s.id = st.species_id
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall gl ON gs.gall_id = gl.id
WHERE f.type = 'family'
  AND f.description != 'Plant'
  AND s.taxoncode = 'gall'
  AND gl.undescribed = 1
ORDER BY f.name ASC, g.name ASC, s.name ASC;

-- name: GetHostFamiliesWithSpecies :many
-- Get all host/plant families with their genera and species for the explore tree.
SELECT
    f.id AS family_id,
    f.name AS family_name,
    f.description AS family_description,
    g.id AS genus_id,
    g.name AS genus_name,
    g.description AS genus_description,
    s.id AS species_id,
    s.name AS species_name,
    s.taxoncode AS species_taxoncode
FROM taxonomy f
INNER JOIN taxonomy g ON g.parent_id = f.id AND g.type = 'genus'
INNER JOIN speciestaxonomy st ON st.taxonomy_id = g.id
INNER JOIN species s ON s.id = st.species_id
WHERE f.type = 'family'
  AND f.description = 'Plant'
  AND s.taxoncode = 'plant'
ORDER BY f.name ASC, g.name ASC, s.name ASC;
