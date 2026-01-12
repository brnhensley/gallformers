-- name: ListSpeciesSourcesBySpeciesID :many
-- Gets all speciessource records for a species with full source details.
SELECT
    ss.id,
    ss.species_id,
    ss.source_id,
    ss.description,
    ss.useasdefault,
    ss.externallink,
    ss.alias_id,
    s.id AS source_id_dup,
    s.title AS source_title,
    s.author AS source_author,
    s.pubyear AS source_pubyear,
    s.link AS source_link,
    s.citation AS source_citation,
    s.datacomplete AS source_datacomplete,
    s.license AS source_license,
    s.licenselink AS source_licenselink
FROM speciessource ss
INNER JOIN source s ON s.id = ss.source_id
WHERE ss.species_id = ?
ORDER BY s.citation;

-- name: GetSpeciesSourceByIDs :one
-- Gets a specific speciessource record by species_id and source_id with full source details.
SELECT
    ss.id,
    ss.species_id,
    ss.source_id,
    ss.description,
    ss.useasdefault,
    ss.externallink,
    ss.alias_id,
    s.id AS source_id_dup,
    s.title AS source_title,
    s.author AS source_author,
    s.pubyear AS source_pubyear,
    s.link AS source_link,
    s.citation AS source_citation,
    s.datacomplete AS source_datacomplete,
    s.license AS source_license,
    s.licenselink AS source_licenselink
FROM speciessource ss
INNER JOIN source s ON s.id = ss.source_id
WHERE ss.species_id = ? AND ss.source_id = ?;

-- name: GetSpeciesSourceByID :one
-- Gets a speciessource record by its ID with full source details.
SELECT
    ss.id,
    ss.species_id,
    ss.source_id,
    ss.description,
    ss.useasdefault,
    ss.externallink,
    ss.alias_id,
    s.id AS source_id_dup,
    s.title AS source_title,
    s.author AS source_author,
    s.pubyear AS source_pubyear,
    s.link AS source_link,
    s.citation AS source_citation,
    s.datacomplete AS source_datacomplete,
    s.license AS source_license,
    s.licenselink AS source_licenselink
FROM speciessource ss
INNER JOIN source s ON s.id = ss.source_id
WHERE ss.id = ?;

-- name: CreateSpeciesSource :one
-- Creates a new speciessource record.
INSERT INTO speciessource (species_id, source_id, description, useasdefault, externallink, alias_id)
VALUES (?, ?, ?, ?, ?, ?)
RETURNING id;

-- name: UpdateSpeciesSource :exec
-- Updates an existing speciessource record.
UPDATE speciessource
SET description = ?, useasdefault = ?, externallink = ?, alias_id = ?
WHERE id = ?;

-- name: ClearDefaultForSpecies :exec
-- Clears the useasdefault flag for all speciessource records for a species.
UPDATE speciessource
SET useasdefault = 0
WHERE species_id = ?;

-- name: DeleteSpeciesSource :exec
-- Deletes a speciessource record by ID.
DELETE FROM speciessource WHERE id = ?;

-- name: DeleteSpeciesSourceByIDs :exec
-- Deletes a speciessource record by species_id and source_id.
DELETE FROM speciessource
WHERE species_id = ? AND source_id = ?;
