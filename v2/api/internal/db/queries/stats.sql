-- =============================================================================
-- Site Statistics Queries
-- =============================================================================

-- name: CountUndescribedGalls :one
-- Count galls that are marked as undescribed
SELECT COUNT(*) as count
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall g ON gs.gall_id = g.id
WHERE s.taxoncode = 'gall' AND g.undescribed = 1;

-- name: CountGallFamilies :one
-- Count distinct families that have gall species
SELECT COUNT(DISTINCT family.id) as count
FROM taxonomy family
INNER JOIN taxonomy genus ON genus.parent_id = family.id AND genus.type = 'genus'
INNER JOIN speciestaxonomy st ON st.taxonomy_id = genus.id
INNER JOIN species s ON s.id = st.species_id
WHERE family.type = 'family' AND s.taxoncode = 'gall';

-- name: CountGallGenera :one
-- Count distinct genera that have gall species
SELECT COUNT(DISTINCT genus.id) as count
FROM taxonomy genus
INNER JOIN speciestaxonomy st ON st.taxonomy_id = genus.id
INNER JOIN species s ON s.id = st.species_id
WHERE genus.type = 'genus' AND s.taxoncode = 'gall';

-- name: CountHostFamilies :one
-- Count distinct families that have host/plant species
SELECT COUNT(DISTINCT family.id) as count
FROM taxonomy family
INNER JOIN taxonomy genus ON genus.parent_id = family.id AND genus.type = 'genus'
INNER JOIN speciestaxonomy st ON st.taxonomy_id = genus.id
INNER JOIN species s ON s.id = st.species_id
WHERE family.type = 'family' AND s.taxoncode = 'plant';

-- name: CountHostGenera :one
-- Count distinct genera that have host/plant species
SELECT COUNT(DISTINCT genus.id) as count
FROM taxonomy genus
INNER JOIN speciestaxonomy st ON st.taxonomy_id = genus.id
INNER JOIN species s ON s.id = st.species_id
WHERE genus.type = 'genus' AND s.taxoncode = 'plant';
