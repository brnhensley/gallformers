package handlers

import (
	"context"
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

// TaxonomyHandler handles taxonomy-related HTTP requests.
type TaxonomyHandler struct {
	queries *db.Queries
}

// NewTaxonomyHandler creates a new TaxonomyHandler.
func NewTaxonomyHandler(queries *db.Queries) *TaxonomyHandler {
	return &TaxonomyHandler{queries: queries}
}

// TaxonomyEntry represents a taxonomy entry in API responses.
type TaxonomyEntry struct {
	ID          int64   `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Type        string  `json:"type"`
	ParentID    *int64  `json:"parent_id,omitempty"`
	ParentName  *string `json:"parent_name,omitempty"`
	ParentType  *string `json:"parent_type,omitempty"`
}

// FamilyResponse represents a family with its genera.
type FamilyResponse struct {
	TaxonomyEntry
	Genera []TaxonomyEntry `json:"genera,omitempty"`
}

// SectionResponse represents a section with species and aliases.
type SectionResponse struct {
	TaxonomyEntry
	Species []SimpleSpecies `json:"species,omitempty"`
	Aliases []Alias         `json:"aliases,omitempty"`
}

// SimpleSpecies represents minimal species info.
type SimpleSpecies struct {
	ID           int64   `json:"id"`
	Name         string  `json:"name"`
	Taxoncode    *string `json:"taxoncode,omitempty"`
	Datacomplete bool    `json:"datacomplete"`
	AbundanceID  *int64  `json:"abundance_id,omitempty"`
}

// FGS represents Family-Genus-Section for a species.
type FGS struct {
	Family  TaxonomyEntry  `json:"family"`
	Genus   TaxonomyEntry  `json:"genus"`
	Section *TaxonomyEntry `json:"section,omitempty"`
}

// TaxonomyListResponse wraps a list of taxonomy entries.
type TaxonomyListResponse struct {
	Data   []TaxonomyEntry `json:"data"`
	Total  int64           `json:"total"`
	Offset int             `json:"offset"`
}

// FamilyListResponse wraps a list of families.
type FamilyListResponse struct {
	Data   []FamilyResponse `json:"data"`
	Total  int64            `json:"total"`
	Offset int              `json:"offset"`
}

// TaxonomyUpsertRequest represents the request body for upserting taxonomy.
type TaxonomyUpsertRequest struct {
	ID          int64   `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Type        string  `json:"type"`
	ParentID    *int64  `json:"parent_id,omitempty"`
	Species     []int64 `json:"species,omitempty"`
}

// FamilyUpsertRequest represents the request body for upserting a family.
type FamilyUpsertRequest struct {
	ID          int64          `json:"id"`
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Genera      []GenusRequest `json:"genera,omitempty"`
}

// GenusRequest represents a genus in create/update requests.
type GenusRequest struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
}

// GeneraMoveRequest represents the request body for moving genera.
type GeneraMoveRequest struct {
	Genera      []int64 `json:"genera"`
	OldFamilyID int64   `json:"oldFamilyId"`
	NewFamilyID int64   `json:"newFamilyId"`
}

// RegisterRoutes registers taxonomy routes on the router.
func (h *TaxonomyHandler) RegisterRoutes(r chi.Router) {
	r.Route("/taxonomy", func(r chi.Router) {
		// Public routes
		r.Get("/", h.GetTaxonomy)
		r.Get("/{id}", h.GetTaxonomyByID)

		// Protected routes
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.UpsertTaxonomy)
			r.Delete("/{id}", h.DeleteTaxonomy)
		})

		// Family routes
		r.Route("/families", func(r chi.Router) {
			r.Get("/", h.ListFamilies)
			r.Get("/{id}", h.GetFamilyByID)

			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireAuth)
				r.Post("/", h.UpsertFamily)
				r.Delete("/{id}", h.DeleteFamily)
			})
		})

		// Genus routes
		r.Route("/genera", func(r chi.Router) {
			r.Get("/", h.ListGenera)

			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireAuth)
				r.Post("/move", h.MoveGenera)
			})
		})

		// Section routes
		r.Route("/sections", func(r chi.Router) {
			r.Get("/", h.ListSections)
			r.Get("/{id}", h.GetSectionByID)

			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireAuth)
				r.Delete("/{id}", h.DeleteSection)
			})
		})
	})
}

