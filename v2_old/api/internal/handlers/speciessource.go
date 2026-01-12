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

// SpeciesSourceHandler handles species-source relationship HTTP requests.
type SpeciesSourceHandler struct {
	queries *db.Queries
	db      *sql.DB
}

// NewSpeciesSourceHandler creates a new SpeciesSourceHandler.
func NewSpeciesSourceHandler(queries *db.Queries, database *sql.DB) *SpeciesSourceHandler {
	return &SpeciesSourceHandler{queries: queries, db: database}
}

// SpeciesSourceResponse represents a species-source relationship in API responses.
type SpeciesSourceResponse struct {
	ID           int64           `json:"id"`
	SpeciesID    int64           `json:"species_id"`
	SourceID     int64           `json:"source_id"`
	Description  string          `json:"description"`
	Useasdefault int64           `json:"useasdefault"`
	Externallink string          `json:"externallink"`
	AliasID      *int64          `json:"alias_id,omitempty"`
	Source       *SourceResponse `json:"source,omitempty"`
}

// SpeciesSourceCreateRequest represents the request body for creating a species-source relationship.
type SpeciesSourceCreateRequest struct {
	SpeciesID    int64  `json:"species_id"`
	SourceID     int64  `json:"source_id"`
	Description  string `json:"description"`
	Useasdefault bool   `json:"useasdefault"`
	Externallink string `json:"externallink"`
	AliasID      *int64 `json:"alias_id,omitempty"`
}

// SpeciesSourceUpdateRequest represents the request body for updating a species-source relationship.
type SpeciesSourceUpdateRequest struct {
	Description  string `json:"description"`
	Useasdefault bool   `json:"useasdefault"`
	Externallink string `json:"externallink"`
	AliasID      *int64 `json:"alias_id,omitempty"`
}

// RegisterRoutes registers species-source routes on the router.
func (h *SpeciesSourceHandler) RegisterRoutes(r chi.Router) {
	r.Route("/species-sources", func(r chi.Router) {
		// Public routes
		r.Get("/", h.List)

		// Protected routes - require authentication
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.Create)
			r.Put("/{id}", h.Update)
			r.Delete("/", h.Delete)
		})
	})
}

// List handles GET /api/v2/species-sources
// Requires speciesid query param. Optionally accepts sourceid to get specific mapping.
func (h *SpeciesSourceHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	speciesIDStr := query.Get("speciesid")
	if speciesIDStr == "" {
		middleware.RespondBadRequest(w, "speciesid query parameter is required")
		return
	}

	speciesID, err := strconv.ParseInt(speciesIDStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid speciesid parameter")
		return
	}

	// Check if we also have sourceid to get a specific mapping
	if sourceIDStr := query.Get("sourceid"); sourceIDStr != "" {
		sourceID, err := strconv.ParseInt(sourceIDStr, 10, 64)
		if err != nil {
			middleware.RespondBadRequest(w, "Invalid sourceid parameter")
			return
		}

		row, err := h.queries.GetSpeciesSourceByIDs(ctx, db.GetSpeciesSourceByIDsParams{
			SpeciesID: speciesID,
			SourceID:  sourceID,
		})
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Species-source mapping not found")
				return
			}
			slog.Error("failed to get species-source mapping", "error", err, "speciesid", speciesID, "sourceid", sourceID)
			middleware.RespondInternalError(w, "Failed to get species-source mapping")
			return
		}

		middleware.RespondOK(w, speciesSourceRowToResponse(row))
		return
	}

	// List all sources for the species
	rows, err := h.queries.ListSpeciesSourcesBySpeciesID(ctx, speciesID)
	if err != nil {
		slog.Error("failed to list species-sources", "error", err, "speciesid", speciesID)
		middleware.RespondInternalError(w, "Failed to list species-sources")
		return
	}

	sources := make([]SpeciesSourceResponse, len(rows))
	for i, row := range rows {
		sources[i] = listSpeciesSourceRowToResponse(row)
	}

	middleware.RespondOK(w, sources)
}

