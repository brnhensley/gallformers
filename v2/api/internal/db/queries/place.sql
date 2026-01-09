-- name: ListPlaces :many
-- Lists all places ordered by name.
SELECT id, name, code, type
FROM place
ORDER BY name;

-- name: ListPlacesPaginated :many
-- Lists places with pagination support.
SELECT id, name, code, type
FROM place
ORDER BY name
LIMIT ? OFFSET ?;

-- name: CountPlaces :one
-- Returns the total count of places.
SELECT COUNT(*) FROM place;

-- name: SearchPlaces :many
-- Searches places by name containing the query string.
SELECT id, name, code, type
FROM place
WHERE name LIKE '%' || ? || '%'
ORDER BY name;

-- name: SearchPlacesPaginated :many
-- Searches places by name with pagination.
SELECT id, name, code, type
FROM place
WHERE name LIKE '%' || ? || '%'
ORDER BY name
LIMIT ? OFFSET ?;

-- name: CountSearchPlaces :one
-- Returns count of places matching search query.
SELECT COUNT(*)
FROM place
WHERE name LIKE '%' || ? || '%';

-- name: GetPlaceByID :one
-- Gets a single place by ID.
SELECT id, name, code, type
FROM place
WHERE id = ?;

-- name: GetPlaceByName :one
-- Gets a single place by exact name.
SELECT id, name, code, type
FROM place
WHERE name = ?;

-- name: CreatePlace :one
-- Creates a new place record.
INSERT INTO place (name, code, type)
VALUES (?, ?, ?)
RETURNING id;

-- name: UpdatePlace :exec
-- Updates an existing place.
UPDATE place
SET name = ?, code = ?, type = ?
WHERE id = ?;

-- name: DeletePlace :exec
-- Deletes a place by ID.
DELETE FROM place WHERE id = ?;