// GetTaxonomy handles GET /api/v2/taxonomy
// Supports ?id=X (taxonomy for species by species ID) or ?name=X (by exact name)
func (h *TaxonomyHandler) GetTaxonomy(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	// If id is provided, get taxonomy for species
	if idStr := query.Get("id"); idStr != "" {
		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil {
			middleware.RespondBadRequest(w, "Invalid id parameter")
			return
		}

		rows, err := h.queries.GetTaxonomyForSpecies(ctx, id)
		if err != nil {
			slog.Error("failed to get taxonomy for species", "error", err, "speciesID", id)
			middleware.RespondInternalError(w, "Failed to get taxonomy")
			return
		}

		// Build FGS response
		fgs := h.buildFGS(rows)
		middleware.RespondOK(w, fgs)
		return
	}

	// If name is provided, search by exact name
	if name := query.Get("name"); name != "" {
		rows, err := h.queries.GetTaxonomyByName(ctx, name)
		if err != nil {
			slog.Error("failed to get taxonomy by name", "error", err, "name", name)
			middleware.RespondInternalError(w, "Failed to get taxonomy")
			return
		}

		entries := make([]TaxonomyEntry, len(rows))
		for i, row := range rows {
			entries[i] = h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
				row.ParentID, row.ParentName, row.ParentType)
		}

		middleware.RespondOK(w, entries)
		return
	}

	middleware.RespondBadRequest(w, "Must provide either id or name parameter")
}

// GetTaxonomyByID handles GET /api/v2/taxonomy/{id}
func (h *TaxonomyHandler) GetTaxonomyByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid taxonomy ID")
		return
	}

	row, err := h.queries.GetTaxonomyByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Taxonomy entry not found")
			return
		}
		slog.Error("failed to get taxonomy", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get taxonomy")
		return
	}

	entry := h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
		row.ParentID, row.ParentName, row.ParentType)

	middleware.RespondOK(w, entry)
}

// UpsertTaxonomy handles POST /api/v2/taxonomy
func (h *TaxonomyHandler) UpsertTaxonomy(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req TaxonomyUpsertRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Name == "" {
		middleware.RespondBadRequest(w, "Name is required")
		return
	}

	if req.Type == "" {
		middleware.RespondBadRequest(w, "Type is required")
		return
	}

	var parentID sql.NullInt64
	if req.ParentID != nil {
		parentID = sql.NullInt64{Int64: *req.ParentID, Valid: true}
	}

	var taxID int64

	if req.ID <= 0 {
		// Insert new taxonomy
		var err error
		taxID, err = h.queries.InsertTaxonomy(ctx, db.InsertTaxonomyParams{
			Name:        req.Name,
			Description: sql.NullString{String: req.Description, Valid: req.Description != ""},
			Type:        req.Type,
			ParentID:    parentID,
		})
		if err != nil {
			slog.Error("failed to insert taxonomy", "error", err)
			middleware.RespondInternalError(w, "Failed to create taxonomy")
			return
		}
	} else {
		// Update existing taxonomy
		taxID = req.ID
		if err := h.queries.UpdateTaxonomy(ctx, db.UpdateTaxonomyParams{
			Name:        req.Name,
			Description: sql.NullString{String: req.Description, Valid: req.Description != ""},
			ParentID:    parentID,
			ID:          req.ID,
		}); err != nil {
			slog.Error("failed to update taxonomy", "error", err)
			middleware.RespondInternalError(w, "Failed to update taxonomy")
			return
		}
	}

	// Handle species links if provided
	if len(req.Species) > 0 {
		// Delete existing links
		h.queries.DeleteSpeciesTaxonomyByTaxonomyID(ctx, taxID)

		// Create new links
		for _, speciesID := range req.Species {
			if err := h.queries.InsertSpeciesTaxonomy(ctx, db.InsertSpeciesTaxonomyParams{
				SpeciesID:  speciesID,
				TaxonomyID: taxID,
			}); err != nil {
				slog.Error("failed to link species to taxonomy", "error", err, "speciesID", speciesID)
			}
		}
	}

	// Fetch and return the result
	row, err := h.queries.GetTaxonomyByID(ctx, taxID)
	if err != nil {
		slog.Error("failed to get created taxonomy", "error", err)
		middleware.RespondInternalError(w, "Failed to get created taxonomy")
		return
	}

	entry := h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
		row.ParentID, row.ParentName, row.ParentType)

	if req.ID <= 0 {
		middleware.RespondCreated(w, entry)
	} else {
		middleware.RespondOK(w, entry)
	}
}

