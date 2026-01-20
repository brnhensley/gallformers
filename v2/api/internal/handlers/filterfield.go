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

// FilterFieldHandler handles filter field-related HTTP requests.
type FilterFieldHandler struct {
	queries *db.Queries
}

// NewFilterFieldHandler creates a new FilterFieldHandler.
func NewFilterFieldHandler(queries *db.Queries) *FilterFieldHandler {
	return &FilterFieldHandler{queries: queries}
}

// FilterFieldType represents the type of filter field.
type FilterFieldType string

const (
	FilterFieldColor     FilterFieldType = "color"
	FilterFieldShape     FilterFieldType = "shape"
	FilterFieldLocation  FilterFieldType = "location"
	FilterFieldTexture   FilterFieldType = "texture"
	FilterFieldWalls     FilterFieldType = "walls"
	FilterFieldCells     FilterFieldType = "cells"
	FilterFieldAlignment FilterFieldType = "alignment"
	FilterFieldSeason    FilterFieldType = "season"
	FilterFieldForm      FilterFieldType = "form"
	FilterFieldAbundance FilterFieldType = "abundance"
)

// ValidFilterFieldTypes lists all valid filter field types.
var ValidFilterFieldTypes = []FilterFieldType{
	FilterFieldColor,
	FilterFieldShape,
	FilterFieldLocation,
	FilterFieldTexture,
	FilterFieldWalls,
	FilterFieldCells,
	FilterFieldAlignment,
	FilterFieldSeason,
	FilterFieldForm,
	FilterFieldAbundance,
}

// FilterFieldResponse represents a filter field value in API responses.
type FilterFieldResponse struct {
	ID          int64   `json:"id"`
	Field       string  `json:"field"`
	Description *string `json:"description,omitempty"`
	Reference   *string `json:"reference,omitempty"` // Only for abundance
}

// FilterFieldTypeInfo represents info about a filter field type.
type FilterFieldTypeInfo struct {
	Type           string `json:"type"`
	HasDescription bool   `json:"hasDescription"`
	HasReference   bool   `json:"hasReference"`
}

// FilterFieldCreateRequest represents the request body for creating a filter field.
type FilterFieldCreateRequest struct {
	Type        string  `json:"type"`
	Field       string  `json:"field"`
	Description *string `json:"description,omitempty"`
	Reference   *string `json:"reference,omitempty"` // Only for abundance
}

// FilterFieldUpdateRequest represents the request body for updating a filter field.
type FilterFieldUpdateRequest struct {
	Field       string  `json:"field"`
	Description *string `json:"description,omitempty"`
	Reference   *string `json:"reference,omitempty"` // Only for abundance
}

// RegisterRoutes registers filter field routes on the router.
func (h *FilterFieldHandler) RegisterRoutes(r chi.Router) {
	r.Route("/filter-fields", func(r chi.Router) {
		// Public routes
		r.Get("/", h.ListTypes)
		r.Get("/{type}", h.ListByType)
		r.Get("/{type}/{id}", h.GetByID)

		// Protected routes - require authentication
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.Create)
			r.Put("/{type}/{id}", h.Update)
			r.Delete("/{type}/{id}", h.Delete)
		})
	})
}

// ListTypes handles GET /api/v2/filter-fields
// Returns a list of available filter field types.
func (h *FilterFieldHandler) ListTypes(w http.ResponseWriter, r *http.Request) {
	types := []FilterFieldTypeInfo{
		{Type: string(FilterFieldColor), HasDescription: false, HasReference: false},
		{Type: string(FilterFieldShape), HasDescription: true, HasReference: false},
		{Type: string(FilterFieldLocation), HasDescription: true, HasReference: false},
		{Type: string(FilterFieldTexture), HasDescription: true, HasReference: false},
		{Type: string(FilterFieldWalls), HasDescription: true, HasReference: false},
		{Type: string(FilterFieldCells), HasDescription: true, HasReference: false},
		{Type: string(FilterFieldAlignment), HasDescription: true, HasReference: false},
		{Type: string(FilterFieldSeason), HasDescription: false, HasReference: false},
		{Type: string(FilterFieldForm), HasDescription: true, HasReference: false},
		{Type: string(FilterFieldAbundance), HasDescription: true, HasReference: true},
	}
	middleware.RespondOK(w, types)
}

