-- name: ListGlossary :many
-- Lists all glossary entries ordered by word (case-insensitive).
SELECT id, word, definition, urls
FROM glossary
ORDER BY word COLLATE NOCASE ASC;

-- name: ListGlossaryPaginated :many
-- Lists glossary entries with pagination support.
SELECT id, word, definition, urls
FROM glossary
ORDER BY word COLLATE NOCASE ASC
LIMIT ? OFFSET ?;

-- name: CountGlossary :one
-- Returns the total count of glossary entries.
SELECT COUNT(*) FROM glossary;

-- name: SearchGlossary :many
-- Searches glossary entries by word containing the query string.
SELECT id, word, definition, urls
FROM glossary
WHERE word LIKE '%' || ? || '%'
ORDER BY word COLLATE NOCASE ASC;

-- name: SearchGlossaryPaginated :many
-- Searches glossary entries by word with pagination.
SELECT id, word, definition, urls
FROM glossary
WHERE word LIKE '%' || ? || '%'
ORDER BY word COLLATE NOCASE ASC
LIMIT ? OFFSET ?;

-- name: CountSearchGlossary :one
-- Returns count of glossary entries matching search query.
SELECT COUNT(*)
FROM glossary
WHERE word LIKE '%' || ? || '%';

-- name: GetGlossaryByID :one
-- Gets a single glossary entry by ID.
SELECT id, word, definition, urls
FROM glossary
WHERE id = ?;

-- name: GetGlossaryByWord :one
-- Gets a single glossary entry by exact word match.
SELECT id, word, definition, urls
FROM glossary
WHERE word = ?;

-- name: CreateGlossary :one
-- Creates a new glossary entry.
INSERT INTO glossary (word, definition, urls)
VALUES (?, ?, ?)
RETURNING id;

-- name: UpdateGlossary :exec
-- Updates an existing glossary entry.
UPDATE glossary
SET word = ?, definition = ?, urls = ?
WHERE id = ?;

-- name: DeleteGlossary :exec
-- Deletes a glossary entry by ID.
DELETE FROM glossary WHERE id = ?;
