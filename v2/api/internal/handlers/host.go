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

// HostHandler handles host-related HTTP requests.
type HostHandler struct {
	queries *db.Queries
}

// NewHostHandler creates a new HostHandler.
func NewHostHandler(queries *db.Queries) *HostHandler {
	return &HostHandler{queries: queries}
}

// Place represents a geographic place for API responses.
type Place struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
	Code string `json:"code"`
	Type string `json:"type"`
}

// Gall represents a gall associated with a host for API responses.
type Gall struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
}

// HostResponse represents a host in API responses.
type HostResponse struct {
	ID           int64    `json:"id"`
	Name         string   `json:"name"`
	Datacomplete bool     `json:"datacomplete"`
	AbundanceID  *int64   `json:"abundance_id,omitempty"`
	Abundance    *string  `json:"abundance,omitempty"`
	Aliases      []Alias  `json:"aliases"`
	Places       []Place  `json:"places,omitempty"`
	Galls        []Gall   `json:"galls,omitempty"`
}

// HostSimpleResponse represents a simplified host for API responses.
type HostSimpleResponse struct {
	ID           int64   `json:"id"`
	Name         string  `json:"name"`
	Datacomplete bool    `json:"datacomplete"`
	Aliases      []Alias `json:"aliases"`
	Places       []Place `json:"places"`
}

// HostListResponse represents a paginated list of hosts.
type HostListResponse struct {
	Data   []HostResponse `json:"data"`
	Total  int64          `json:"total"`
	Limit  *int64         `json:"limit,omitempty"`
	Offset int64          `json:"offset"`
}

// HostSimpleListResponse represents a paginated list of simplified hosts.
type HostSimpleListResponse struct {
	Data   []HostSimpleResponse `json:"data"`
	Total  int64                `json:"total"`
	Limit  *int64               `json:"limit,omitempty"`
	Offset int64                `json:"offset"`
}

// HostCreateRequest represents the request body for creating a host.
type HostCreateRequest struct {
	Name         string  `json:"name"`
	Datacomplete bool    `json:"datacomplete"`
	AbundanceID  *int64  `json:"abundance_id,omitempty"`
	Aliases      []Alias `json:"aliases,omitempty"`
	Places       []int64 `json:"places,omitempty"`
}

// HostUpdateRequest represents the request body for updating a host.
type HostUpdateRequest struct {
	Name         string  `json:"name"`
	Datacomplete bool    `json:"datacomplete"`
	AbundanceID  *int64  `json:"abundance_id,omitempty"`
	Aliases      []Alias `json:"aliases,omitempty"`
	Places       []int64 `json:"places,omitempty"`
}

// RegisterRoutes registers host routes on the router.
func (h *HostHandler) RegisterRoutes(r chi.Router) {
	r.Route("/hosts", func(r chi.Router) {
		// Public routes
		r.Get("/", h.List)
		r.Get("/{id}", h.GetByID)

		// Protected routes - require authentication
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.Create)
			r.Put("/{id}", h.Update)
			r.Delete("/{id}", h.Delete)
		})
	})
}

