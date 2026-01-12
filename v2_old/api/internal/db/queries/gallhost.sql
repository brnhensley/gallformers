-- name: ListHostsByGallID :many
-- Gets all hosts associated with a gall species.
SELECT
    h.id AS host_relation_id,
    s.id AS host_species_id,
    s.name AS host_name
FROM host h
INNER JOIN species s ON h.host_species_id = s.id
WHERE h.gall_species_id = ?
ORDER BY s.name;

-- name: GetGallHostByIDs :one
-- Gets a specific gall-host relationship by both IDs.
SELECT
    h.id AS host_relation_id,
    h.gall_species_id,
    h.host_species_id,
    s.name AS host_name
FROM host h
INNER JOIN species s ON h.host_species_id = s.id
WHERE h.gall_species_id = ? AND h.host_species_id = ?;

-- name: CreateGallHost :one
-- Creates a new gall-host association.
INSERT INTO host (gall_species_id, host_species_id)
VALUES (?, ?)
RETURNING id;

-- name: DeleteGallHost :exec
-- Deletes a gall-host association by gall and host species IDs.
DELETE FROM host
WHERE gall_species_id = ? AND host_species_id = ?;

-- name: DeleteGallHostByID :exec
-- Deletes a gall-host association by its ID.
DELETE FROM host WHERE id = ?;

-- name: CountHostsByGallID :one
-- Returns the count of hosts for a gall.
SELECT COUNT(*) FROM host WHERE gall_species_id = ?;
