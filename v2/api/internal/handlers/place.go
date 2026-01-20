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

// PlaceHandler handles place-related HTTP requests.
type PlaceHandler struct {
	queries *db.Queries
}

// NewPlaceHandler creates a new PlaceHandler.
func NewPlaceHandler(queries *db.Queries) *PlaceHandler {
	return &PlaceHandler{queries: queries}
}

// PlaceResponse represents a place in API responses.
type PlaceResponse struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
	Code string `json:"code"`
	Type string `json:"type"`
}

// PlaceHost represents minimal host info for place detail page.
type PlaceHost struct {
	ID           int64  `json:"id"`
	Name         string `json:"name"`
	Datacomplete bool   `json:"datacomplete"`
}

// PlaceDetailResponse represents a place with parent and hosts.
type PlaceDetailResponse struct {
	PlaceResponse
	Parent *PlaceResponse `json:"parent,omitempty"`
	Hosts  []PlaceHost    `json:"hosts"`
}

// PlaceListResponse represents a paginated list of places.
type PlaceListResponse struct {
	Data   []PlaceResponse `json:"data"`
	Total  int64           `json:"total"`
	Limit  *int64          `json:"limit,omitempty"`
	Offset int64           `json:"offset"`
}

// PlaceCreateRequest represents the request body for creating a place.
type PlaceCreateRequest struct {
	Name string `json:"name"`
	Code string `json:"code"`
	Type string `json:"type"`
}

// PlaceUpdateRequest represents the request body for updating a place.
type PlaceUpdateRequest struct {
	Name string `json:"name"`
	Code string `json:"code"`
	Type string `json:"type"`
}

// Valid place types
var validPlaceTypes = map[string]bool{
	"continent": true,
	"country":   true,
	"region":    true,
	"state":     true,
	"province":  true,
	"county":    true,
	"city":      true,
}

// RegisterRoutes registers place routes on the router.
func (h *PlaceHandler) RegisterRoutes(r chi.Router) {
	r.Route("/places", func(r chi.Router) {
		// Public routes
		r.Get("/", h.List)
		r.Get("/{id}", h.GetByID)
		r.Get("/by-name/{name}", h.GetByName)

		// Protected routes - require authentication
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.Create)
			r.Put("/{id}", h.Update)
			r.Delete("/{id}", h.Delete)
		})
	})
}

// List handles GET /api/v2/places
// Supports search via q query param and pagination via limit/offset.
func (h *PlaceHandler) List(w http.ResponseWriter, r *http.Request) {
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
	var places []PlaceResponse
	var err error

	if searchQuery != "" {
		// Search mode
		total, err = h.queries.CountSearchPlaces(ctx, sql.NullString{String: searchQuery, Valid: true})
		if err != nil {
			slog.Error("failed to count search places", "error", err)
			middleware.RespondInternalError(w, "Failed to count places")
			return
		}

		if limit != nil {
			rows, err := h.queries.SearchPlacesPaginated(ctx, db.SearchPlacesPaginatedParams{
				Column1: sql.NullString{String: searchQuery, Valid: true},
				Limit:   *limit,
				Offset:  offset,
			})
			if err != nil {
				slog.Error("failed to search places paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to search places")
				return
			}
			places = make([]PlaceResponse, len(rows))
			for i, row := range rows {
				places[i] = placeToResponse(row)
			}
		} else {
			rows, err := h.queries.SearchPlaces(ctx, sql.NullString{String: searchQuery, Valid: true})
			if err != nil {
				slog.Error("failed to search places", "error", err)
				middleware.RespondInternalError(w, "Failed to search places")
				return
			}
			places = make([]PlaceResponse, len(rows))
			for i, row := range rows {
				places[i] = placeToResponse(row)
			}
		}
	} else {
		// List mode
		total, err = h.queries.CountPlaces(ctx)
		if err != nil {
			slog.Error("failed to count places", "error", err)
			middleware.RespondInternalError(w, "Failed to count places")
			return
		}

		if limit != nil {
			rows, err := h.queries.ListPlacesPaginated(ctx, db.ListPlacesPaginatedParams{
				Limit:  *limit,
				Offset: offset,
			})
			if err != nil {
				slog.Error("failed to list places paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to list places")
				return
			}
			places = make([]PlaceResponse, len(rows))
			for i, row := range rows {
				places[i] = placeToResponse(row)
			}
		} else {
			rows, err := h.queries.ListPlaces(ctx)
			if err != nil {
				slog.Error("failed to list places", "error", err)
				middleware.RespondInternalError(w, "Failed to list places")
				return
			}
			places = make([]PlaceResponse, len(rows))
			for i, row := range rows {
				places[i] = placeToResponse(row)
			}
		}
	}

	response := PlaceListResponse{
		Data:   places,
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}

	middleware.RespondOK(w, response)
}