// DeleteTaxonomy handles DELETE /api/v2/taxonomy/{id}
func (h *TaxonomyHandler) DeleteTaxonomy(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid taxonomy ID")
		return
	}

	// Check if exists
	row, err := h.queries.GetTaxonomyByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Taxonomy entry not found")
			return
		}
		slog.Error("failed to get taxonomy", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete taxonomy")
		return
	}

	// If it's a family, delete species under it first
	if row.Type == "family" {
		if err := h.queries.DeleteSpeciesForFamily(ctx, id); err != nil {
			slog.Error("failed to delete species for family", "error", err, "id", id)
		}
	}

	// Delete the taxonomy entry
	if err := h.queries.DeleteTaxonomy(ctx, id); err != nil {
		slog.Error("failed to delete taxonomy", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete taxonomy")
		return
	}

	middleware.RespondNoContent(w)
}

// ListFamilies handles GET /api/v2/taxonomy/families
// Supports ?q=X (search), ?familyid=X (by ID), ?name=X (by exact name)
func (h *TaxonomyHandler) ListFamilies(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	// Search by ID
	if familyIDStr := query.Get("familyid"); familyIDStr != "" {
		id, err := strconv.ParseInt(familyIDStr, 10, 64)
		if err != nil {
			middleware.RespondBadRequest(w, "Invalid familyid parameter")
			return
		}

		row, err := h.queries.GetFamilyByID(ctx, id)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Family not found")
				return
			}
			slog.Error("failed to get family", "error", err, "id", id)
			middleware.RespondInternalError(w, "Failed to get family")
			return
		}

		family := h.rowToFamilyResponse(ctx, row.ID, row.Name, row.Description, row.Type)
		middleware.RespondOK(w, []FamilyResponse{family})
		return
	}

	// Search by name (exact match)
	if name := query.Get("name"); name != "" {
		row, err := h.queries.GetFamilyByName(ctx, name)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Family not found")
				return
			}
			slog.Error("failed to get family by name", "error", err, "name", name)
			middleware.RespondInternalError(w, "Failed to get family")
			return
		}

		family := h.rowToFamilyResponse(ctx, row.ID, row.Name, row.Description, row.Type)
		middleware.RespondOK(w, []FamilyResponse{family})
		return
	}

	// Search by query string
	if q := query.Get("q"); q != "" {
		searchTerm := "%" + q + "%"
		rows, err := h.queries.SearchFamilies(ctx, searchTerm)
		if err != nil {
			slog.Error("failed to search families", "error", err, "query", q)
			middleware.RespondInternalError(w, "Failed to search families")
			return
		}

		families := make([]TaxonomyEntry, len(rows))
		for i, row := range rows {
			families[i] = h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
				sql.NullInt64{}, sql.NullString{}, sql.NullString{})
		}

		middleware.RespondOK(w, families)
		return
	}

	// List all families
	rows, err := h.queries.ListFamilies(ctx)
	if err != nil {
		slog.Error("failed to list families", "error", err)
		middleware.RespondInternalError(w, "Failed to list families")
		return
	}

	total, err := h.queries.CountFamilies(ctx)
	if err != nil {
		slog.Error("failed to count families", "error", err)
		middleware.RespondInternalError(w, "Failed to count families")
		return
	}

	families := make([]TaxonomyEntry, len(rows))
	for i, row := range rows {
		families[i] = h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
			sql.NullInt64{}, sql.NullString{}, sql.NullString{})
	}

	middleware.RespondOK(w, TaxonomyListResponse{
		Data:   families,
		Total:  total,
		Offset: 0,
	})
}

