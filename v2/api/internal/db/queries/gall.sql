-- name: ListGalls :many
-- Lists all galls with their species data, ordered by name.
-- Returns species data joined with gall-specific data.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    g.id AS gall_id,
    g.detachable,
    g.undescribed
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall g ON gs.gall_id = g.id
WHERE s.taxoncode = 'gall'
ORDER BY s.name;

-- name: ListGallsPaginated :many
-- Lists galls with pagination support.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    g.id AS gall_id,
    g.detachable,
    g.undescribed
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall g ON gs.gall_id = g.id
WHERE s.taxoncode = 'gall'
ORDER BY s.name
LIMIT ? OFFSET ?;

-- name: CountGalls :one
-- Returns the total count of galls.
SELECT COUNT(*) FROM species WHERE taxoncode = 'gall';

-- name: SearchGalls :many
-- Searches galls by name containing the query string.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    g.id AS gall_id,
    g.detachable,
    g.undescribed
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall g ON gs.gall_id = g.id
WHERE s.taxoncode = 'gall'
  AND s.name LIKE '%' || ? || '%'
ORDER BY s.name;

-- name: SearchGallsPaginated :many
-- Searches galls by name with pagination.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    g.id AS gall_id,
    g.detachable,
    g.undescribed
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall g ON gs.gall_id = g.id
WHERE s.taxoncode = 'gall'
  AND s.name LIKE '%' || ? || '%'
ORDER BY s.name
LIMIT ? OFFSET ?;

-- name: CountSearchGalls :one
-- Returns count of galls matching search query.
SELECT COUNT(*)
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
WHERE s.taxoncode = 'gall'
  AND s.name LIKE '%' || ? || '%';

-- name: GetGallByID :one
-- Gets a single gall by its species ID.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    g.id AS gall_id,
    g.detachable,
    g.undescribed
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall g ON gs.gall_id = g.id
WHERE s.id = ? AND s.taxoncode = 'gall';

-- name: GetGallBySpeciesID :one
-- Gets a gall by species ID (same as GetGallByID, provided for clarity).
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    g.id AS gall_id,
    g.detachable,
    g.undescribed
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall g ON gs.gall_id = g.id
WHERE s.id = ? AND s.taxoncode = 'gall';

-- name: GetGallByName :one
-- Gets a gall by its exact species name.
SELECT
    s.id,
    s.name,
    s.taxoncode,
    s.datacomplete,
    s.abundance_id,
    g.id AS gall_id,
    g.detachable,
    g.undescribed
FROM species s
INNER JOIN gallspecies gs ON gs.species_id = s.id
INNER JOIN gall g ON gs.gall_id = g.id
WHERE s.name = ? AND s.taxoncode = 'gall';

-- name: GetAliasesBySpeciesID :many
-- Gets all aliases for a species.
SELECT a.id, a.name, a.type, a.description
FROM alias a
INNER JOIN aliasspecies als ON als.alias_id = a.id
WHERE als.species_id = ?;

-- name: GetAbundanceByID :one
-- Gets abundance info by ID.
SELECT id, abundance, description, reference
FROM abundance
WHERE id = ?;

-- name: GetGallHosts :many
-- Gets hosts for a gall species.
SELECT
    h.id AS host_relation_id,
    s.id AS host_species_id,
    s.name AS host_name
FROM host h
INNER JOIN species s ON h.host_species_id = s.id
WHERE h.gall_species_id = ?;

-- name: GetGallColors :many
-- Gets colors associated with a gall.
SELECT c.id, c.color
FROM color c
INNER JOIN gallcolor gc ON gc.color_id = c.id
WHERE gc.gall_id = ?;

-- name: GetGallShapes :many
-- Gets shapes associated with a gall.
SELECT sh.id, sh.shape, sh.description
FROM shape sh
INNER JOIN gallshape gs ON gs.shape_id = sh.id
WHERE gs.gall_id = ?;

-- name: GetGallTextures :many
-- Gets textures associated with a gall.
SELECT t.id, t.texture, t.description
FROM texture t
INNER JOIN galltexture gt ON gt.texture_id = t.id
WHERE gt.gall_id = ?;

