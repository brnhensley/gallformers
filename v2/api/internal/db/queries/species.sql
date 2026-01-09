-- name: GetSpeciesByID :one
-- Get a single species by ID
SELECT
    s.id,
    s.taxoncode,
    s.name,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.id = ?;

-- name: ListSpecies :many
-- List all species ordered by name
SELECT
    s.id,
    s.taxoncode,
    s.name,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
ORDER BY s.name ASC;

-- name: SearchSpecies :many
-- Search species by name (case-insensitive LIKE)
SELECT
    s.id,
    s.taxoncode,
    s.name,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.name LIKE ?
ORDER BY s.name ASC;

-- name: GetSpeciesByName :one
-- Get a single species by exact name match
SELECT
    s.id,
    s.taxoncode,
    s.name,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.name = ?;

-- name: CountSpecies :one
-- Count total species (for pagination)
SELECT COUNT(*) as count FROM species;

-- name: CountSpeciesSearch :one
-- Count species matching search term (for pagination)
SELECT COUNT(*) as count FROM species WHERE name LIKE ?;