// Create handles POST /api/v2/species-sources
func (h *SpeciesSourceHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req SpeciesSourceCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.SpeciesID == 0 {
		middleware.RespondBadRequest(w, "species_id is required")
		return
	}
	if req.SourceID == 0 {
		middleware.RespondBadRequest(w, "source_id is required")
		return
	}

	// Start a transaction to handle useasdefault logic
	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		slog.Error("failed to begin transaction", "error", err)
		middleware.RespondInternalError(w, "Failed to create species-source")
		return
	}
	defer tx.Rollback()

	qtx := h.queries.WithTx(tx)

	// If setting as default, clear other defaults first
	if req.Useasdefault {
		if err := qtx.ClearDefaultForSpecies(ctx, req.SpeciesID); err != nil {
			slog.Error("failed to clear defaults", "error", err)
			middleware.RespondInternalError(w, "Failed to create species-source")
			return
		}
	}

	var aliasID sql.NullInt64
	if req.AliasID != nil {
		aliasID = sql.NullInt64{Int64: *req.AliasID, Valid: true}
	}

	useasdefault := int64(0)
	if req.Useasdefault {
		useasdefault = 1
	}

	id, err := qtx.CreateSpeciesSource(ctx, db.CreateSpeciesSourceParams{
		SpeciesID:    req.SpeciesID,
		SourceID:     req.SourceID,
		Description:  req.Description,
		Useasdefault: useasdefault,
		Externallink: req.Externallink,
		AliasID:      aliasID,
	})
	if err != nil {
		slog.Error("failed to create species-source", "error", err)
		middleware.RespondInternalError(w, "Failed to create species-source")
		return
	}

	if err := tx.Commit(); err != nil {
		slog.Error("failed to commit transaction", "error", err)
		middleware.RespondInternalError(w, "Failed to create species-source")
		return
	}

	// Fetch the created record to return with source details
	row, err := h.queries.GetSpeciesSourceByID(ctx, id)
	if err != nil {
		slog.Error("failed to fetch created species-source", "error", err)
		middleware.RespondInternalError(w, "Created but failed to fetch species-source")
		return
	}

	middleware.RespondCreated(w, getSpeciesSourceRowToResponse(row))
}

// Update handles PUT /api/v2/species-sources/{id}
func (h *SpeciesSourceHandler) Update(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid species-source ID")
		return
	}

	// Check if exists and get the species_id for clearing defaults
	existing, err := h.queries.GetSpeciesSourceByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Species-source mapping not found")
			return
		}
		slog.Error("failed to get species-source", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to update species-source")
		return
	}

	var req SpeciesSourceUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	// Start a transaction to handle useasdefault logic
	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		slog.Error("failed to begin transaction", "error", err)
		middleware.RespondInternalError(w, "Failed to update species-source")
		return
	}
	defer tx.Rollback()

	qtx := h.queries.WithTx(tx)

	// If setting as default, clear other defaults first
	if req.Useasdefault {
		if err := qtx.ClearDefaultForSpecies(ctx, existing.SpeciesID); err != nil {
			slog.Error("failed to clear defaults", "error", err)
			middleware.RespondInternalError(w, "Failed to update species-source")
			return
		}
	}

	var aliasID sql.NullInt64
	if req.AliasID != nil {
		aliasID = sql.NullInt64{Int64: *req.AliasID, Valid: true}
	}

	useasdefault := int64(0)
	if req.Useasdefault {
		useasdefault = 1
	}

	if err := qtx.UpdateSpeciesSource(ctx, db.UpdateSpeciesSourceParams{
		Description:  req.Description,
		Useasdefault: useasdefault,
		Externallink: req.Externallink,
		AliasID:      aliasID,
		ID:           id,
	}); err != nil {
		slog.Error("failed to update species-source", "error", err)
		middleware.RespondInternalError(w, "Failed to update species-source")
		return
	}

	if err := tx.Commit(); err != nil {
		slog.Error("failed to commit transaction", "error", err)
		middleware.RespondInternalError(w, "Failed to update species-source")
		return
	}

	// Fetch the updated record
	row, err := h.queries.GetSpeciesSourceByID(ctx, id)
	if err != nil {
		slog.Error("failed to fetch updated species-source", "error", err)
		middleware.RespondInternalError(w, "Updated but failed to fetch species-source")
		return
	}

	middleware.RespondOK(w, getSpeciesSourceRowToResponse(row))
}

