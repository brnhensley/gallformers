package handlers

import (
	"log/slog"
	"net/http"
	"sort"
	"strings"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	"github.com/jeffdc/gallformers/v2/api/internal/views/pages"
)

// HTMXGlossaryHandler handles HTMX-rendered glossary pages.
type HTMXGlossaryHandler struct {
	queries *db.Queries
}

// NewHTMXGlossaryHandler creates a new HTMX glossary handler.
func NewHTMXGlossaryHandler(queries *db.Queries) *HTMXGlossaryHandler {
	return &HTMXGlossaryHandler{queries: queries}
}

// RegisterRoutes registers the HTMX glossary routes.
func (h *HTMXGlossaryHandler) RegisterRoutes(r chi.Router) {
	r.Get("/glossary", h.Page)
}

// Page renders the glossary page.
// Supports sorting via query params: sort=word|definition, dir=asc|desc
// If HX-Request header is present, returns just the table body for partial update.
func (h *HTMXGlossaryHandler) Page(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Fetch all glossary entries
	rows, err := h.queries.ListGlossary(ctx)
	if err != nil {
		slog.Error("failed to list glossary", "error", err)
		http.Error(w, "Failed to load glossary", http.StatusInternalServerError)
		return
	}

	// Convert to page entries
	entries := make([]pages.GlossaryEntry, len(rows))
	for i, row := range rows {
		entries[i] = pages.GlossaryEntry{
			ID:         row.ID,
			Word:       row.Word,
			Definition: row.Definition,
			URLs:       row.Urls,
		}
	}

	// Parse sort parameters
	sortField := r.URL.Query().Get("sort")
	sortDir := r.URL.Query().Get("dir")

	// Default to sorting by word ascending
	if sortField == "" {
		sortField = "word"
	}
	if sortDir == "" {
		sortDir = "asc"
	}

	// Validate sort field
	if sortField != "word" && sortField != "definition" {
		sortField = "word"
	}

	// Validate sort direction
	if sortDir != "asc" && sortDir != "desc" {
		sortDir = "asc"
	}

	// Sort entries
	sortEntries(entries, sortField, sortDir)

	data := pages.GlossaryData{
		Entries:   entries,
		SortField: sortField,
		SortDir:   sortDir,
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")

	// Check if this is an HTMX request for partial update
	if isHTMXRequest(r) {
		// Return just the table body
		pages.GlossaryTableBody(entries).Render(ctx, w)
	} else {
		// Return full page
		pages.GlossaryPage(data).Render(ctx, w)
	}
}

// sortEntries sorts glossary entries by the specified field and direction.
func sortEntries(entries []pages.GlossaryEntry, field, dir string) {
	sort.Slice(entries, func(i, j int) bool {
		var less bool

		switch field {
		case "definition":
			less = strings.ToLower(entries[i].Definition) < strings.ToLower(entries[j].Definition)
		default: // "word"
			less = strings.ToLower(entries[i].Word) < strings.ToLower(entries[j].Word)
		}

		if dir == "desc" {
			return !less
		}
		return less
	})
}