// List handles GET /api/v2/hosts
// Supports search via q query param, simple flag, and pagination via limit/offset.
func (h *HostHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	query := r.URL.Query()

	// Check for simple flag
	simple := query.Get("simple") != ""

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
	var err error

	if searchQuery != "" {
		// Search mode
		total, err = h.queries.CountSearchHosts(ctx, sql.NullString{String: searchQuery, Valid: true})
		if err != nil {
			slog.Error("failed to count search hosts", "error", err)
			middleware.RespondInternalError(w, "Failed to count hosts")
			return
		}

		if simple {
			h.listSimple(w, r, searchQuery, limit, offset, total)
			return
		}

		if limit != nil {
			rows, err := h.queries.SearchHostsPaginated(ctx, db.SearchHostsPaginatedParams{
				Column1: sql.NullString{String: searchQuery, Valid: true},
				Limit:   *limit,
				Offset:  offset,
			})
			if err != nil {
				slog.Error("failed to search hosts paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to search hosts")
				return
			}
			hosts := make([]HostResponse, len(rows))
			for i, row := range rows {
				hosts[i] = h.searchPaginatedRowToHostResponse(ctx, row, false)
			}
			middleware.RespondOK(w, HostListResponse{Data: hosts, Total: total, Limit: limit, Offset: offset})
		} else {
			rows, err := h.queries.SearchHosts(ctx, sql.NullString{String: searchQuery, Valid: true})
			if err != nil {
				slog.Error("failed to search hosts", "error", err)
				middleware.RespondInternalError(w, "Failed to search hosts")
				return
			}
			hosts := make([]HostResponse, len(rows))
			for i, row := range rows {
				hosts[i] = h.searchRowToHostResponse(ctx, row, false)
			}
			middleware.RespondOK(w, HostListResponse{Data: hosts, Total: total, Offset: offset})
		}
	} else {
		// List mode
		total, err = h.queries.CountHosts(ctx)
		if err != nil {
			slog.Error("failed to count hosts", "error", err)
			middleware.RespondInternalError(w, "Failed to count hosts")
			return
		}

		if simple {
			h.listSimple(w, r, "", limit, offset, total)
			return
		}

		if limit != nil {
			rows, err := h.queries.ListHostsPaginated(ctx, db.ListHostsPaginatedParams{
				Limit:  *limit,
				Offset: offset,
			})
			if err != nil {
				slog.Error("failed to list hosts paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to list hosts")
				return
			}
			hosts := make([]HostResponse, len(rows))
			for i, row := range rows {
				hosts[i] = h.listPaginatedRowToHostResponse(ctx, row, false)
			}
			middleware.RespondOK(w, HostListResponse{Data: hosts, Total: total, Limit: limit, Offset: offset})
		} else {
			rows, err := h.queries.ListHosts(ctx)
			if err != nil {
				slog.Error("failed to list hosts", "error", err)
				middleware.RespondInternalError(w, "Failed to list hosts")
				return
			}
			hosts := make([]HostResponse, len(rows))
			for i, row := range rows {
				hosts[i] = h.listRowToHostResponse(ctx, row, false)
			}
			middleware.RespondOK(w, HostListResponse{Data: hosts, Total: total, Offset: offset})
		}
	}
}

// listSimple handles the simple=true flag for listing hosts.
func (h *HostHandler) listSimple(w http.ResponseWriter, r *http.Request, searchQuery string, limit *int64, offset int64, total int64) {
	ctx := r.Context()

	var hosts []HostSimpleResponse

	if searchQuery != "" {
		if limit != nil {
			rows, err := h.queries.SearchHostsPaginated(ctx, db.SearchHostsPaginatedParams{
				Column1: sql.NullString{String: searchQuery, Valid: true},
				Limit:   *limit,
				Offset:  offset,
			})
			if err != nil {
				slog.Error("failed to search hosts simple paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to search hosts")
				return
			}
			hosts = make([]HostSimpleResponse, len(rows))
			for i, row := range rows {
				hosts[i] = h.searchPaginatedRowToSimpleResponse(ctx, row)
			}
		} else {
			rows, err := h.queries.SearchHosts(ctx, sql.NullString{String: searchQuery, Valid: true})
			if err != nil {
				slog.Error("failed to search hosts simple", "error", err)
				middleware.RespondInternalError(w, "Failed to search hosts")
				return
			}
			hosts = make([]HostSimpleResponse, len(rows))
			for i, row := range rows {
				hosts[i] = h.searchRowToSimpleResponse(ctx, row)
			}
		}
	} else {
		if limit != nil {
			rows, err := h.queries.ListHostsPaginated(ctx, db.ListHostsPaginatedParams{
				Limit:  *limit,
				Offset: offset,
			})
			if err != nil {
				slog.Error("failed to list hosts simple paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to list hosts")
				return
			}
			hosts = make([]HostSimpleResponse, len(rows))
			for i, row := range rows {
				hosts[i] = h.listPaginatedRowToSimpleResponse(ctx, row)
			}
		} else {
			rows, err := h.queries.ListHosts(ctx)
			if err != nil {
				slog.Error("failed to list hosts simple", "error", err)
				middleware.RespondInternalError(w, "Failed to list hosts")
				return
			}
			hosts = make([]HostSimpleResponse, len(rows))
			for i, row := range rows {
				hosts[i] = h.listRowToSimpleResponse(ctx, row)
			}
		}
	}

	middleware.RespondOK(w, HostSimpleListResponse{
		Data:   hosts,
		Total:  total,
		Limit:  limit,
		Offset: offset,
	})
}

