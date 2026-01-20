-- name: ListSources :many
-- Lists all sources ordered by title.
SELECT id, title, author, pubyear, link, citation, datacomplete, license, licenselink
FROM source
ORDER BY title;

-- name: ListSourcesPaginated :many
-- Lists sources with pagination support.
SELECT id, title, author, pubyear, link, citation, datacomplete, license, licenselink
FROM source
ORDER BY title
LIMIT ? OFFSET ?;

-- name: CountSources :one
-- Returns the total count of sources.
SELECT COUNT(*) FROM source;

-- name: SearchSources :many
-- Searches sources by title containing the query string.
SELECT id, title, author, pubyear, link, citation, datacomplete, license, licenselink
FROM source
WHERE title LIKE '%' || ? || '%'
ORDER BY title;

-- name: SearchSourcesPaginated :many
-- Searches sources by title with pagination.
SELECT id, title, author, pubyear, link, citation, datacomplete, license, licenselink
FROM source
WHERE title LIKE '%' || ? || '%'
ORDER BY title
LIMIT ? OFFSET ?;

-- name: CountSearchSources :one
-- Returns count of sources matching search query.
SELECT COUNT(*)
FROM source
WHERE title LIKE '%' || ? || '%';

-- name: GetSourceByID :one
-- Gets a single source by ID.
SELECT id, title, author, pubyear, link, citation, datacomplete, license, licenselink
FROM source
WHERE id = ?;

-- name: GetSourceByTitle :one
-- Gets a single source by exact title.
SELECT id, title, author, pubyear, link, citation, datacomplete, license, licenselink
FROM source
WHERE title = ?;

-- name: GetSourcesBySpeciesID :many
-- Gets sources associated with a species via speciessource table.
-- Includes the speciessource details (description, useasdefault, externallink).
SELECT
    s.id,
    s.title,
    s.author,
    s.pubyear,
    s.link,
    s.citation,
    s.datacomplete,
    s.license,
    s.licenselink,
    ss.id AS speciessource_id,
    ss.description AS speciessource_description,
    ss.useasdefault AS speciessource_useasdefault,
    ss.externallink AS speciessource_externallink
FROM source s
INNER JOIN speciessource ss ON ss.source_id = s.id
WHERE ss.species_id = ?
ORDER BY s.title;

-- name: CreateSource :one
-- Creates a new source record.
INSERT INTO source (title, author, pubyear, link, citation, datacomplete, license, licenselink)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
RETURNING id;

-- name: UpdateSource :exec
-- Updates an existing source.
UPDATE source
SET title = ?, author = ?, pubyear = ?, link = ?, citation = ?,
    datacomplete = ?, license = ?, licenselink = ?
WHERE id = ?;

-- name: DeleteSource :exec
-- Deletes a source by ID.
DELETE FROM source WHERE id = ?;

-- name: GetSpeciesBySourceID :many
-- Gets all species associated with a source via speciessource table.
SELECT
    sp.id,
    sp.name,
    sp.taxoncode,
    sp.datacomplete
FROM species sp
INNER JOIN speciessource ss ON ss.species_id = sp.id
WHERE ss.source_id = ?
ORDER BY sp.name;
