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

// GallHostHandler handles gall-host relationship HTTP requests.
type GallHostHandler struct {
	queries *db.Queries
}

// NewGallHostHandler creates a new GallHostHandler.
func NewGallHostHandler(queries *db.Queries) *GallHostHandler {
	return &GallHostHandler{queries: queries}
}

// GallHostResponse represents a gall-host relationship in API responses.
type GallHostResponse struct {
	ID            int64  `json:"id"`
	GallSpeciesID int64  `json:"gall_species_id"`
	HostSpeciesID int64  `json:"host_species_id"`
	HostName      string `json:"host_name"`
}

// GallHostListResponse represents a list of gall-host relationships.
type GallHostListResponse struct {
	Data  []GallHostResponse `json:"data"`
	Total int64              `json:"total"`
}

// GallHostCreateRequest represents the request body for creating a gall-host association.
type GallHostCreateRequest struct {
	GallSpeciesID int64 `json:"gall_species_id"`
	HostSpeciesID int64 `json:"host_species_id"`
}

// GallHostDeleteRequest represents the request body for deleting a gall-host association.
type GallHostDeleteRequest struct {
	GallSpeciesID int64 `json:"gall_species_id"`
	HostSpeciesID int64 `json:"host_species_id"`
}

// RegisterRoutes registers gall-host routes on the router.
func (h *GallHostHandler) RegisterRoutes(r chi.Router) {
	r.Route("/gall-hosts", func(r chi.Router) {
		// Public routes
		r.Get("/", h.List)

		// Protected routes - require authentication
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.Create)
			r.Delete("/", h.Delete)
		})
	})
}

// List handles GET /api/v2/gall-hosts
// Requires gallid query parameter.
func (h *GallHostHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	gallIDStr := query.Get("gallid")
	if gallIDStr == "" {
		middleware.RespondBadRequest(w, "gallid parameter is required")
		return
	}

	gallID, err := strconv.ParseInt(gallIDStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid gallid parameter")
		return
	}

	// Get total count
	total, err := h.queries.CountHostsByGallID(ctx, sql.NullInt64{Int64: gallID, Valid: true})
	if err != nil {
		slog.Error("failed to count hosts by gall ID", "error", err)
		middleware.RespondInternalError(w, "Failed to count hosts")
		return
	}

	// Get hosts
	rows, err := h.queries.ListHostsByGallID(ctx, sql.NullInt64{Int64: gallID, Valid: true})
	if err != nil {
		slog.Error("failed to list hosts by gall ID", "error", err)
		middleware.RespondInternalError(w, "Failed to list hosts")
		return
	}

	hosts := make([]GallHostResponse, len(rows))
	for i, row := range rows {
		hosts[i] = GallHostResponse{
			ID:            row.HostRelationID,
			GallSpeciesID: gallID,
			HostSpeciesID: row.HostSpeciesID,
			HostName:      row.HostName,
		}
	}

	middleware.RespondOK(w, GallHostListResponse{
		Data:  hosts,
		Total: total,
	})
}

// Create handles POST /api/v2/gall-hosts
func (h *GallHostHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req GallHostCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.GallSpeciesID <= 0 {
		middleware.RespondBadRequest(w, "gall_species_id is required")
		return
	}
	if req.HostSpeciesID <= 0 {
		middleware.RespondBadRequest(w, "host_species_id is required")
		return
	}

	// Check if the relationship already exists
	_, err := h.queries.GetGallHostByIDs(ctx, db.GetGallHostByIDsParams{
		GallSpeciesID: sql.NullInt64{Int64: req.GallSpeciesID, Valid: true},
		HostSpeciesID: sql.NullInt64{Int64: req.HostSpeciesID, Valid: true},
	})
	if err == nil {
		middleware.RespondBadRequest(w, "Gall-host relationship already exists")
		return
	}
	if !errors.Is(err, sql.ErrNoRows) {
		slog.Error("failed to check existing gall-host", "error", err)
		middleware.RespondInternalError(w, "Failed to create gall-host relationship")
		return
	}

	// Create the relationship
	id, err := h.queries.CreateGallHost(ctx, db.CreateGallHostParams{
		GallSpeciesID: sql.NullInt64{Int64: req.GallSpeciesID, Valid: true},
		HostSpeciesID: sql.NullInt64{Int64: req.HostSpeciesID, Valid: true},
	})
	if err != nil {
		slog.Error("failed to create gall-host", "error", err)
		middleware.RespondInternalError(w, "Failed to create gall-host relationship")
		return
	}

	// Fetch the created relationship to get the host name
	row, err := h.queries.GetGallHostByIDs(ctx, db.GetGallHostByIDsParams{
		GallSpeciesID: sql.NullInt64{Int64: req.GallSpeciesID, Valid: true},
		HostSpeciesID: sql.NullInt64{Int64: req.HostSpeciesID, Valid: true},
	})
	if err != nil {
		// Relationship was created but we can't fetch details, return minimal response
		middleware.RespondCreated(w, GallHostResponse{
			ID:            id,
			GallSpeciesID: req.GallSpeciesID,
			HostSpeciesID: req.HostSpeciesID,
		})
		return
	}

	middleware.RespondCreated(w, GallHostResponse{
		ID:            row.HostRelationID,
		GallSpeciesID: req.GallSpeciesID,
		HostSpeciesID: row.HostSpeciesID.Int64,
		HostName:      row.HostName,
	})
}

// Delete handles DELETE /api/v2/gall-hosts
func (h *GallHostHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req GallHostDeleteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.GallSpeciesID <= 0 {
		middleware.RespondBadRequest(w, "gall_species_id is required")
		return
	}
	if req.HostSpeciesID <= 0 {
		middleware.RespondBadRequest(w, "host_species_id is required")
		return
	}

	// Check if the relationship exists
	_, err := h.queries.GetGallHostByIDs(ctx, db.GetGallHostByIDsParams{
		GallSpeciesID: sql.NullInt64{Int64: req.GallSpeciesID, Valid: true},
		HostSpeciesID: sql.NullInt64{Int64: req.HostSpeciesID, Valid: true},
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Gall-host relationship not found")
			return
		}
		slog.Error("failed to get gall-host", "error", err)
		middleware.RespondInternalError(w, "Failed to delete gall-host relationship")
		return
	}

	// Delete the relationship
	if err := h.queries.DeleteGallHost(ctx, db.DeleteGallHostParams{
		GallSpeciesID: sql.NullInt64{Int64: req.GallSpeciesID, Valid: true},
		HostSpeciesID: sql.NullInt64{Int64: req.HostSpeciesID, Valid: true},
	}); err != nil {
		slog.Error("failed to delete gall-host", "error", err)
		middleware.RespondInternalError(w, "Failed to delete gall-host relationship")
		return
	}

	middleware.RespondNoContent(w)
}
