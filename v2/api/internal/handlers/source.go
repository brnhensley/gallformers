package handlers

import (
	"database/sql"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	"github.com/jeffdc/gallformers/v2/api/internal/middleware"
)

// SourceHandler handles source-related HTTP requests.
type SourceHandler struct {
	queries *db.Queries
}

// NewSourceHandler creates a new SourceHandler.
func NewSourceHandler(queries *db.Queries) *SourceHandler {
	return &SourceHandler{queries: queries}
}

// SourceResponse represents a source in API responses.
type SourceResponse struct {
	ID           int64  `json:"id"`
	Title        string `json:"title"`
	Author       string `json:"author"`
	Pubyear      string `json:"pubyear"`
	Link         string `json:"link"`
	Citation     string `json:"citation"`
	Datacomplete bool   `json:"datacomplete"`
	License      string `json:"license"`
	Licenselink  string `json:"licenselink"`
}

// SpeciesSourceInfo represents speciessource relationship data.
type SpeciesSourceInfo struct {
	ID           int64  `json:"id"`
	Description  string `json:"description"`
	Useasdefault int64  `json:"useasdefault"`
	Externallink string `json:"externallink"`
}

// SourceWithSpeciesSourceResponse represents a source with its speciessource relationship data.
type SourceWithSpeciesSourceResponse struct {
	SourceResponse
	SpeciesSource SpeciesSourceInfo `json:"speciessource"`
}

// SourceSpecies represents minimal species info for source detail page.
type SourceSpecies struct {
	ID           int64   `json:"id"`
	Name         string  `json:"name"`
	Taxoncode    *string `json:"taxoncode,omitempty"`
	Datacomplete bool    `json:"datacomplete"`
}

// SourceDetailResponse represents a source with its connected species.
type SourceDetailResponse struct {
	SourceResponse
	Species []SourceSpecies `json:"species"`
}

// SourceListResponse represents a paginated list of sources.
type SourceListResponse struct {
	Data   []SourceResponse `json:"data"`
	Total  int64            `json:"total"`
	Limit  *int64           `json:"limit,omitempty"`
	Offset int64            `json:"offset"`
}

// SourceCreateRequest represents the request body for creating a source.
type SourceCreateRequest struct {
	Title        string `json:"title"`
	Author       string `json:"author"`
	Pubyear      string `json:"pubyear"`
	Link         string `json:"link"`
	Citation     string `json:"citation"`
	Datacomplete bool   `json:"datacomplete"`
	License      string `json:"license"`
	Licenselink  string `json:"licenselink"`
}

// SourceUpdateRequest represents the request body for updating a source.
type SourceUpdateRequest struct {
	Title        string `json:"title"`
	Author       string `json:"author"`
	Pubyear      string `json:"pubyear"`
	Link         string `json:"link"`
	Citation     string `json:"citation"`
	Datacomplete bool   `json:"datacomplete"`
	License      string `json:"license"`
	Licenselink  string `json:"licenselink"`
}

// RegisterRoutes registers source routes on the router.
func (h *SourceHandler) RegisterRoutes(r chi.Router) {
	r.Route("/sources", func(r chi.Router) {
		// Public routes
		r.Get("/", h.List)
		r.Get("/{id}", h.GetByID)
		r.Get("/by-title/{title}", h.GetByTitle)

		// Protected routes - require authentication
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.Create)
			r.Put("/{id}", h.Update)
			r.Delete("/{id}", h.Delete)
		})
	})
}