// ListByType handles GET /api/v2/filter-fields/{type}
// Returns all values for the specified filter field type.
func (h *FilterFieldHandler) ListByType(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	fieldType := FilterFieldType(chi.URLParam(r, "type"))

	if !isValidFilterFieldType(fieldType) {
		middleware.RespondBadRequest(w, "Invalid filter field type")
		return
	}

	var responses []FilterFieldResponse
	var err error

	switch fieldType {
	case FilterFieldColor:
		rows, e := h.queries.ListColors(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{ID: row.ID, Field: row.Color}
		}
	case FilterFieldShape:
		rows, e := h.queries.ListShapes(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Shape,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldLocation:
		rows, e := h.queries.ListLocations(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Location,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldTexture:
		rows, e := h.queries.ListTextures(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Texture,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldWalls:
		rows, e := h.queries.ListWalls(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Walls,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldCells:
		rows, e := h.queries.ListCells(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Cells,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldAlignment:
		rows, e := h.queries.ListAlignments(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Alignment,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldSeason:
		rows, e := h.queries.ListSeasons(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{ID: row.ID, Field: row.Season}
		}
	case FilterFieldForm:
		rows, e := h.queries.ListForms(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Form,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldAbundance:
		rows, e := h.queries.ListAbundanceValues(ctx)
		err = e
		responses = make([]FilterFieldResponse, len(rows))
		for i, row := range rows {
			responses[i] = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Abundance,
				Description: nullStringToPtr(row.Description),
				Reference:   nullStringToPtr(row.Reference),
			}
		}
	}

	if err != nil {
		slog.Error("failed to list filter fields", "type", fieldType, "error", err)
		middleware.RespondInternalError(w, "Failed to list filter fields")
		return
	}

	middleware.RespondOK(w, responses)
}

// GetByID handles GET /api/v2/filter-fields/{type}/{id}
// Returns a single filter field value by type and ID.
func (h *FilterFieldHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	fieldType := FilterFieldType(chi.URLParam(r, "type"))

	if !isValidFilterFieldType(fieldType) {
		middleware.RespondBadRequest(w, "Invalid filter field type")
		return
	}

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid filter field ID")
		return
	}

	var response FilterFieldResponse
	var queryErr error

	switch fieldType {
	case FilterFieldColor:
		row, e := h.queries.GetColorByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{ID: row.ID, Field: row.Color}
		}
	case FilterFieldShape:
		row, e := h.queries.GetShapeByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Shape,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldLocation:
		row, e := h.queries.GetLocationByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Location,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldTexture:
		row, e := h.queries.GetTextureByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Texture,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldWalls:
		row, e := h.queries.GetWallsByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Walls,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldCells:
		row, e := h.queries.GetCellsByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Cells,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldAlignment:
		row, e := h.queries.GetAlignmentByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Alignment,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldSeason:
		row, e := h.queries.GetSeasonByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{ID: row.ID, Field: row.Season}
		}
	case FilterFieldForm:
		row, e := h.queries.GetFormByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Form,
				Description: nullStringToPtr(row.Description),
			}
		}
	case FilterFieldAbundance:
		row, e := h.queries.GetAbundanceValueByID(ctx, id)
		queryErr = e
		if e == nil {
			response = FilterFieldResponse{
				ID:          row.ID,
				Field:       row.Abundance,
				Description: nullStringToPtr(row.Description),
				Reference:   nullStringToPtr(row.Reference),
			}
		}
	}

	if queryErr != nil {
		if errors.Is(queryErr, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Filter field not found")
			return
		}
		slog.Error("failed to get filter field", "type", fieldType, "id", id, "error", queryErr)
		middleware.RespondInternalError(w, "Failed to get filter field")
		return
	}

	middleware.RespondOK(w, response)
}

// Create handles POST /api/v2/filter-fields
// Creates a new filter field value.
func (h *FilterFieldHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req FilterFieldCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	fieldType := FilterFieldType(req.Type)
	if !isValidFilterFieldType(fieldType) {
		middleware.RespondBadRequest(w, "Invalid filter field type")
		return
	}

	if req.Field == "" {
		middleware.RespondBadRequest(w, "Field value is required")
		return
	}

	var id int64
	var err error

	switch fieldType {
	case FilterFieldColor:
		id, err = h.queries.CreateColor(ctx, req.Field)
	case FilterFieldShape:
		id, err = h.queries.CreateShape(ctx, db.CreateShapeParams{
			Shape:       req.Field,
			Description: ptrToNullString(req.Description),
		})
	case FilterFieldLocation:
		id, err = h.queries.CreateLocation(ctx, db.CreateLocationParams{
			Location:    req.Field,
			Description: ptrToNullString(req.Description),
		})
	case FilterFieldTexture:
		id, err = h.queries.CreateTexture(ctx, db.CreateTextureParams{
			Texture:     req.Field,
			Description: ptrToNullString(req.Description),
		})
	case FilterFieldWalls:
		id, err = h.queries.CreateWalls(ctx, db.CreateWallsParams{
			Walls:       req.Field,
			Description: ptrToNullString(req.Description),
		})
	case FilterFieldCells:
		id, err = h.queries.CreateCells(ctx, db.CreateCellsParams{
			Cells:       req.Field,
			Description: ptrToNullString(req.Description),
		})
	case FilterFieldAlignment:
		id, err = h.queries.CreateAlignment(ctx, db.CreateAlignmentParams{
			Alignment:   req.Field,
			Description: ptrToNullString(req.Description),
		})
	case FilterFieldSeason:
		id, err = h.queries.CreateSeason(ctx, req.Field)
	case FilterFieldForm:
		id, err = h.queries.CreateForm(ctx, db.CreateFormParams{
			Form:        req.Field,
			Description: ptrToNullString(req.Description),
		})
	case FilterFieldAbundance:
		id, err = h.queries.CreateAbundanceValue(ctx, db.CreateAbundanceValueParams{
			Abundance:   req.Field,
			Description: ptrToNullString(req.Description),
			Reference:   ptrToNullString(req.Reference),
		})
	}

	if err != nil {
		slog.Error("failed to create filter field", "type", fieldType, "error", err)
		middleware.RespondInternalError(w, "Failed to create filter field")
		return
	}

	response := FilterFieldResponse{
		ID:          id,
		Field:       req.Field,
		Description: req.Description,
		Reference:   req.Reference,
	}

	middleware.RespondCreated(w, response)
}

// Update handles PUT /api/v2/filter-fields/{type}/{id}
// Updates an existing filter field value.
func (h *FilterFieldHandler) Update(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	fieldType := FilterFieldType(chi.URLParam(r, "type"))

	if !isValidFilterFieldType(fieldType) {
		middleware.RespondBadRequest(w, "Invalid filter field type")
		return
	}

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid filter field ID")
		return
	}

	var req FilterFieldUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.RespondBadRequest(w, "Invalid request body")
		return
	}

	if req.Field == "" {
		middleware.RespondBadRequest(w, "Field value is required")
		return
	}

	// Check if exists and update
	var updateErr error

	switch fieldType {
	case FilterFieldColor:
		_, e := h.queries.GetColorByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateColor(ctx, db.UpdateColorParams{Color: req.Field, ID: id})
	case FilterFieldShape:
		_, e := h.queries.GetShapeByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateShape(ctx, db.UpdateShapeParams{
			Shape:       req.Field,
			Description: ptrToNullString(req.Description),
			ID:          id,
		})
	case FilterFieldLocation:
		_, e := h.queries.GetLocationByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateLocation(ctx, db.UpdateLocationParams{
			Location:    req.Field,
			Description: ptrToNullString(req.Description),
			ID:          id,
		})
	case FilterFieldTexture:
		_, e := h.queries.GetTextureByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateTexture(ctx, db.UpdateTextureParams{
			Texture:     req.Field,
			Description: ptrToNullString(req.Description),
			ID:          id,
		})
	case FilterFieldWalls:
		_, e := h.queries.GetWallsByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateWalls(ctx, db.UpdateWallsParams{
			Walls:       req.Field,
			Description: ptrToNullString(req.Description),
			ID:          id,
		})
	case FilterFieldCells:
		_, e := h.queries.GetCellsByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateCells(ctx, db.UpdateCellsParams{
			Cells:       req.Field,
			Description: ptrToNullString(req.Description),
			ID:          id,
		})
	case FilterFieldAlignment:
		_, e := h.queries.GetAlignmentByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateAlignment(ctx, db.UpdateAlignmentParams{
			Alignment:   req.Field,
			Description: ptrToNullString(req.Description),
			ID:          id,
		})
	case FilterFieldSeason:
		_, e := h.queries.GetSeasonByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateSeason(ctx, db.UpdateSeasonParams{Season: req.Field, ID: id})
	case FilterFieldForm:
		_, e := h.queries.GetFormByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateForm(ctx, db.UpdateFormParams{
			Form:        req.Field,
			Description: ptrToNullString(req.Description),
			ID:          id,
		})
	case FilterFieldAbundance:
		_, e := h.queries.GetAbundanceValueByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		updateErr = h.queries.UpdateAbundanceValue(ctx, db.UpdateAbundanceValueParams{
			Abundance:   req.Field,
			Description: ptrToNullString(req.Description),
			Reference:   ptrToNullString(req.Reference),
			ID:          id,
		})
	}

	if updateErr != nil {
		slog.Error("failed to update filter field", "type", fieldType, "id", id, "error", updateErr)
		middleware.RespondInternalError(w, "Failed to update filter field")
		return
	}

	response := FilterFieldResponse{
		ID:          id,
		Field:       req.Field,
		Description: req.Description,
		Reference:   req.Reference,
	}

	middleware.RespondOK(w, response)
}