// GetByID handles GET /api/v2/hosts/{id}
func (h *HostHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid host ID")
		return
	}

	row, err := h.queries.GetHostByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Host not found")
			return
		}
		slog.Error("failed to get host", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get host")
		return
	}

	host := h.getByIDRowToHostResponse(ctx, row, true)

	middleware.RespondOK(w, host)
}

// Create handles POST /api/v2/hosts
func (h *HostHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req HostCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Name == "" {
		middleware.RespondBadRequest(w, "Name is required")
		return
	}

	// Create the species record
	var abundanceID sql.NullInt64
	if req.AbundanceID != nil {
		abundanceID = sql.NullInt64{Int64: *req.AbundanceID, Valid: true}
	}

	speciesID, err := h.queries.CreateHostSpecies(ctx, db.CreateHostSpeciesParams{
		Name:         req.Name,
		Datacomplete: req.Datacomplete,
		AbundanceID:  abundanceID,
	})
	if err != nil {
		slog.Error("failed to create host species", "error", err)
		middleware.RespondInternalError(w, "Failed to create host")
		return
	}

	// Create aliases
	aliases := make([]Alias, 0, len(req.Aliases))
	for _, alias := range req.Aliases {
		aliasID, err := h.queries.CreateAlias(ctx, db.CreateAliasParams{
			Name:        alias.Name,
			Type:        alias.Type,
			Description: alias.Description,
		})
		if err != nil {
			slog.Error("failed to create alias", "error", err)
			continue
		}
		if err := h.queries.CreateAliasSpecies(ctx, db.CreateAliasSpeciesParams{
			SpeciesID: speciesID,
			AliasID:   aliasID,
		}); err != nil {
			slog.Error("failed to link alias to species", "error", err)
			continue
		}
		aliases = append(aliases, Alias{
			ID:          aliasID,
			Name:        alias.Name,
			Type:        alias.Type,
			Description: alias.Description,
		})
	}

	// Create place associations
	for _, placeID := range req.Places {
		if err := h.queries.InsertHostPlace(ctx, db.InsertHostPlaceParams{
			SpeciesID: sql.NullInt64{Int64: speciesID, Valid: true},
			PlaceID:   sql.NullInt64{Int64: placeID, Valid: true},
		}); err != nil {
			slog.Error("failed to create place association", "error", err, "placeID", placeID)
		}
	}

	response := HostResponse{
		ID:           speciesID,
		Name:         req.Name,
		Datacomplete: req.Datacomplete,
		AbundanceID:  req.AbundanceID,
		Aliases:      aliases,
	}

	middleware.RespondCreated(w, response)
}

// Update handles PUT /api/v2/hosts/{id}
func (h *HostHandler) Update(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	speciesID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid host ID")
		return
	}

	// Check if host exists
	_, err = h.queries.GetHostByID(ctx, speciesID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Host not found")
			return
		}
		slog.Error("failed to get host", "error", err, "id", speciesID)
		middleware.RespondInternalError(w, "Failed to get host")
		return
	}

	var req HostUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Name == "" {
		middleware.RespondBadRequest(w, "Name is required")
		return
	}

	// Update species
	var abundanceID sql.NullInt64
	if req.AbundanceID != nil {
		abundanceID = sql.NullInt64{Int64: *req.AbundanceID, Valid: true}
	}

	if err := h.queries.UpdateHostSpecies(ctx, db.UpdateHostSpeciesParams{
		Name:         req.Name,
		Datacomplete: req.Datacomplete,
		AbundanceID:  abundanceID,
		ID:           speciesID,
	}); err != nil {
		slog.Error("failed to update host species", "error", err)
		middleware.RespondInternalError(w, "Failed to update host")
		return
	}

	// Update aliases - delete existing and recreate
	h.queries.DeleteAliasSpeciesBySpeciesID(ctx, speciesID)
	h.queries.DeleteAliasBySpeciesID(ctx, speciesID)

	aliases := make([]Alias, 0, len(req.Aliases))
	for _, alias := range req.Aliases {
		aliasID, err := h.queries.CreateAlias(ctx, db.CreateAliasParams{
			Name:        alias.Name,
			Type:        alias.Type,
			Description: alias.Description,
		})
		if err != nil {
			slog.Error("failed to create alias", "error", err)
			continue
		}
		if err := h.queries.CreateAliasSpecies(ctx, db.CreateAliasSpeciesParams{
			SpeciesID: speciesID,
			AliasID:   aliasID,
		}); err != nil {
			slog.Error("failed to link alias to species", "error", err)
			continue
		}
		aliases = append(aliases, Alias{
			ID:          aliasID,
			Name:        alias.Name,
			Type:        alias.Type,
			Description: alias.Description,
		})
	}

	// Update places - delete existing and recreate
	h.queries.DeleteHostPlaces(ctx, sql.NullInt64{Int64: speciesID, Valid: true})
	for _, placeID := range req.Places {
		if err := h.queries.InsertHostPlace(ctx, db.InsertHostPlaceParams{
			SpeciesID: sql.NullInt64{Int64: speciesID, Valid: true},
			PlaceID:   sql.NullInt64{Int64: placeID, Valid: true},
		}); err != nil {
			slog.Error("failed to create place association", "error", err, "placeID", placeID)
		}
	}

	response := HostResponse{
		ID:           speciesID,
		Name:         req.Name,
		Datacomplete: req.Datacomplete,
		AbundanceID:  req.AbundanceID,
		Aliases:      aliases,
	}

	middleware.RespondOK(w, response)
}