// GetFamilyByID handles GET /api/v2/taxonomy/families/{id}
func (h *TaxonomyHandler) GetFamilyByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid family ID")
		return
	}

	row, err := h.queries.GetFamilyByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Family not found")
			return
		}
		slog.Error("failed to get family", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get family")
		return
	}

	family := h.rowToFamilyResponse(ctx, row.ID, row.Name, row.Description, row.Type)
	middleware.RespondOK(w, family)
}

// UpsertFamily handles POST /api/v2/taxonomy/families
func (h *TaxonomyHandler) UpsertFamily(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req FamilyUpsertRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Name == "" {
		middleware.RespondBadRequest(w, "Name is required")
		return
	}

	var familyID int64

	if req.ID <= 0 {
		// Create new family
		var err error
		familyID, err = h.queries.InsertFamily(ctx, db.InsertFamilyParams{
			Name:        req.Name,
			Description: sql.NullString{String: req.Description, Valid: req.Description != ""},
		})
		if err != nil {
			slog.Error("failed to insert family", "error", err)
			middleware.RespondInternalError(w, "Failed to create family")
			return
		}
	} else {
		// Update existing family
		familyID = req.ID
		if err := h.queries.UpdateFamily(ctx, db.UpdateFamilyParams{
			Name:        req.Name,
			Description: sql.NullString{String: req.Description, Valid: req.Description != ""},
			ID:          req.ID,
		}); err != nil {
			slog.Error("failed to update family", "error", err)
			middleware.RespondInternalError(w, "Failed to update family")
			return
		}
	}

	// Handle genera
	for _, genus := range req.Genera {
		if genus.ID <= 0 {
			// Create new genus
			genusID, err := h.queries.InsertGenus(ctx, db.InsertGenusParams{
				Name:        genus.Name,
				Description: sql.NullString{String: genus.Description, Valid: genus.Description != ""},
				ParentID:    sql.NullInt64{Int64: familyID, Valid: true},
			})
			if err != nil {
				slog.Error("failed to insert genus", "error", err)
				continue
			}

			// Create taxonomytaxonomy relationship
			if err := h.queries.InsertTaxonomyTaxonomy(ctx, db.InsertTaxonomyTaxonomyParams{
				TaxonomyID: familyID,
				ChildID:    genusID,
			}); err != nil {
				slog.Error("failed to link genus to family", "error", err)
			}
		} else {
			// Update existing genus
			if err := h.queries.UpdateGenus(ctx, db.UpdateGenusParams{
				Name:        genus.Name,
				Description: sql.NullString{String: genus.Description, Valid: genus.Description != ""},
				ParentID:    sql.NullInt64{Int64: familyID, Valid: true},
				ID:          genus.ID,
			}); err != nil {
				slog.Error("failed to update genus", "error", err)
			}

			// Update species names to reflect genus name change
			if err := h.queries.UpdateSpeciesNamesForGenus(ctx, db.UpdateSpeciesNamesForGenusParams{
				NewGenus:   genus.Name,
				TaxonomyID: genus.ID,
			}); err != nil {
				slog.Error("failed to update species names", "error", err)
			}
		}
	}

	// Fetch and return the result
	row, err := h.queries.GetFamilyByID(ctx, familyID)
	if err != nil {
		slog.Error("failed to get created family", "error", err)
		middleware.RespondInternalError(w, "Failed to get created family")
		return
	}

	family := h.rowToFamilyResponse(ctx, row.ID, row.Name, row.Description, row.Type)

	if req.ID <= 0 {
		middleware.RespondCreated(w, family)
	} else {
		middleware.RespondOK(w, family)
	}
}

