-- Filter field queries for various filter tables (color, shape, location, texture, etc.)
-- Each table represents a different type of filter field used to categorize galls.

-- ============================================================================
-- COLOR QUERIES
-- ============================================================================

-- name: ListColors :many
-- Lists all colors ordered by name.
SELECT id, color FROM color ORDER BY color;

-- name: GetColorByID :one
-- Gets a color by ID.
SELECT id, color FROM color WHERE id = ?;

-- name: CreateColor :one
-- Creates a new color record.
INSERT INTO color (color) VALUES (?) RETURNING id;

-- name: UpdateColor :exec
-- Updates a color by ID.
UPDATE color SET color = ? WHERE id = ?;

-- name: DeleteColor :exec
-- Deletes a color by ID.
DELETE FROM color WHERE id = ?;

-- ============================================================================
-- SHAPE QUERIES
-- ============================================================================

-- name: ListShapes :many
-- Lists all shapes ordered by name.
SELECT id, shape, description FROM shape ORDER BY shape;

-- name: GetShapeByID :one
-- Gets a shape by ID.
SELECT id, shape, description FROM shape WHERE id = ?;

-- name: CreateShape :one
-- Creates a new shape record.
INSERT INTO shape (shape, description) VALUES (?, ?) RETURNING id;

-- name: UpdateShape :exec
-- Updates a shape by ID.
UPDATE shape SET shape = ?, description = ? WHERE id = ?;

-- name: DeleteShape :exec
-- Deletes a shape by ID.
DELETE FROM shape WHERE id = ?;

-- ============================================================================
-- LOCATION QUERIES
-- ============================================================================

-- name: ListLocations :many
-- Lists all locations ordered by name.
SELECT id, location, description FROM location ORDER BY location;

-- name: GetLocationByID :one
-- Gets a location by ID.
SELECT id, location, description FROM location WHERE id = ?;

-- name: CreateLocation :one
-- Creates a new location record.
INSERT INTO location (location, description) VALUES (?, ?) RETURNING id;

-- name: UpdateLocation :exec
-- Updates a location by ID.
UPDATE location SET location = ?, description = ? WHERE id = ?;

-- name: DeleteLocation :exec
-- Deletes a location by ID.
DELETE FROM location WHERE id = ?;

-- ============================================================================
-- TEXTURE QUERIES
-- ============================================================================

-- name: ListTextures :many
-- Lists all textures ordered by name.
SELECT id, texture, description FROM texture ORDER BY texture;

-- name: GetTextureByID :one
-- Gets a texture by ID.
SELECT id, texture, description FROM texture WHERE id = ?;

-- name: CreateTexture :one
-- Creates a new texture record.
INSERT INTO texture (texture, description) VALUES (?, ?) RETURNING id;

-- name: UpdateTexture :exec
-- Updates a texture by ID.
UPDATE texture SET texture = ?, description = ? WHERE id = ?;

-- name: DeleteTexture :exec
-- Deletes a texture by ID.
DELETE FROM texture WHERE id = ?;

-- ============================================================================
-- WALLS QUERIES
-- ============================================================================

-- name: ListWalls :many
-- Lists all walls values ordered by name.
SELECT id, walls, description FROM walls ORDER BY walls;

-- name: GetWallsByID :one
-- Gets a walls value by ID.
SELECT id, walls, description FROM walls WHERE id = ?;

-- name: CreateWalls :one
-- Creates a new walls record.
INSERT INTO walls (walls, description) VALUES (?, ?) RETURNING id;

-- name: UpdateWalls :exec
-- Updates a walls value by ID.
UPDATE walls SET walls = ?, description = ? WHERE id = ?;

-- name: DeleteWalls :exec
-- Deletes a walls value by ID.
DELETE FROM walls WHERE id = ?;

-- ============================================================================
-- CELLS QUERIES
-- ============================================================================

-- name: ListCells :many
-- Lists all cells values ordered by name.
SELECT id, cells, description FROM cells ORDER BY cells;

-- name: GetCellsByID :one
-- Gets a cells value by ID.
SELECT id, cells, description FROM cells WHERE id = ?;

-- name: CreateCells :one
-- Creates a new cells record.
INSERT INTO cells (cells, description) VALUES (?, ?) RETURNING id;

-- name: UpdateCells :exec
-- Updates a cells value by ID.
UPDATE cells SET cells = ?, description = ? WHERE id = ?;

-- name: DeleteCells :exec
-- Deletes a cells value by ID.
DELETE FROM cells WHERE id = ?;

-- ============================================================================
-- ALIGNMENT QUERIES
-- ============================================================================

-- name: ListAlignments :many
-- Lists all alignments ordered by name.
SELECT id, alignment, description FROM alignment ORDER BY alignment;

-- name: GetAlignmentByID :one
-- Gets an alignment by ID.
SELECT id, alignment, description FROM alignment WHERE id = ?;

-- name: CreateAlignment :one
-- Creates a new alignment record.
INSERT INTO alignment (alignment, description) VALUES (?, ?) RETURNING id;

-- name: UpdateAlignment :exec
-- Updates an alignment by ID.
UPDATE alignment SET alignment = ?, description = ? WHERE id = ?;

-- name: DeleteAlignment :exec
-- Deletes an alignment by ID.
DELETE FROM alignment WHERE id = ?;

-- ============================================================================
-- SEASON QUERIES
-- ============================================================================

-- name: ListSeasons :many
-- Lists all seasons ordered by name.
SELECT id, season FROM season ORDER BY season;

-- name: GetSeasonByID :one
-- Gets a season by ID.
SELECT id, season FROM season WHERE id = ?;

-- name: CreateSeason :one
-- Creates a new season record.
INSERT INTO season (season) VALUES (?) RETURNING id;

-- name: UpdateSeason :exec
-- Updates a season by ID.
UPDATE season SET season = ? WHERE id = ?;

-- name: DeleteSeason :exec
-- Deletes a season by ID.
DELETE FROM season WHERE id = ?;

-- ============================================================================
-- FORM QUERIES
-- ============================================================================

-- name: ListForms :many
-- Lists all forms ordered by name.
SELECT id, form, description FROM form ORDER BY form;

-- name: GetFormByID :one
-- Gets a form by ID.
SELECT id, form, description FROM form WHERE id = ?;

-- name: CreateForm :one
-- Creates a new form record.
INSERT INTO form (form, description) VALUES (?, ?) RETURNING id;

-- name: UpdateForm :exec
-- Updates a form by ID.
UPDATE form SET form = ?, description = ? WHERE id = ?;

-- name: DeleteForm :exec
-- Deletes a form by ID.
DELETE FROM form WHERE id = ?;

-- ============================================================================
-- ABUNDANCE QUERIES (prefixed to avoid conflict with gall.sql)
-- ============================================================================

-- name: ListAbundanceValues :many
-- Lists all abundance values ordered by name.
SELECT id, abundance, description, reference FROM abundance ORDER BY abundance;

-- name: GetAbundanceValueByID :one
-- Gets an abundance by ID.
SELECT id, abundance, description, reference FROM abundance WHERE id = ?;

-- name: CreateAbundanceValue :one
-- Creates a new abundance record.
INSERT INTO abundance (abundance, description, reference) VALUES (?, ?, ?) RETURNING id;

-- name: UpdateAbundanceValue :exec
-- Updates an abundance by ID.
UPDATE abundance SET abundance = ?, description = ?, reference = ? WHERE id = ?;

-- name: DeleteAbundanceValue :exec
-- Deletes an abundance by ID.
DELETE FROM abundance WHERE id = ?;