-- name: GetGallLocations :many
-- Gets locations associated with a gall.
SELECT l.id, l.location, l.description
FROM location l
INNER JOIN galllocation gl ON gl.location_id = l.id
WHERE gl.gall_id = ?;

-- name: GetGallAlignments :many
-- Gets alignments associated with a gall.
SELECT a.id, a.alignment, a.description
FROM alignment a
INNER JOIN gallalignment ga ON ga.alignment_id = a.id
WHERE ga.gall_id = ?;

-- name: GetGallWalls :many
-- Gets walls associated with a gall.
SELECT w.id, w.walls, w.description
FROM walls w
INNER JOIN gallwalls gw ON gw.walls_id = w.id
WHERE gw.gall_id = ?;

-- name: GetGallCells :many
-- Gets cells associated with a gall.
SELECT c.id, c.cells, c.description
FROM cells c
INNER JOIN gallcells gc ON gc.cells_id = c.id
WHERE gc.gall_id = ?;

-- name: GetGallSeasons :many
-- Gets seasons associated with a gall.
SELECT se.id, se.season
FROM season se
INNER JOIN gallseason gs ON gs.season_id = se.id
WHERE gs.gall_id = ?;

-- name: GetGallForms :many
-- Gets forms associated with a gall.
SELECT f.id, f.form, f.description
FROM form f
INNER JOIN gallform gf ON gf.form_id = f.id
WHERE gf.gall_id = ?;

-- name: CreateSpecies :one
-- Creates a new species record for a gall.
INSERT INTO species (name, taxoncode, datacomplete, abundance_id)
VALUES (?, 'gall', ?, ?)
RETURNING id;

-- name: CreateGall :one
-- Creates a new gall record.
INSERT INTO gall (taxoncode, detachable, undescribed)
VALUES ('gall', ?, ?)
RETURNING id;

-- name: CreateGallSpecies :exec
-- Links a species to a gall.
INSERT INTO gallspecies (species_id, gall_id)
VALUES (?, ?);

-- name: CreateAlias :one
-- Creates a new alias.
INSERT INTO alias (name, type, description)
VALUES (?, ?, ?)
RETURNING id;

-- name: CreateAliasSpecies :exec
-- Links an alias to a species.
INSERT INTO aliasspecies (species_id, alias_id)
VALUES (?, ?);

-- name: UpdateSpecies :exec
-- Updates species data.
UPDATE species
SET name = ?, datacomplete = ?, abundance_id = ?
WHERE id = ?;

-- name: UpdateGall :exec
-- Updates gall-specific data.
UPDATE gall
SET detachable = ?, undescribed = ?
WHERE id = ?;

-- name: DeleteAliasBySpeciesID :exec
-- Deletes all aliases for a species (via junction table).
DELETE FROM alias
WHERE id IN (SELECT alias_id FROM aliasspecies WHERE species_id = ?);

-- name: DeleteAliasSpeciesBySpeciesID :exec
-- Deletes alias-species links for a species.
DELETE FROM aliasspecies WHERE species_id = ?;

-- name: DeleteGallColors :exec
-- Deletes all color associations for a gall.
DELETE FROM gallcolor WHERE gall_id = ?;

-- name: DeleteGallShapes :exec
-- Deletes all shape associations for a gall.
DELETE FROM gallshape WHERE gall_id = ?;

-- name: DeleteGallTextures :exec
-- Deletes all texture associations for a gall.
DELETE FROM galltexture WHERE gall_id = ?;

-- name: DeleteGallLocations :exec
-- Deletes all location associations for a gall.
DELETE FROM galllocation WHERE gall_id = ?;

-- name: DeleteGallAlignments :exec
-- Deletes all alignment associations for a gall.
DELETE FROM gallalignment WHERE gall_id = ?;

-- name: DeleteGallWalls :exec
-- Deletes all walls associations for a gall.
DELETE FROM gallwalls WHERE gall_id = ?;

-- name: DeleteGallCells :exec
-- Deletes all cells associations for a gall.
DELETE FROM gallcells WHERE gall_id = ?;

-- name: DeleteGallSeasons :exec
-- Deletes all season associations for a gall.
DELETE FROM gallseason WHERE gall_id = ?;

