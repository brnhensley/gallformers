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

// GlossaryHandler handles glossary-related HTTP requests.
type GlossaryHandler struct {
	queries *db.Queries
}

// NewGlossaryHandler creates a new GlossaryHandler.
func NewGlossaryHandler(queries *db.Queries) *GlossaryHandler {
	return &GlossaryHandler{queries: queries}
}

// GlossaryResponse represents a glossary entry in API responses.
type GlossaryResponse struct {
	ID         int64  `json:"id"`
	Word       string `json:"word"`
	Definition string `json:"definition"`
	URLs       string `json:"urls"`
}

// GlossaryListResponse represents a paginated list of glossary entries.
type GlossaryListResponse struct {
	Data   []GlossaryResponse `json:"data"`
	Total  int64              `json:"total"`
	Limit  *int64             `json:"limit,omitempty"`
	Offset int64              `json:"offset"`
}

// GlossaryCreateRequest represents the request body for creating a glossary entry.
type GlossaryCreateRequest struct {
	Word       string `json:"word"`
	Definition string `json:"definition"`
	URLs       string `json:"urls"`
}

// GlossaryUpdateRequest represents the request body for updating a glossary entry.
type GlossaryUpdateRequest struct {
	Word       string `json:"word"`
	Definition string `json:"definition"`
	URLs       string `json:"urls"`
}

// RegisterRoutes registers glossary routes on the router.
func (h *GlossaryHandler) RegisterRoutes(r chi.Router) {
	r.Route("/glossary", func(r chi.Router) {
		// Public routes
		r.Get("/", h.List)
		r.Get("/{id}", h.GetByID)
		r.Get("/by-word/{word}", h.GetByWord)

		// Protected routes - require authentication
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.Create)
			r.Put("/{id}", h.Update)
			r.Delete("/{id}", h.Delete)
		})
	})
}

// List handles GET /api/v2/glossary
// Supports search via q query param and pagination via limit/offset.
func (h *GlossaryHandler) List(w http.ResponseWriter, r *http.Request) {
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

	searchQuery := query.Get("q")

	var total int64
	var entries []GlossaryResponse
	var err error

	if searchQuery != "" {
		// Search mode
		total, err = h.queries.CountSearchGlossary(ctx, sql.NullString{String: searchQuery, Valid: true})
		if err != nil {
			slog.Error("failed to count search glossary", "error", err)
			middleware.RespondInternalError(w, "Failed to count glossary entries")
			return
		}

		if limit != nil {
			rows, err := h.queries.SearchGlossaryPaginated(ctx, db.SearchGlossaryPaginatedParams{
				Column1: sql.NullString{String: searchQuery, Valid: true},
				Limit:   *limit,
				Offset:  offset,
			})
			if err != nil {
				slog.Error("failed to search glossary paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to search glossary")
				return
			}
			entries = make([]GlossaryResponse, len(rows))
			for i, row := range rows {
				entries[i] = glossaryToResponse(row)
			}
		} else {
			rows, err := h.queries.SearchGlossary(ctx, sql.NullString{String: searchQuery, Valid: true})
			if err != nil {
				slog.Error("failed to search glossary", "error", err)
				middleware.RespondInternalError(w, "Failed to search glossary")
				return
			}
			entries = make([]GlossaryResponse, len(rows))
			for i, row := range rows {
				entries[i] = glossaryToResponse(row)
			}
		}
	} else {
		// List mode
		total, err = h.queries.CountGlossary(ctx)
		if err != nil {
			slog.Error("failed to count glossary", "error", err)
			middleware.RespondInternalError(w, "Failed to count glossary entries")
			return
		}

		if limit != nil {
			rows, err := h.queries.ListGlossaryPaginated(ctx, db.ListGlossaryPaginatedParams{
				Limit:  *limit,
				Offset: offset,
			})
			if err != nil {
				slog.Error("failed to list glossary paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to list glossary")
				return
			}
			entries = make([]GlossaryResponse, len(rows))
			for i, row := range rows {
				entries[i] = glossaryToResponse(row)
			}
		} else {
			rows, err := h.queries.ListGlossary(ctx)
			if err != nil {
				slog.Error("failed to list glossary", "error", err)
				middleware.RespondInternalError(w, "Failed to list glossary")
				return
			}
			entries = make([]GlossaryResponse, len(rows))
			for i, row := range rows {
				entries[i] = glossaryToResponse(row)
			}
		}
	}

	response := GlossaryListResponse{
		Data:   entries,
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}

	middleware.RespondOK(w, response)
}