// Delete handles DELETE /api/v2/hosts/{id}
func (h *HostHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	speciesID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid host ID")
		return
	}

	// Check if host exists
	_, err = h.queries.GetHostByID(ctx, speciesID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Host not found")
			return
		}
		slog.Error("failed to get host", "error", err, "id", speciesID)
		middleware.RespondInternalError(w, "Failed to delete host")
		return
	}

	// Delete in order to respect foreign key constraints
	// Delete gall associations
	h.queries.DeleteHostGallAssociations(ctx, sql.NullInt64{Int64: speciesID, Valid: true})

	// Delete places
	h.queries.DeleteHostPlaces(ctx, sql.NullInt64{Int64: speciesID, Valid: true})

	// Delete aliases
	h.queries.DeleteAliasSpeciesBySpeciesID(ctx, speciesID)
	h.queries.DeleteAliasBySpeciesID(ctx, speciesID)

	// Delete the species
	if err := h.queries.DeleteHostByID(ctx, speciesID); err != nil {
		slog.Error("failed to delete host", "error", err, "id", speciesID)
		middleware.RespondInternalError(w, "Failed to delete host")
		return
	}

	middleware.RespondNoContent(w)
}

// Helper methods

func (h *HostHandler) listRowToHostResponse(ctx context.Context, row db.ListHostsRow, includeDetails bool) HostResponse {
	response := HostResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
	}

	if row.AbundanceID.Valid {
		response.AbundanceID = &row.AbundanceID.Int64
	}
	if row.AbundanceName.Valid {
		response.Abundance = &row.AbundanceName.String
	}

	// Always fetch aliases
	response.Aliases = h.getAliases(ctx, row.ID)

	// Fetch detailed data for single-item requests
	if includeDetails {
		response.Places = h.getPlaces(ctx, row.ID)
		response.Galls = h.getGalls(ctx, row.ID)
	}

	return response
}

func (h *HostHandler) listRowToSimpleResponse(ctx context.Context, row db.ListHostsRow) HostSimpleResponse {
	return HostSimpleResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
		Aliases:      h.getAliases(ctx, row.ID),
		Places:       h.getPlaces(ctx, row.ID),
	}
}

func (h *HostHandler) searchRowToHostResponse(ctx context.Context, row db.SearchHostsRow, includeDetails bool) HostResponse {
	response := HostResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
	}

	if row.AbundanceID.Valid {
		response.AbundanceID = &row.AbundanceID.Int64
	}
	if row.AbundanceName.Valid {
		response.Abundance = &row.AbundanceName.String
	}

	// Always fetch aliases
	response.Aliases = h.getAliases(ctx, row.ID)

	// Fetch detailed data for single-item requests
	if includeDetails {
		response.Places = h.getPlaces(ctx, row.ID)
		response.Galls = h.getGalls(ctx, row.ID)
	}

	return response
}

func (h *HostHandler) searchRowToSimpleResponse(ctx context.Context, row db.SearchHostsRow) HostSimpleResponse {
	return HostSimpleResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
		Aliases:      h.getAliases(ctx, row.ID),
		Places:       h.getPlaces(ctx, row.ID),
	}
}