-- name: DeleteGallForms :exec
-- Deletes all form associations for a gall.
DELETE FROM gallform WHERE gall_id = ?;

-- name: InsertGallColor :exec
-- Associates a color with a gall.
INSERT INTO gallcolor (gall_id, color_id) VALUES (?, ?);

-- name: InsertGallShape :exec
-- Associates a shape with a gall.
INSERT INTO gallshape (gall_id, shape_id) VALUES (?, ?);

-- name: InsertGallTexture :exec
-- Associates a texture with a gall.
INSERT INTO galltexture (gall_id, texture_id) VALUES (?, ?);

-- name: InsertGallLocation :exec
-- Associates a location with a gall.
INSERT INTO galllocation (gall_id, location_id) VALUES (?, ?);

-- name: InsertGallAlignment :exec
-- Associates an alignment with a gall.
INSERT INTO gallalignment (gall_id, alignment_id) VALUES (?, ?);

-- name: InsertGallWalls :exec
-- Associates walls with a gall.
INSERT INTO gallwalls (gall_id, walls_id) VALUES (?, ?);

-- name: InsertGallCells :exec
-- Associates cells with a gall.
INSERT INTO gallcells (gall_id, cells_id) VALUES (?, ?);

-- name: InsertGallSeason :exec
-- Associates a season with a gall.
INSERT INTO gallseason (gall_id, season_id) VALUES (?, ?);

-- name: InsertGallForm :exec
-- Associates a form with a gall.
INSERT INTO gallform (gall_id, form_id) VALUES (?, ?);

-- name: DeleteSpeciesByID :exec
-- Deletes a species by ID. Cascades delete the gall and related records.
DELETE FROM species WHERE id = ?;

-- name: DeleteGallByID :exec
-- Deletes a gall by its gall table ID.
DELETE FROM gall WHERE id = ?;

-- name: DeleteGallSpecies :exec
-- Deletes the gall-species junction record.
DELETE FROM gallspecies WHERE species_id = ?;

-- name: DeleteHostsByGallSpeciesID :exec
-- Deletes host associations for a gall.
DELETE FROM host WHERE gall_species_id = ?;

-- name: InsertHost :exec
-- Creates a host association for a gall.
INSERT INTO host (host_species_id, gall_species_id)
VALUES (?, ?);

-- name: DeleteAliasByID :exec
-- Deletes an alias by ID.
DELETE FROM alias WHERE id = ?;

-- name: GetGallPlaces :many
-- Gets places associated with a gall via its host plants.
SELECT DISTINCT p.name
FROM place p
INNER JOIN speciesplace sp ON sp.place_id = p.id
INNER JOIN host h ON h.host_species_id = sp.species_id
WHERE h.gall_species_id = ?;

-- name: GetGallTaxonomy :one
-- Gets the genus and family for a gall species.
SELECT
    g.name AS genus,
    f.name AS family
FROM speciestaxonomy st
INNER JOIN taxonomy g ON st.taxonomy_id = g.id AND g.type = 'genus'
LEFT JOIN taxonomy f ON g.parent_id = f.id AND f.type = 'family'
WHERE st.species_id = ?
LIMIT 1;

-- name: GetRandomGallWithImage :one
-- Gets a random gall that has a default image.
SELECT
    s.id,
    s.name,
    g.undescribed,
    i.path AS image_path,
    i.creator AS image_creator,
    i.license AS image_license,
    i.sourcelink AS image_sourcelink,
    i.licenselink AS image_licenselink
FROM gall g
INNER JOIN gallspecies gs ON gs.gall_id = g.id
INNER JOIN species s ON gs.species_id = s.id
INNER JOIN image i ON i.species_id = s.id
WHERE i.`default` = 1
ORDER BY RANDOM()
LIMIT 1;

-- name: GetImagesBySpeciesID :many
-- Gets all images for a species.
SELECT
    i.id,
    i.path,
    i.creator,
    i.attribution,
    i.sourcelink,
    i.license,
    i.licenselink,
    i.caption
FROM image i
WHERE i.species_id = ?
ORDER BY i.id;