// Delete handles DELETE /api/v2/filter-fields/{type}/{id}
// Deletes a filter field value.
func (h *FilterFieldHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	fieldType := FilterFieldType(chi.URLParam(r, "type"))

	if !isValidFilterFieldType(fieldType) {
		middleware.RespondBadRequest(w, "Invalid filter field type")
		return
	}

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid filter field ID")
		return
	}

	// Check if exists and delete
	var deleteErr error

	switch fieldType {
	case FilterFieldColor:
		_, e := h.queries.GetColorByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteColor(ctx, id)
	case FilterFieldShape:
		_, e := h.queries.GetShapeByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteShape(ctx, id)
	case FilterFieldLocation:
		_, e := h.queries.GetLocationByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteLocation(ctx, id)
	case FilterFieldTexture:
		_, e := h.queries.GetTextureByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteTexture(ctx, id)
	case FilterFieldWalls:
		_, e := h.queries.GetWallsByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteWalls(ctx, id)
	case FilterFieldCells:
		_, e := h.queries.GetCellsByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteCells(ctx, id)
	case FilterFieldAlignment:
		_, e := h.queries.GetAlignmentByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteAlignment(ctx, id)
	case FilterFieldSeason:
		_, e := h.queries.GetSeasonByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteSeason(ctx, id)
	case FilterFieldForm:
		_, e := h.queries.GetFormByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteForm(ctx, id)
	case FilterFieldAbundance:
		_, e := h.queries.GetAbundanceValueByID(ctx, id)
		if e != nil {
			if errors.Is(e, sql.ErrNoRows) {
				middleware.RespondNotFound(w, "Filter field not found")
				return
			}
			slog.Error("failed to get filter field", "error", e)
			middleware.RespondInternalError(w, "Failed to get filter field")
			return
		}
		deleteErr = h.queries.DeleteAbundanceValue(ctx, id)
	}

	if deleteErr != nil {
		slog.Error("failed to delete filter field", "type", fieldType, "id", id, "error", deleteErr)
		middleware.RespondInternalError(w, "Failed to delete filter field")
		return
	}

	middleware.RespondNoContent(w)
}

// Helper functions

func isValidFilterFieldType(t FilterFieldType) bool {
	for _, valid := range ValidFilterFieldTypes {
		if t == valid {
			return true
		}
	}
	return false
}

func nullStringToPtr(ns sql.NullString) *string {
	if ns.Valid {
		return &ns.String
	}
	return nil
}

func ptrToNullString(s *string) sql.NullString {
	if s != nil {
		return sql.NullString{String: *s, Valid: true}
	}
	return sql.NullString{Valid: false}
}