// GetByID handles GET /api/v2/places/{id}
func (h *PlaceHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid place ID")
		return
	}

	row, err := h.queries.GetPlaceByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Place not found")
			return
		}
		slog.Error("failed to get place", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get place")
		return
	}

	// Fetch parent place
	var parent *PlaceResponse
	parentRow, err := h.queries.GetParentPlace(ctx, sql.NullInt64{Int64: id, Valid: true})
	if err == nil {
		p := placeToResponse(parentRow)
		parent = &p
	}

	// Fetch hosts
	hostRows, err := h.queries.GetHostsByPlaceID(ctx, sql.NullInt64{Int64: id, Valid: true})
	var hosts []PlaceHost
	if err != nil {
		slog.Error("failed to get hosts for place", "error", err, "placeID", id)
		hosts = []PlaceHost{}
	} else {
		hosts = make([]PlaceHost, len(hostRows))
		for i, h := range hostRows {
			hosts[i] = PlaceHost{
				ID:           h.ID,
				Name:         h.Name,
				Datacomplete: h.Datacomplete,
			}
		}
	}

	response := PlaceDetailResponse{
		PlaceResponse: placeToResponse(row),
		Parent:        parent,
		Hosts:         hosts,
	}

	middleware.RespondOK(w, response)
}

// GetByName handles GET /api/v2/places/by-name/{name}
func (h *PlaceHandler) GetByName(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	name := chi.URLParam(r, "name")
	if name == "" {
		middleware.RespondBadRequest(w, "Name is required")
		return
	}

	row, err := h.queries.GetPlaceByName(ctx, name)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Place not found")
			return
		}
		slog.Error("failed to get place by name", "error", err, "name", name)
		middleware.RespondInternalError(w, "Failed to get place")
		return
	}

	middleware.RespondOK(w, placeToResponse(row))
}

// Create handles POST /api/v2/places
func (h *PlaceHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req PlaceCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Name == "" {
		middleware.RespondBadRequest(w, "Name is required")
		return
	}

	if req.Code == "" {
		middleware.RespondBadRequest(w, "Code is required")
		return
	}

	if req.Type == "" {
		middleware.RespondBadRequest(w, "Type is required")
		return
	}

	if !validPlaceTypes[req.Type] {
		middleware.RespondBadRequest(w, "Invalid type. Must be one of: continent, country, region, state, province, county, city")
		return
	}

	id, err := h.queries.CreatePlace(ctx, db.CreatePlaceParams{
		Name: req.Name,
		Code: req.Code,
		Type: req.Type,
	})
	if err != nil {
		slog.Error("failed to create place", "error", err)
		middleware.RespondInternalError(w, "Failed to create place")
		return
	}

	response := PlaceResponse{
		ID:   id,
		Name: req.Name,
		Code: req.Code,
		Type: req.Type,
	}

	middleware.RespondCreated(w, response)
}

// Update handles PUT /api/v2/places/{id}
func (h *PlaceHandler) Update(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid place ID")
		return
	}

	// Check if place exists
	_, err = h.queries.GetPlaceByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Place not found")
			return
		}
		slog.Error("failed to get place", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get place")
		return
	}

	var req PlaceUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Name == "" {
		middleware.RespondBadRequest(w, "Name is required")
		return
	}

	if req.Code == "" {
		middleware.RespondBadRequest(w, "Code is required")
		return
	}

	if req.Type == "" {
		middleware.RespondBadRequest(w, "Type is required")
		return
	}

	if !validPlaceTypes[req.Type] {
		middleware.RespondBadRequest(w, "Invalid type. Must be one of: continent, country, region, state, province, county, city")
		return
	}

	if err := h.queries.UpdatePlace(ctx, db.UpdatePlaceParams{
		Name: req.Name,
		Code: req.Code,
		Type: req.Type,
		ID:   id,
	}); err != nil {
		slog.Error("failed to update place", "error", err)
		middleware.RespondInternalError(w, "Failed to update place")
		return
	}

	response := PlaceResponse{
		ID:   id,
		Name: req.Name,
		Code: req.Code,
		Type: req.Type,
	}

	middleware.RespondOK(w, response)
}

// Delete handles DELETE /api/v2/places/{id}
func (h *PlaceHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid place ID")
		return
	}

	// Check if place exists
	_, err = h.queries.GetPlaceByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Place not found")
			return
		}
		slog.Error("failed to get place", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete place")
		return
	}

	if err := h.queries.DeletePlace(ctx, id); err != nil {
		slog.Error("failed to delete place", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to delete place")
		return
	}

	middleware.RespondNoContent(w)
}

// Helper function to convert db.Place to PlaceResponse
func placeToResponse(p db.Place) PlaceResponse {
	return PlaceResponse{
		ID:   p.ID,
		Name: p.Name,
		Code: p.Code,
		Type: p.Type,
	}
}