// List handles GET /api/v2/sources
// Supports search via q query param, by speciesid query param, and pagination via limit/offset.
func (h *SourceHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	// Parse pagination parameters
	var limit *int64
	var offset int64 = 0

	if limitStr := query.Get("limit"); limitStr != "" {
		l, err := strconv.ParseInt(limitStr, 10, 64)
		if err != nil || l < 1 {
			middleware.RespondBadRequest(w, "Invalid limit parameter")
			return
		}
		limit = &l
	}

	if offsetStr := query.Get("offset"); offsetStr != "" {
		o, err := strconv.ParseInt(offsetStr, 10, 64)
		if err != nil || o < 0 {
			middleware.RespondBadRequest(w, "Invalid offset parameter")
			return
		}
		offset = o
	}

	// Check for speciesid parameter first - this returns sources with speciessource info
	if speciesIDStr := query.Get("speciesid"); speciesIDStr != "" {
		speciesID, err := strconv.ParseInt(speciesIDStr, 10, 64)
		if err != nil {
			middleware.RespondBadRequest(w, "Invalid speciesid parameter")
			return
		}

		rows, err := h.queries.GetSourcesBySpeciesID(ctx, speciesID)
		if err != nil {
			slog.Error("failed to get sources by species id", "error", err, "speciesid", speciesID)
			middleware.RespondInternalError(w, "Failed to get sources")
			return
		}

		sources := make([]SourceWithSpeciesSourceResponse, len(rows))
		for i, row := range rows {
			sources[i] = SourceWithSpeciesSourceResponse{
				SourceResponse: SourceResponse{
					ID:           row.ID,
					Title:        row.Title,
					Author:       row.Author,
					Pubyear:      row.Pubyear,
					Link:         row.Link,
					Citation:     row.Citation,
					Datacomplete: row.Datacomplete,
					License:      row.License,
					Licenselink:  row.Licenselink,
				},
				SpeciesSource: SpeciesSourceInfo{
					ID:           row.SpeciessourceID,
					Description:  row.SpeciessourceDescription,
					Useasdefault: row.SpeciessourceUseasdefault,
					Externallink: row.SpeciessourceExternallink,
				},
			}
		}

		middleware.RespondOK(w, sources)
		return
	}

	searchQuery := query.Get("q")

	var total int64
	var sources []SourceResponse
	var err error

	if searchQuery != "" {
		// Search mode
		total, err = h.queries.CountSearchSources(ctx, sql.NullString{String: searchQuery, Valid: true})
		if err != nil {
			slog.Error("failed to count search sources", "error", err)
			middleware.RespondInternalError(w, "Failed to count sources")
			return
		}

		if limit != nil {
			rows, err := h.queries.SearchSourcesPaginated(ctx, db.SearchSourcesPaginatedParams{
				Column1: sql.NullString{String: searchQuery, Valid: true},
				Limit:   *limit,
				Offset:  offset,
			})
			if err != nil {
				slog.Error("failed to search sources paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to search sources")
				return
			}
			sources = make([]SourceResponse, len(rows))
			for i, row := range rows {
				sources[i] = sourceToResponse(row)
			}
		} else {
			rows, err := h.queries.SearchSources(ctx, sql.NullString{String: searchQuery, Valid: true})
			if err != nil {
				slog.Error("failed to search sources", "error", err)
				middleware.RespondInternalError(w, "Failed to search sources")
				return
			}
			sources = make([]SourceResponse, len(rows))
			for i, row := range rows {
				sources[i] = sourceToResponse(row)
			}
		}
	} else {
		// List mode
		total, err = h.queries.CountSources(ctx)
		if err != nil {
			slog.Error("failed to count sources", "error", err)
			middleware.RespondInternalError(w, "Failed to count sources")
			return
		}

		if limit != nil {
			rows, err := h.queries.ListSourcesPaginated(ctx, db.ListSourcesPaginatedParams{
				Limit:  *limit,
				Offset: offset,
			})
			if err != nil {
				slog.Error("failed to list sources paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to list sources")
				return
			}
			sources = make([]SourceResponse, len(rows))
			for i, row := range rows {
				sources[i] = sourceToResponse(row)
			}
		} else {
			rows, err := h.queries.ListSources(ctx)
			if err != nil {
				slog.Error("failed to list sources", "error", err)
				middleware.RespondInternalError(w, "Failed to list sources")
				return
			}
			sources = make([]SourceResponse, len(rows))
			for i, row := range rows {
				sources[i] = sourceToResponse(row)
			}
		}
	}

	response := SourceListResponse{
		Data:   sources,
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}

	middleware.RespondOK(w, response)
}

