-- name: ListHosts :many
-- Lists all hosts (plant species) with their data, ordered by name.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.taxoncode = 'plant'
ORDER BY s.name;

-- name: ListHostsPaginated :many
-- Lists hosts with pagination support.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.taxoncode = 'plant'
ORDER BY s.name
LIMIT ? OFFSET ?;

-- name: CountHosts :one
-- Returns the total count of hosts.
SELECT COUNT(*) FROM species WHERE taxoncode = 'plant';

-- name: SearchHosts :many
-- Searches hosts by name containing the query string.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.taxoncode = 'plant'
  AND s.name LIKE '%' || ? || '%'
ORDER BY s.name;

-- name: SearchHostsPaginated :many
-- Searches hosts by name with pagination.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.taxoncode = 'plant'
  AND s.name LIKE '%' || ? || '%'
ORDER BY s.name
LIMIT ? OFFSET ?;

-- name: CountSearchHosts :one
-- Returns count of hosts matching search query.
SELECT COUNT(*)
FROM species s
WHERE s.taxoncode = 'plant'
  AND s.name LIKE '%' || ? || '%';

-- name: GetHostByID :one
-- Gets a single host by its species ID.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.id = ? AND s.taxoncode = 'plant';

-- name: GetHostByName :one
-- Gets a host by its exact species name.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    a.abundance as abundance_name
FROM species s
LEFT JOIN abundance a ON s.abundance_id = a.id
WHERE s.name = ? AND s.taxoncode = 'plant';

-- name: GetHostGalls :many
-- Gets galls associated with a host species.
SELECT
    h.id AS host_relation_id,
    s.id AS gall_species_id,
    s.name AS gall_name
FROM host h
INNER JOIN species s ON h.gall_species_id = s.id
WHERE h.host_species_id = ?;

-- name: GetHostPlaces :many
-- Gets places associated with a host species.
SELECT
    p.id,
    p.name,
    p.code,
    p.type
FROM place p
INNER JOIN speciesplace sp ON sp.place_id = p.id
WHERE sp.species_id = ?;

-- name: CreateHostSpecies :one
-- Creates a new species record for a host (plant).
INSERT INTO species (name, taxoncode, datacomplete, abundance_id)
VALUES (?, 'plant', ?, ?)
RETURNING id;

-- name: UpdateHostSpecies :exec
-- Updates host species data.
UPDATE species
SET name = ?, datacomplete = ?, abundance_id = ?
WHERE id = ? AND taxoncode = 'plant';

-- name: DeleteHostByID :exec
-- Deletes a host species by ID. Related records should be deleted first.
DELETE FROM species WHERE id = ? AND taxoncode = 'plant';

-- name: DeleteHostGallAssociations :exec
-- Deletes all gall associations for a host species.
DELETE FROM host WHERE host_species_id = ?;

-- name: DeleteHostPlaces :exec
-- Deletes all place associations for a host species.
DELETE FROM speciesplace WHERE species_id = ?;

-- name: InsertHostPlace :exec
-- Associates a place with a host species.
INSERT INTO speciesplace (species_id, place_id) VALUES (?, ?);
