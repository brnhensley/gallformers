package handlers

import (
	"database/sql"
	"log/slog"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	"github.com/jeffdc/gallformers/v2/api/internal/middleware"
)

// SearchHandler handles global search HTTP requests.
type SearchHandler struct {
	queries *db.Queries
}

// NewSearchHandler creates a new SearchHandler.
func NewSearchHandler(queries *db.Queries) *SearchHandler {
	return &SearchHandler{queries: queries}
}

// TinySpecies represents a minimal species record for search results.
type TinySpecies struct {
	ID        int64    `json:"id"`
	Name      string   `json:"name"`
	Taxoncode string   `json:"taxoncode"`
	Aliases   []string `json:"aliases"`
}

// TinySource represents a minimal source record for search results.
type TinySource struct {
	ID     int64  `json:"id"`
	Source string `json:"source"`
}

// GlossaryEntry represents a glossary entry in search results.
type GlossaryEntry struct {
	ID         int64  `json:"id"`
	Word       string `json:"word"`
	Definition string `json:"definition"`
}

// SearchTaxonomyEntry represents a taxonomy entry in search results.
type SearchTaxonomyEntry struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Type        string `json:"type"`
}

// PlaceEntry represents a place in search results.
type PlaceEntry struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
	Code string `json:"code"`
	Type string `json:"type"`
}

// GlobalSearchResponse contains all search results grouped by type.
type GlobalSearchResponse struct {
	Species  []TinySpecies         `json:"species"`
	Glossary []GlossaryEntry       `json:"glossary"`
	Sources  []TinySource          `json:"sources"`
	Taxa     []SearchTaxonomyEntry `json:"taxa"`
	Places   []PlaceEntry          `json:"places"`
}

// RegisterRoutes registers search routes on the router.
func (h *SearchHandler) RegisterRoutes(r chi.Router) {
	r.Get("/search", h.Search)
}