// Delete handles DELETE /api/v2/species-sources
// Requires both speciesid and sourceid query params.
func (h *SpeciesSourceHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	speciesIDStr := query.Get("speciesid")
	sourceIDStr := query.Get("sourceid")

	if speciesIDStr == "" || sourceIDStr == "" {
		middleware.RespondBadRequest(w, "Both speciesid and sourceid query parameters are required")
		return
	}

	speciesID, err := strconv.ParseInt(speciesIDStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid speciesid parameter")
		return
	}

	sourceID, err := strconv.ParseInt(sourceIDStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid sourceid parameter")
		return
	}

	// Check if mapping exists
	_, err = h.queries.GetSpeciesSourceByIDs(ctx, db.GetSpeciesSourceByIDsParams{
		SpeciesID: speciesID,
		SourceID:  sourceID,
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Species-source mapping not found")
			return
		}
		slog.Error("failed to get species-source", "error", err, "speciesid", speciesID, "sourceid", sourceID)
		middleware.RespondInternalError(w, "Failed to delete species-source")
		return
	}

	if err := h.queries.DeleteSpeciesSourceByIDs(ctx, db.DeleteSpeciesSourceByIDsParams{
		SpeciesID: speciesID,
		SourceID:  sourceID,
	}); err != nil {
		slog.Error("failed to delete species-source", "error", err, "speciesid", speciesID, "sourceid", sourceID)
		middleware.RespondInternalError(w, "Failed to delete species-source")
		return
	}

	middleware.RespondNoContent(w)
}

// Helper functions to convert db rows to response types

func speciesSourceRowToResponse(row db.GetSpeciesSourceByIDsRow) SpeciesSourceResponse {
	var aliasID *int64
	if row.AliasID.Valid {
		aliasID = &row.AliasID.Int64
	}

	return SpeciesSourceResponse{
		ID:           row.ID,
		SpeciesID:    row.SpeciesID,
		SourceID:     row.SourceID,
		Description:  row.Description,
		Useasdefault: row.Useasdefault,
		Externallink: row.Externallink,
		AliasID:      aliasID,
		Source: &SourceResponse{
			ID:           row.SourceIDDup,
			Title:        row.SourceTitle,
			Author:       row.SourceAuthor,
			Pubyear:      row.SourcePubyear,
			Link:         row.SourceLink,
			Citation:     row.SourceCitation,
			Datacomplete: row.SourceDatacomplete,
			License:      row.SourceLicense,
			Licenselink:  row.SourceLicenselink,
		},
	}
}

func listSpeciesSourceRowToResponse(row db.ListSpeciesSourcesBySpeciesIDRow) SpeciesSourceResponse {
	var aliasID *int64
	if row.AliasID.Valid {
		aliasID = &row.AliasID.Int64
	}

	return SpeciesSourceResponse{
		ID:           row.ID,
		SpeciesID:    row.SpeciesID,
		SourceID:     row.SourceID,
		Description:  row.Description,
		Useasdefault: row.Useasdefault,
		Externallink: row.Externallink,
		AliasID:      aliasID,
		Source: &SourceResponse{
			ID:           row.SourceIDDup,
			Title:        row.SourceTitle,
			Author:       row.SourceAuthor,
			Pubyear:      row.SourcePubyear,
			Link:         row.SourceLink,
			Citation:     row.SourceCitation,
			Datacomplete: row.SourceDatacomplete,
			License:      row.SourceLicense,
			Licenselink:  row.SourceLicenselink,
		},
	}
}

func getSpeciesSourceRowToResponse(row db.GetSpeciesSourceByIDRow) SpeciesSourceResponse {
	var aliasID *int64
	if row.AliasID.Valid {
		aliasID = &row.AliasID.Int64
	}

	return SpeciesSourceResponse{
		ID:           row.ID,
		SpeciesID:    row.SpeciesID,
		SourceID:     row.SourceID,
		Description:  row.Description,
		Useasdefault: row.Useasdefault,
		Externallink: row.Externallink,
		AliasID:      aliasID,
		Source: &SourceResponse{
			ID:           row.SourceIDDup,
			Title:        row.SourceTitle,
			Author:       row.SourceAuthor,
			Pubyear:      row.SourcePubyear,
			Link:         row.SourceLink,
			Citation:     row.SourceCitation,
			Datacomplete: row.SourceDatacomplete,
			License:      row.SourceLicense,
			Licenselink:  row.SourceLicenselink,
		},
	}
}