func (h *HostHandler) getByIDRowToHostResponse(ctx context.Context, row db.GetHostByIDRow, includeDetails bool) HostResponse {
	response := HostResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
	}

	if row.AbundanceID.Valid {
		response.AbundanceID = &row.AbundanceID.Int64
	}
	if row.AbundanceName.Valid {
		response.Abundance = &row.AbundanceName.String
	}

	// Always fetch aliases
	response.Aliases = h.getAliases(ctx, row.ID)

	// Fetch detailed data for single-item requests
	if includeDetails {
		response.Places = h.getPlaces(ctx, row.ID)
		response.Galls = h.getGalls(ctx, row.ID)
	}

	return response
}

func (h *HostHandler) getAliases(ctx context.Context, speciesID int64) []Alias {
	aliases, err := h.queries.GetAliasesBySpeciesID(ctx, speciesID)
	if err != nil {
		slog.Error("failed to get aliases", "error", err, "speciesID", speciesID)
		return []Alias{}
	}
	result := make([]Alias, len(aliases))
	for i, a := range aliases {
		result[i] = Alias{
			ID:          a.ID,
			Name:        a.Name,
			Type:        a.Type,
			Description: a.Description,
		}
	}
	return result
}

func (h *HostHandler) getPlaces(ctx context.Context, speciesID int64) []Place {
	places, err := h.queries.GetHostPlaces(ctx, sql.NullInt64{Int64: speciesID, Valid: true})
	if err != nil {
		slog.Error("failed to get places", "error", err, "speciesID", speciesID)
		return []Place{}
	}
	result := make([]Place, len(places))
	for i, p := range places {
		result[i] = Place{
			ID:   p.ID,
			Name: p.Name,
			Code: p.Code,
			Type: p.Type,
		}
	}
	return result
}

func (h *HostHandler) getGalls(ctx context.Context, speciesID int64) []Gall {
	galls, err := h.queries.GetHostGalls(ctx, sql.NullInt64{Int64: speciesID, Valid: true})
	if err != nil {
		slog.Error("failed to get galls", "error", err, "speciesID", speciesID)
		return []Gall{}
	}
	result := make([]Gall, len(galls))
	for i, g := range galls {
		result[i] = Gall{
			ID:   g.GallSpeciesID,
			Name: g.GallName,
		}
	}
	return result
}

// Paginated row converters

func (h *HostHandler) listPaginatedRowToHostResponse(ctx context.Context, row db.ListHostsPaginatedRow, includeDetails bool) HostResponse {
	response := HostResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
	}

	if row.AbundanceID.Valid {
		response.AbundanceID = &row.AbundanceID.Int64
	}
	if row.AbundanceName.Valid {
		response.Abundance = &row.AbundanceName.String
	}

	response.Aliases = h.getAliases(ctx, row.ID)

	if includeDetails {
		response.Places = h.getPlaces(ctx, row.ID)
		response.Galls = h.getGalls(ctx, row.ID)
	}

	return response
}

func (h *HostHandler) listPaginatedRowToSimpleResponse(ctx context.Context, row db.ListHostsPaginatedRow) HostSimpleResponse {
	return HostSimpleResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
		Aliases:      h.getAliases(ctx, row.ID),
		Places:       h.getPlaces(ctx, row.ID),
	}
}

func (h *HostHandler) searchPaginatedRowToHostResponse(ctx context.Context, row db.SearchHostsPaginatedRow, includeDetails bool) HostResponse {
	response := HostResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
	}

	if row.AbundanceID.Valid {
		response.AbundanceID = &row.AbundanceID.Int64
	}
	if row.AbundanceName.Valid {
		response.Abundance = &row.AbundanceName.String
	}

	response.Aliases = h.getAliases(ctx, row.ID)

	if includeDetails {
		response.Places = h.getPlaces(ctx, row.ID)
		response.Galls = h.getGalls(ctx, row.ID)
	}

	return response
}

func (h *HostHandler) searchPaginatedRowToSimpleResponse(ctx context.Context, row db.SearchHostsPaginatedRow) HostSimpleResponse {
	return HostSimpleResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
		Aliases:      h.getAliases(ctx, row.ID),
		Places:       h.getPlaces(ctx, row.ID),
	}
}