// DeleteFamily handles DELETE /api/v2/taxonomy/families/{id}
func (h *TaxonomyHandler) DeleteFamily(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid family ID")
		return
	}

	// Check if exists
	_, err = h.queries.GetFamilyByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Family not found")
			return
		}
		slog.Error("failed to get family", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete family")
		return
	}

	// Delete species under this family first
	if err := h.queries.DeleteSpeciesForFamily(ctx, id); err != nil {
		slog.Error("failed to delete species for family", "error", err, "id", id)
	}

	// Delete the family (cascades to genera)
	if err := h.queries.DeleteFamily(ctx, id); err != nil {
		slog.Error("failed to delete family", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete family")
		return
	}

	middleware.RespondNoContent(w)
}

// ListGenera handles GET /api/v2/taxonomy/genera
// Supports ?famid=X (by family) or ?q=X (search)
func (h *TaxonomyHandler) ListGenera(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	// Get genera by family ID
	if famIDStr := query.Get("famid"); famIDStr != "" {
		famID, err := strconv.ParseInt(famIDStr, 10, 64)
		if err != nil {
			middleware.RespondBadRequest(w, "Invalid famid parameter")
			return
		}

		rows, err := h.queries.GetGeneraForFamily(ctx, sql.NullInt64{Int64: famID, Valid: true})
		if err != nil {
			slog.Error("failed to get genera for family", "error", err, "familyID", famID)
			middleware.RespondInternalError(w, "Failed to get genera")
			return
		}

		genera := make([]TaxonomyEntry, len(rows))
		for i, row := range rows {
			genera[i] = h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
				row.ParentID, sql.NullString{}, sql.NullString{})
		}

		middleware.RespondOK(w, genera)
		return
	}

	// Search genera
	if q := query.Get("q"); q != "" {
		searchTerm := "%" + q + "%"
		rows, err := h.queries.SearchGenera(ctx, searchTerm)
		if err != nil {
			slog.Error("failed to search genera", "error", err, "query", q)
			middleware.RespondInternalError(w, "Failed to search genera")
			return
		}

		genera := make([]TaxonomyEntry, len(rows))
		for i, row := range rows {
			genera[i] = h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
				row.ParentID, row.ParentName, row.ParentType)
		}

		middleware.RespondOK(w, genera)
		return
	}

	middleware.RespondBadRequest(w, "Must provide either famid or q parameter")
}

// MoveGenera handles POST /api/v2/taxonomy/genera/move
func (h *TaxonomyHandler) MoveGenera(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req GeneraMoveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if len(req.Genera) == 0 {
		middleware.RespondBadRequest(w, "No genera specified")
		return
	}

	if req.OldFamilyID <= 0 || req.NewFamilyID <= 0 {
		middleware.RespondBadRequest(w, "Invalid family IDs")
		return
	}

	// Update parent_id for each genus and update taxonomytaxonomy relationships
	for _, genusID := range req.Genera {
		// Move the genus to new family
		if err := h.queries.MoveGenusToFamily(ctx, db.MoveGenusToFamilyParams{
			ParentID: sql.NullInt64{Int64: req.NewFamilyID, Valid: true},
			ID:       genusID,
		}); err != nil {
			slog.Error("failed to move genus", "error", err, "genusID", genusID)
			middleware.RespondInternalError(w, "Failed to move genera")
			return
		}

		// Delete old taxonomytaxonomy relationship
		if err := h.queries.DeleteTaxonomyTaxonomyByChildID(ctx, db.DeleteTaxonomyTaxonomyByChildIDParams{
			ChildID:    genusID,
			TaxonomyID: req.OldFamilyID,
		}); err != nil {
			slog.Error("failed to delete old taxonomy relationship", "error", err)
		}

		// Create new taxonomytaxonomy relationship
		if err := h.queries.InsertTaxonomyTaxonomy(ctx, db.InsertTaxonomyTaxonomyParams{
			TaxonomyID: req.NewFamilyID,
			ChildID:    genusID,
		}); err != nil {
			slog.Error("failed to create taxonomy relationship", "error", err)
		}
	}

	// Return updated families list
	rows, err := h.queries.ListFamilies(ctx)
	if err != nil {
		slog.Error("failed to list families", "error", err)
		middleware.RespondInternalError(w, "Failed to get families")
		return
	}

	families := make([]FamilyResponse, len(rows))
	for i, row := range rows {
		families[i] = h.rowToFamilyResponse(ctx, row.ID, row.Name, row.Description, row.Type)
	}

	middleware.RespondOK(w, families)
}