// GetByID handles GET /api/v2/sources/{id}
func (h *SourceHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid source ID")
		return
	}

	row, err := h.queries.GetSourceByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Source not found")
			return
		}
		slog.Error("failed to get source", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get source")
		return
	}

	// Fetch connected species
	speciesRows, err := h.queries.GetSpeciesBySourceID(ctx, id)
	var species []SourceSpecies
	if err != nil {
		slog.Error("failed to get species for source", "error", err, "sourceID", id)
		species = []SourceSpecies{}
	} else {
		species = make([]SourceSpecies, len(speciesRows))
		for i, sp := range speciesRows {
			s := SourceSpecies{
				ID:           sp.ID,
				Name:         sp.Name,
				Datacomplete: sp.Datacomplete,
			}
			if sp.Taxoncode.Valid {
				s.Taxoncode = &sp.Taxoncode.String
			}
			species[i] = s
		}
	}

	response := SourceDetailResponse{
		SourceResponse: sourceToResponse(row),
		Species:        species,
	}

	middleware.RespondOK(w, response)
}

// GetByTitle handles GET /api/v2/sources/by-title/{title}
func (h *SourceHandler) GetByTitle(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	title := chi.URLParam(r, "title")
	if title == "" {
		middleware.RespondBadRequest(w, "Title is required")
		return
	}

	row, err := h.queries.GetSourceByTitle(ctx, title)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Source not found")
			return
		}
		slog.Error("failed to get source by title", "error", err, "title", title)
		middleware.RespondInternalError(w, "Failed to get source")
		return
	}

	middleware.RespondOK(w, sourceToResponse(row))
}

// Create handles POST /api/v2/sources
func (h *SourceHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req SourceCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Title == "" {
		middleware.RespondBadRequest(w, "Title is required")
		return
	}

	id, err := h.queries.CreateSource(ctx, db.CreateSourceParams{
		Title:        req.Title,
		Author:       req.Author,
		Pubyear:      req.Pubyear,
		Link:         req.Link,
		Citation:     req.Citation,
		Datacomplete: req.Datacomplete,
		License:      req.License,
		Licenselink:  req.Licenselink,
	})
	if err != nil {
		slog.Error("failed to create source", "error", err)
		middleware.RespondInternalError(w, "Failed to create source")
		return
	}

	response := SourceResponse{
		ID:           id,
		Title:        req.Title,
		Author:       req.Author,
		Pubyear:      req.Pubyear,
		Link:         req.Link,
		Citation:     req.Citation,
		Datacomplete: req.Datacomplete,
		License:      req.License,
		Licenselink:  req.Licenselink,
	}

	middleware.RespondCreated(w, response)
}

// Update handles PUT /api/v2/sources/{id}
func (h *SourceHandler) Update(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid source ID")
		return
	}

	// Check if source exists
	_, err = h.queries.GetSourceByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Source not found")
			return
		}
		slog.Error("failed to get source", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get source")
		return
	}

	var req SourceUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Title == "" {
		middleware.RespondBadRequest(w, "Title is required")
		return
	}

	if err := h.queries.UpdateSource(ctx, db.UpdateSourceParams{
		Title:        req.Title,
		Author:       req.Author,
		Pubyear:      req.Pubyear,
		Link:         req.Link,
		Citation:     req.Citation,
		Datacomplete: req.Datacomplete,
		License:      req.License,
		Licenselink:  req.Licenselink,
		ID:           id,
	}); err != nil {
		slog.Error("failed to update source", "error", err)
		middleware.RespondInternalError(w, "Failed to update source")
		return
	}

	response := SourceResponse{
		ID:           id,
		Title:        req.Title,
		Author:       req.Author,
		Pubyear:      req.Pubyear,
		Link:         req.Link,
		Citation:     req.Citation,
		Datacomplete: req.Datacomplete,
		License:      req.License,
		Licenselink:  req.Licenselink,
	}

	middleware.RespondOK(w, response)
}

// Delete handles DELETE /api/v2/sources/{id}
func (h *SourceHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid source ID")
		return
	}

	// Check if source exists
	_, err = h.queries.GetSourceByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Source not found")
			return
		}
		slog.Error("failed to get source", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete source")
		return
	}

	if err := h.queries.DeleteSource(ctx, id); err != nil {
		slog.Error("failed to delete source", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete source")
		return
	}

	middleware.RespondNoContent(w)
}

// Helper function to convert db.Source to SourceResponse
func sourceToResponse(s db.Source) SourceResponse {
	return SourceResponse{
		ID:           s.ID,
		Title:        s.Title,
		Author:       s.Author,
		Pubyear:      s.Pubyear,
		Link:         s.Link,
		Citation:     s.Citation,
		Datacomplete: s.Datacomplete,
		License:      s.License,
		Licenselink:  s.Licenselink,
	}
}