// Search handles GET /api/v2/search?q={term}
// Returns grouped results from species, glossary, sources, taxa, and places.
func (h *SearchHandler) Search(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get search query
	searchQuery := strings.TrimSpace(r.URL.Query().Get("q"))
	if searchQuery == "" {
		middleware.RespondBadRequest(w, "Search query 'q' is required")
		return
	}

	// Replace spaces with % for LIKE matching (mimics v1 behavior)
	normalizedQuery := strings.ReplaceAll(searchQuery, " ", "%")

	response := GlobalSearchResponse{
		Species:  []TinySpecies{},
		Glossary: []GlossaryEntry{},
		Sources:  []TinySource{},
		Taxa:     []SearchTaxonomyEntry{},
		Places:   []PlaceEntry{},
	}

	// Search species by name
	speciesMap := make(map[int64]*TinySpecies)
	speciesRows, err := h.queries.GlobalSearchSpecies(ctx, sql.NullString{String: normalizedQuery, Valid: true})
	if err != nil {
		slog.Error("failed to search species by name", "error", err)
		middleware.RespondInternalError(w, "Failed to search species")
		return
	}
	for _, row := range speciesRows {
		taxoncode := "plant"
		if row.Taxoncode.Valid && row.Taxoncode.String != "" {
			taxoncode = row.Taxoncode.String
		}
		speciesMap[row.ID] = &TinySpecies{
			ID:        row.ID,
			Name:      row.Name,
			Taxoncode: taxoncode,
			Aliases:   []string{},
		}
	}

	// Search species by alias and merge
	aliasRows, err := h.queries.GlobalSearchSpeciesByAlias(ctx, sql.NullString{String: normalizedQuery, Valid: true})
	if err != nil {
		slog.Error("failed to search species by alias", "error", err)
		middleware.RespondInternalError(w, "Failed to search species")
		return
	}
	for _, row := range aliasRows {
		if _, exists := speciesMap[row.ID]; !exists {
			taxoncode := "plant"
			if row.Taxoncode.Valid && row.Taxoncode.String != "" {
				taxoncode = row.Taxoncode.String
			}
			speciesMap[row.ID] = &TinySpecies{
				ID:        row.ID,
				Name:      row.Name,
				Taxoncode: taxoncode,
				Aliases:   []string{},
			}
		}
	}

	// Fetch aliases for each species
	for id, sp := range speciesMap {
		aliases, err := h.queries.GetAliasesForSpecies(ctx, id)
		if err != nil {
			slog.Warn("failed to get aliases for species", "error", err, "species_id", id)
			continue
		}
		sp.Aliases = aliases
	}

	// Convert map to sorted slice
	for _, sp := range speciesMap {
		response.Species = append(response.Species, *sp)
	}
	// Sort by name
	sortSpeciesByName(response.Species)

	// Search glossary (by word or definition)
	glossaryRows, err := h.queries.GlobalSearchGlossary(ctx, db.GlobalSearchGlossaryParams{
		Column1: sql.NullString{String: normalizedQuery, Valid: true},
		Column2: sql.NullString{String: normalizedQuery, Valid: true},
	})
	if err != nil {
		slog.Error("failed to search glossary", "error", err)
		middleware.RespondInternalError(w, "Failed to search glossary")
		return
	}
	// Filter to match v1 behavior: exact word match OR definition contains
	for _, row := range glossaryRows {
		// v1 filters: e.word === search || e.definition.includes(search)
		if strings.EqualFold(row.Word, searchQuery) || strings.Contains(strings.ToLower(row.Definition), strings.ToLower(searchQuery)) {
			response.Glossary = append(response.Glossary, GlossaryEntry{
				ID:         row.ID,
				Word:       row.Word,
				Definition: row.Definition,
			})
		}
	}

	// Search sources
	sourceRows, err := h.queries.GlobalSearchSources(ctx, db.GlobalSearchSourcesParams{
		Column1: sql.NullString{String: normalizedQuery, Valid: true},
		Column2: sql.NullString{String: normalizedQuery, Valid: true},
	})
	if err != nil {
		slog.Error("failed to search sources", "error", err)
		middleware.RespondInternalError(w, "Failed to search sources")
		return
	}
	for _, row := range sourceRows {
		response.Sources = append(response.Sources, TinySource{
			ID:     row.ID,
			Source: formatSourceDisplay(row.Title, row.Author, row.Pubyear),
		})
	}

	// Search taxonomy
	taxaRows, err := h.queries.GlobalSearchTaxa(ctx, db.GlobalSearchTaxaParams{
		Column1: sql.NullString{String: normalizedQuery, Valid: true},
		Column2: sql.NullString{String: normalizedQuery, Valid: true},
	})
	if err != nil {
		slog.Error("failed to search taxonomy", "error", err)
		middleware.RespondInternalError(w, "Failed to search taxonomy")
		return
	}
	for _, row := range taxaRows {
		desc := ""
		if row.Description.Valid {
			desc = row.Description.String
		}
		response.Taxa = append(response.Taxa, SearchTaxonomyEntry{
			ID:          row.ID,
			Name:        row.Name,
			Description: desc,
			Type:        row.Type,
		})
	}

	// Search places
	placeRows, err := h.queries.GlobalSearchPlaces(ctx, db.GlobalSearchPlacesParams{
		Column1: sql.NullString{String: normalizedQuery, Valid: true},
		Column2: sql.NullString{String: normalizedQuery, Valid: true},
	})
	if err != nil {
		slog.Error("failed to search places", "error", err)
		middleware.RespondInternalError(w, "Failed to search places")
		return
	}
	for _, row := range placeRows {
		response.Places = append(response.Places, PlaceEntry{
			ID:   row.ID,
			Name: row.Name,
			Code: row.Code,
			Type: row.Type,
		})
	}

	middleware.RespondOK(w, response)
}

// sortSpeciesByName sorts species slice by name alphabetically.
func sortSpeciesByName(species []TinySpecies) {
	for i := 0; i < len(species)-1; i++ {
		for j := i + 1; j < len(species); j++ {
			if species[i].Name > species[j].Name {
				species[i], species[j] = species[j], species[i]
			}
		}
	}
}

// formatSourceDisplay formats a source for display (matches v1 sourceToDisplay behavior).
func formatSourceDisplay(title, author, pubyear string) string {
	// v1 format: "{author}, {pubyear}. {title}" or variations if parts are missing
	parts := []string{}
	if author != "" {
		parts = append(parts, author)
	}
	if pubyear != "" {
		if len(parts) > 0 {
			parts = append(parts, pubyear+".")
		} else {
			parts = append(parts, pubyear+".")
		}
	}
	if title != "" {
		parts = append(parts, title)
	}

	if len(parts) == 0 {
		return "Unknown source"
	}

	// Join with appropriate separators
	if author != "" && pubyear != "" {
		return author + ", " + pubyear + ". " + title
	} else if author != "" {
		return author + ". " + title
	} else if pubyear != "" {
		return pubyear + ". " + title
	}
	return title
}