// ListSections handles GET /api/v2/taxonomy/sections
// Supports ?q=X (search), ?sectionid=X (by ID), ?name=X (by exact name)
func (h *TaxonomyHandler) ListSections(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	// Get by ID
	if sectionIDStr := query.Get("sectionid"); sectionIDStr != "" {
		id, err := strconv.ParseInt(sectionIDStr, 10, 64)
		if err != nil {
			middleware.RespondBadRequest(w, "Invalid sectionid parameter")
			return
		}

		row, err := h.queries.GetSectionByID(ctx, id)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Section not found")
				return
			}
			slog.Error("failed to get section", "error", err, "id", id)
			middleware.RespondInternalError(w, "Failed to get section")
			return
		}

		section := h.rowToSectionResponse(ctx, row.ID, row.Name, row.Description, row.Type)
		middleware.RespondOK(w, []SectionResponse{section})
		return
	}

	// Get by name (exact match)
	if name := query.Get("name"); name != "" {
		row, err := h.queries.GetSectionByName(ctx, name)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Section not found")
				return
			}
			slog.Error("failed to get section by name", "error", err, "name", name)
			middleware.RespondInternalError(w, "Failed to get section")
			return
		}

		section := h.rowToSectionResponse(ctx, row.ID, row.Name, row.Description, row.Type)
		middleware.RespondOK(w, []SectionResponse{section})
		return
	}

	// Search by query string
	if q := query.Get("q"); q != "" {
		searchTerm := "%" + q + "%"
		rows, err := h.queries.SearchSections(ctx, searchTerm)
		if err != nil {
			slog.Error("failed to search sections", "error", err, "query", q)
			middleware.RespondInternalError(w, "Failed to search sections")
			return
		}

		sections := make([]TaxonomyEntry, len(rows))
		for i, row := range rows {
			sections[i] = h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
				row.ParentID, row.ParentName, row.ParentType)
		}

		middleware.RespondOK(w, sections)
		return
	}

	// List all sections
	rows, err := h.queries.ListSections(ctx)
	if err != nil {
		slog.Error("failed to list sections", "error", err)
		middleware.RespondInternalError(w, "Failed to list sections")
		return
	}

	total, err := h.queries.CountSections(ctx)
	if err != nil {
		slog.Error("failed to count sections", "error", err)
		middleware.RespondInternalError(w, "Failed to count sections")
		return
	}

	sections := make([]TaxonomyEntry, len(rows))
	for i, row := range rows {
		sections[i] = h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
			row.ParentID, row.ParentName, row.ParentType)
	}

	middleware.RespondOK(w, TaxonomyListResponse{
		Data:   sections,
		Total:  total,
		Offset: 0,
	})
}

// GetSectionByID handles GET /api/v2/taxonomy/sections/{id}
func (h *TaxonomyHandler) GetSectionByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid section ID")
		return
	}

	row, err := h.queries.GetSectionByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Section not found")
			return
		}
		slog.Error("failed to get section", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get section")
		return
	}

	section := h.rowToSectionResponse(ctx, row.ID, row.Name, row.Description, row.Type)
	middleware.RespondOK(w, section)
}

// DeleteSection handles DELETE /api/v2/taxonomy/sections/{id}
func (h *TaxonomyHandler) DeleteSection(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid section ID")
		return
	}

	// Check if exists
	_, err = h.queries.GetSectionByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Section not found")
			return
		}
		slog.Error("failed to get section", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete section")
		return
	}

	// Delete the section
	if err := h.queries.DeleteSection(ctx, id); err != nil {
		slog.Error("failed to delete section", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete section")
		return
	}

	middleware.RespondNoContent(w)
}

// Helper methods