// GetByID handles GET /api/v2/glossary/{id}
func (h *GlossaryHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid glossary ID")
		return
	}

	row, err := h.queries.GetGlossaryByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Glossary entry not found")
			return
		}
		slog.Error("failed to get glossary entry", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get glossary entry")
		return
	}

	middleware.RespondOK(w, glossaryToResponse(row))
}

// GetByWord handles GET /api/v2/glossary/by-word/{word}
func (h *GlossaryHandler) GetByWord(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	word := chi.URLParam(r, "word")
	if word == "" {
		middleware.RespondBadRequest(w, "Word is required")
		return
	}

	row, err := h.queries.GetGlossaryByWord(ctx, word)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Glossary entry not found")
			return
		}
		slog.Error("failed to get glossary entry by word", "error", err, "word", word)
		middleware.RespondInternalError(w, "Failed to get glossary entry")
		return
	}

	middleware.RespondOK(w, glossaryToResponse(row))
}

// Create handles POST /api/v2/glossary
func (h *GlossaryHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req GlossaryCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Word == "" {
		middleware.RespondBadRequest(w, "Word is required")
		return
	}

	if req.Definition == "" {
		middleware.RespondBadRequest(w, "Definition is required")
		return
	}

	id, err := h.queries.CreateGlossary(ctx, db.CreateGlossaryParams{
		Word:       req.Word,
		Definition: req.Definition,
		Urls:       req.URLs,
	})
	if err != nil {
		slog.Error("failed to create glossary entry", "error", err)
		middleware.RespondInternalError(w, "Failed to create glossary entry")
		return
	}

	response := GlossaryResponse{
		ID:         id,
		Word:       req.Word,
		Definition: req.Definition,
		URLs:       req.URLs,
	}

	middleware.RespondCreated(w, response)
}

// Update handles PUT /api/v2/glossary/{id}
func (h *GlossaryHandler) Update(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid glossary ID")
		return
	}

	// Check if entry exists
	_, err = h.queries.GetGlossaryByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Glossary entry not found")
			return
		}
		slog.Error("failed to get glossary entry", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get glossary entry")
		return
	}

	var req GlossaryUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Word == "" {
		middleware.RespondBadRequest(w, "Word is required")
		return
	}

	if req.Definition == "" {
		middleware.RespondBadRequest(w, "Definition is required")
		return
	}

	if err := h.queries.UpdateGlossary(ctx, db.UpdateGlossaryParams{
		Word:       req.Word,
		Definition: req.Definition,
		Urls:       req.URLs,
		ID:         id,
	}); err != nil {
		slog.Error("failed to update glossary entry", "error", err)
		middleware.RespondInternalError(w, "Failed to update glossary entry")
		return
	}

	response := GlossaryResponse{
		ID:         id,
		Word:       req.Word,
		Definition: req.Definition,
		URLs:       req.URLs,
	}

	middleware.RespondOK(w, response)
}

// Delete handles DELETE /api/v2/glossary/{id}
func (h *GlossaryHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid glossary ID")
		return
	}

	// Check if entry exists
	_, err = h.queries.GetGlossaryByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Glossary entry not found")
			return
		}
		slog.Error("failed to get glossary entry", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete glossary entry")
		return
	}

	if err := h.queries.DeleteGlossary(ctx, id); err != nil {
		slog.Error("failed to delete glossary entry", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete glossary entry")
		return
	}

	middleware.RespondNoContent(w)
}

// Helper function to convert db.Glossary to GlossaryResponse
func glossaryToResponse(g db.Glossary) GlossaryResponse {
	return GlossaryResponse{
		ID:         g.ID,
		Word:       g.Word,
		Definition: g.Definition,
		URLs:       g.Urls,
	}
}