func (h *TaxonomyHandler) rowToTaxonomyEntry(id int64, name string, desc sql.NullString, typ string,
	parentID sql.NullInt64, parentName, parentType sql.NullString) TaxonomyEntry {

	entry := TaxonomyEntry{
		ID:          id,
		Name:        name,
		Description: "",
		Type:        typ,
	}

	if desc.Valid {
		entry.Description = desc.String
	}
	if parentID.Valid {
		entry.ParentID = &parentID.Int64
	}
	if parentName.Valid {
		entry.ParentName = &parentName.String
	}
	if parentType.Valid {
		entry.ParentType = &parentType.String
	}

	return entry
}

func (h *TaxonomyHandler) rowToFamilyResponse(ctx context.Context, id int64, name string,
	desc sql.NullString, typ string) FamilyResponse {

	family := FamilyResponse{
		TaxonomyEntry: h.rowToTaxonomyEntry(id, name, desc, typ,
			sql.NullInt64{}, sql.NullString{}, sql.NullString{}),
	}

	// Fetch genera for this family
	genera, err := h.queries.GetGeneraForFamily(ctx, sql.NullInt64{Int64: id, Valid: true})
	if err != nil {
		slog.Error("failed to get genera for family", "error", err, "familyID", id)
		family.Genera = []TaxonomyEntry{}
	} else {
		family.Genera = make([]TaxonomyEntry, len(genera))
		for i, g := range genera {
			family.Genera[i] = h.rowToTaxonomyEntry(g.ID, g.Name, g.Description, g.Type,
				g.ParentID, sql.NullString{}, sql.NullString{})
		}
	}

	return family
}

func (h *TaxonomyHandler) rowToSectionResponse(ctx context.Context, id int64, name string,
	desc sql.NullString, typ string) SectionResponse {

	section := SectionResponse{
		TaxonomyEntry: h.rowToTaxonomyEntry(id, name, desc, typ,
			sql.NullInt64{}, sql.NullString{}, sql.NullString{}),
	}

	// Fetch species for this section
	species, err := h.queries.GetSpeciesForTaxonomy(ctx, id)
	if err != nil {
		slog.Error("failed to get species for section", "error", err, "sectionID", id)
		section.Species = []SimpleSpecies{}
	} else {
		section.Species = make([]SimpleSpecies, len(species))
		for i, s := range species {
			sp := SimpleSpecies{
				ID:           s.ID,
				Name:         s.Name,
				Datacomplete: s.Datacomplete,
			}
			if s.Taxoncode.Valid {
				sp.Taxoncode = &s.Taxoncode.String
			}
			if s.AbundanceID.Valid {
				sp.AbundanceID = &s.AbundanceID.Int64
			}
			section.Species[i] = sp
		}
	}

	// Fetch aliases for this section
	aliases, err := h.queries.GetAliasesForTaxonomy(ctx, id)
	if err != nil {
		slog.Error("failed to get aliases for section", "error", err, "sectionID", id)
		section.Aliases = []Alias{}
	} else {
		section.Aliases = make([]Alias, len(aliases))
		for i, a := range aliases {
			section.Aliases[i] = Alias{
				ID:          a.ID,
				Name:        a.Name,
				Type:        a.Type,
				Description: a.Description,
			}
		}
	}

	return section
}

func (h *TaxonomyHandler) buildFGS(rows []db.GetTaxonomyForSpeciesRow) FGS {
	fgs := FGS{}

	for _, row := range rows {
		entry := h.rowToTaxonomyEntry(row.ID, row.Name, row.Description, row.Type,
			row.ParentID, row.ParentName, row.ParentType)

		switch row.Type {
		case "genus":
			fgs.Genus = entry
			// Family is the parent of genus
			if row.ParentID.Valid && row.ParentName.Valid {
				fgs.Family = TaxonomyEntry{
					ID:          row.ParentID.Int64,
					Name:        row.ParentName.String,
					Description: "",
					Type:        "family",
				}
				if row.ParentType.Valid {
					fgs.Family.Type = row.ParentType.String
				}
			}
		case "section":
			fgs.Section = &entry
		case "family":
			fgs.Family = entry
		}
	}

	return fgs
}
