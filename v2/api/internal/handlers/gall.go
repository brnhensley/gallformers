package handlers

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	"github.com/jeffdc/gallformers/v2/api/internal/middleware"
)

// GallHandler handles gall-related HTTP requests.
type GallHandler struct {
	queries *db.Queries
}

// NewGallHandler creates a new GallHandler.
func NewGallHandler(queries *db.Queries) *GallHandler {
	return &GallHandler{queries: queries}
}

// Alias represents an alias for API responses.
type Alias struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Type        string `json:"type"`
	Description string `json:"description"`
}

// FilterField represents a filter field value for API responses.
type FilterField struct {
	ID          int64   `json:"id"`
	Field       string  `json:"field"`
	Description *string `json:"description,omitempty"`
}

// Host represents a host for API responses.
type Host struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
}

// ImageResponse represents an image for API responses.
type ImageResponse struct {
	ID          int64  `json:"id"`
	Path        string `json:"path"`
	URL         string `json:"url"`
	Creator     string `json:"creator,omitempty"`
	Attribution string `json:"attribution,omitempty"`
	Sourcelink  string `json:"sourcelink,omitempty"`
	License     string `json:"license,omitempty"`
	Licenselink string `json:"licenselink,omitempty"`
	Caption     string `json:"caption,omitempty"`
}

// GallResponse represents a gall in API responses.
type GallResponse struct {
	ID             int64         `json:"id"`
	Name           string        `json:"name"`
	GallID         int64         `json:"gall_id"`
	Datacomplete   bool          `json:"datacomplete"`
	AbundanceID    *int64        `json:"abundance_id,omitempty"`
	Detachable     *int64        `json:"detachable,omitempty"`
	Undescribed    bool          `json:"undescribed"`
	Aliases        []Alias       `json:"aliases"`
	Hosts          []Host        `json:"hosts,omitempty"`
	Colors         []FilterField `json:"colors,omitempty"`
	Shapes         []FilterField `json:"shapes,omitempty"`
	Textures       []FilterField `json:"textures,omitempty"`
	Locations      []FilterField `json:"locations,omitempty"`
	Alignments     []FilterField `json:"alignments,omitempty"`
	Walls          []FilterField `json:"walls,omitempty"`
	Cells          []FilterField `json:"cells,omitempty"`
	Seasons        []FilterField `json:"seasons,omitempty"`
	Forms          []FilterField `json:"forms,omitempty"`
	Places         []string      `json:"places,omitempty"`
	ExcludedPlaces []string      `json:"excludedPlaces,omitempty"`
}

// GallListResponse represents a paginated list of galls.
type GallListResponse struct {
	Data   []GallResponse `json:"data"`
	Total  int64          `json:"total"`
	Limit  *int64         `json:"limit,omitempty"`
	Offset int64          `json:"offset"`
}

// RandomGallResponse represents a random gall with its image for the home page.
type RandomGallResponse struct {
	ID               int64  `json:"id"`
	Name             string `json:"name"`
	Undescribed      bool   `json:"undescribed"`
	ImagePath        string `json:"image_path"`
	ImageURL         string `json:"image_url"`
	ImageCreator     string `json:"image_creator"`
	ImageLicense     string `json:"image_license"`
	ImageSourceLink  string `json:"image_sourcelink"`
	ImageLicenseLink string `json:"image_licenselink"`
}

// RelatedGallResponse represents a related gall (same binomial name) for linking.
type RelatedGallResponse struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
}

// CloudFront base URL for images
const imageBaseURL = "https://dhz6u1p7t6okk.cloudfront.net"

// GallCreateRequest represents the request body for creating a gall.
type GallCreateRequest struct {
	Name         string  `json:"name"`
	Datacomplete bool    `json:"datacomplete"`
	AbundanceID  *int64  `json:"abundance_id,omitempty"`
	Detachable   *int64  `json:"detachable,omitempty"`
	Undescribed  bool    `json:"undescribed"`
	Aliases      []Alias `json:"aliases,omitempty"`
	Hosts        []int64 `json:"hosts,omitempty"`
	Colors       []int64 `json:"colors,omitempty"`
	Shapes       []int64 `json:"shapes,omitempty"`
	Textures     []int64 `json:"textures,omitempty"`
	Locations    []int64 `json:"locations,omitempty"`
	Alignments   []int64 `json:"alignments,omitempty"`
	Walls        []int64 `json:"walls,omitempty"`
	Cells        []int64 `json:"cells,omitempty"`
	Seasons      []int64 `json:"seasons,omitempty"`
	Forms        []int64 `json:"forms,omitempty"`
}

// GallUpdateRequest represents the request body for updating a gall.
type GallUpdateRequest struct {
	Name         string  `json:"name"`
	Datacomplete bool    `json:"datacomplete"`
	AbundanceID  *int64  `json:"abundance_id,omitempty"`
	Detachable   *int64  `json:"detachable,omitempty"`
	Undescribed  bool    `json:"undescribed"`
	Aliases      []Alias `json:"aliases,omitempty"`
	Hosts        []int64 `json:"hosts,omitempty"`
	Colors       []int64 `json:"colors,omitempty"`
	Shapes       []int64 `json:"shapes,omitempty"`
	Textures     []int64 `json:"textures,omitempty"`
	Locations    []int64 `json:"locations,omitempty"`
	Alignments   []int64 `json:"alignments,omitempty"`
	Walls        []int64 `json:"walls,omitempty"`
	Cells        []int64 `json:"cells,omitempty"`
	Seasons      []int64 `json:"seasons,omitempty"`
	Forms        []int64 `json:"forms,omitempty"`
}

// IDGallResponse is a compact gall representation optimized for the ID tool.
// Contains all filter fields as string arrays for client-side filtering.
type IDGallResponse struct {
	ID          int64    `json:"id"`
	Name        string   `json:"name"`
	Undescribed bool     `json:"undescribed"`
	Detachable  string   `json:"detachable"` // "integral", "detachable", "both", or ""
	Alignments  []string `json:"alignments"`
	Cells       []string `json:"cells"`
	Colors      []string `json:"colors"`
	Forms       []string `json:"forms"`
	Locations   []string `json:"locations"`
	Seasons     []string `json:"seasons"`
	Shapes      []string `json:"shapes"`
	Textures    []string `json:"textures"`
	Walls       []string `json:"walls"`
	Places      []string `json:"places"`
	Family      string   `json:"family"`
	Genus       string   `json:"genus"`
	Hosts       []Host   `json:"hosts"`
	ImageURL    string   `json:"imageUrl,omitempty"`
}

// RegisterRoutes registers gall routes on the router.
func (h *GallHandler) RegisterRoutes(r chi.Router) {
	r.Route("/galls", func(r chi.Router) {
		// Public routes
		r.Get("/", h.List)
		r.Get("/random", h.GetRandom) // Random gall with image for home page
		r.Get("/id", h.ListForID)     // Must come before /{id} to not be matched as an ID
		r.Get("/{id}", h.GetByID)
		r.Get("/{id}/images", h.GetImages)   // Images for a species
		r.Get("/{id}/related", h.GetRelated) // Related galls (same binomial name)

		// Protected routes - require authentication
		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Post("/", h.Create)
			r.Put("/{id}", h.Update)
			r.Delete("/{id}", h.Delete)
		})
	})
}

// List handles GET /api/v2/galls
// Supports search via q query param and pagination via limit/offset.
func (h *GallHandler) List(w http.ResponseWriter, r *http.Request) {
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
	var galls []GallResponse
	var err error

	if searchQuery != "" {
		// Search mode
		total, err = h.queries.CountSearchGalls(ctx, sql.NullString{String: searchQuery, Valid: true})
		if err != nil {
			slog.Error("failed to count search galls", "error", err)
			middleware.RespondInternalError(w, "Failed to count galls")
			return
		}

		if limit != nil {
			rows, err := h.queries.SearchGallsPaginated(ctx, db.SearchGallsPaginatedParams{
				Column1: sql.NullString{String: searchQuery, Valid: true},
				Limit:   *limit,
				Offset:  offset,
			})
			if err != nil {
				slog.Error("failed to search galls paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to search galls")
				return
			}
			galls = make([]GallResponse, len(rows))
			for i, row := range rows {
				galls[i] = h.rowToGallResponse(ctx, row.ID, row.Name, row.Datacomplete,
					row.AbundanceID, row.GallID, row.Detachable, row.Undescribed, false)
			}
		} else {
			rows, err := h.queries.SearchGalls(ctx, sql.NullString{String: searchQuery, Valid: true})
			if err != nil {
				slog.Error("failed to search galls", "error", err)
				middleware.RespondInternalError(w, "Failed to search galls")
				return
			}
			galls = make([]GallResponse, len(rows))
			for i, row := range rows {
				galls[i] = h.rowToGallResponse(ctx, row.ID, row.Name, row.Datacomplete,
					row.AbundanceID, row.GallID, row.Detachable, row.Undescribed, false)
			}
		}
	} else {
		// List mode
		total, err = h.queries.CountGalls(ctx)
		if err != nil {
			slog.Error("failed to count galls", "error", err)
			middleware.RespondInternalError(w, "Failed to count galls")
			return
		}

		if limit != nil {
			rows, err := h.queries.ListGallsPaginated(ctx, db.ListGallsPaginatedParams{
				Limit:  *limit,
				Offset: offset,
			})
			if err != nil {
				slog.Error("failed to list galls paginated", "error", err)
				middleware.RespondInternalError(w, "Failed to list galls")
				return
			}
			galls = make([]GallResponse, len(rows))
			for i, row := range rows {
				galls[i] = h.rowToGallResponse(ctx, row.ID, row.Name, row.Datacomplete,
					row.AbundanceID, row.GallID, row.Detachable, row.Undescribed, false)
			}
		} else {
			rows, err := h.queries.ListGalls(ctx)
			if err != nil {
				slog.Error("failed to list galls", "error", err)
				middleware.RespondInternalError(w, "Failed to list galls")
				return
			}
			galls = make([]GallResponse, len(rows))
			for i, row := range rows {
				galls[i] = h.rowToGallResponse(ctx, row.ID, row.Name, row.Datacomplete,
					row.AbundanceID, row.GallID, row.Detachable, row.Undescribed, false)
			}
		}
	}

	response := GallListResponse{
		Data:   galls,
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}

	middleware.RespondOK(w, response)
}

// GetByID handles GET /api/v2/galls/{id}
func (h *GallHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid gall ID")
		return
	}

	row, err := h.queries.GetGallByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Gall not found")
			return
		}
		slog.Error("failed to get gall", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get gall")
		return
	}

	gall := h.rowToGallResponse(ctx, row.ID, row.Name, row.Datacomplete,
		row.AbundanceID, row.GallID, row.Detachable, row.Undescribed, true)

	middleware.RespondOK(w, gall)
}

// GetImages handles GET /api/v2/galls/{id}/images
// Returns all images for a species (gall).
func (h *GallHandler) GetImages(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid species ID")
		return
	}

	rows, err := h.queries.GetImagesBySpeciesID(ctx, id)
	if err != nil {
		slog.Error("failed to get images", "error", err, "speciesID", id)
		middleware.RespondInternalError(w, "Failed to get images")
		return
	}

	images := make([]ImageResponse, len(rows))
	for i, row := range rows {
		images[i] = ImageResponse{
			ID:   row.ID,
			Path: row.Path,
			URL:  imageBaseURL + "/" + row.Path,
		}
		if row.Creator.Valid {
			images[i].Creator = row.Creator.String
		}
		if row.Attribution.Valid {
			images[i].Attribution = row.Attribution.String
		}
		if row.Sourcelink.Valid {
			images[i].Sourcelink = row.Sourcelink.String
		}
		if row.License.Valid {
			images[i].License = row.License.String
		}
		if row.Licenselink.Valid {
			images[i].Licenselink = row.Licenselink.String
		}
		if row.Caption.Valid {
			images[i].Caption = row.Caption.String
		}
	}

	middleware.RespondOK(w, images)
}

// GetRelated handles GET /api/v2/galls/{id}/related
// Returns galls with the same binomial name (genus + species epithet).
// Related galls share the first two name parts but have additional qualifiers.
func (h *GallHandler) GetRelated(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid gall ID")
		return
	}

	// Get the gall to get its name
	row, err := h.queries.GetGallByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Gall not found")
			return
		}
		slog.Error("failed to get gall", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get gall")
		return
	}

	// Split the name into parts
	nameParts := strings.Fields(row.Name)
	if len(nameParts) < 2 {
		// No related galls possible without at least genus + species
		middleware.RespondOK(w, []RelatedGallResponse{})
		return
	}

	// Build the prefix: "Genus species " (with trailing space)
	namePrefix := nameParts[0] + " " + nameParts[1] + " "

	// Find related galls
	related, err := h.queries.GetRelatedGalls(ctx, db.GetRelatedGallsParams{
		Column1: sql.NullString{String: namePrefix, Valid: true},
		ID:      id,
	})
	if err != nil {
		slog.Error("failed to get related galls", "error", err, "id", id)
		middleware.RespondInternalError(w, "Failed to get related galls")
		return
	}

	response := make([]RelatedGallResponse, len(related))
	for i, r := range related {
		response[i] = RelatedGallResponse{
			ID:   r.ID,
			Name: r.Name,
		}
	}

	middleware.RespondOK(w, response)
}

// GetRandom handles GET /api/v2/galls/random
// Returns a random gall that has a default image, for the home page.
func (h *GallHandler) GetRandom(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	row, err := h.queries.GetRandomGallWithImage(ctx)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "No galls with images found")
			return
		}
		slog.Error("failed to get random gall", "error", err)
		middleware.RespondInternalError(w, "Failed to get random gall")
		return
	}

	response := RandomGallResponse{
		ID:               row.ID,
		Name:             row.Name,
		Undescribed:      row.Undescribed,
		ImagePath:        row.ImagePath,
		ImageURL:         imageBaseURL + "/" + row.ImagePath,
		ImageCreator:     row.ImageCreator.String,
		ImageLicense:     row.ImageLicense.String,
		ImageSourceLink:  row.ImageSourcelink.String,
		ImageLicenseLink: row.ImageLicenselink.String,
	}

	middleware.RespondOK(w, response)
}

// ListForID handles GET /api/v2/galls/id
// Returns all galls with their filter fields for client-side filtering in the ID tool.
func (h *GallHandler) ListForID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get all galls
	rows, err := h.queries.ListGalls(ctx)
	if err != nil {
		slog.Error("failed to list galls for ID", "error", err)
		middleware.RespondInternalError(w, "Failed to list galls")
		return
	}

	// Batch fetch default images for all gall species
	defaultImages, err := h.queries.GetDefaultImages(ctx)
	if err != nil {
		slog.Warn("failed to fetch default images for ID tool", "error", err)
		defaultImages = nil
	}

	// Build a map of species_id -> image path for quick lookup
	imageMap := make(map[int64]string, len(defaultImages))
	for _, img := range defaultImages {
		imageMap[img.SpeciesID] = img.Path
	}

	galls := make([]IDGallResponse, 0, len(rows))
	for _, row := range rows {
		gall := h.rowToIDGallResponse(ctx, row.ID, row.Name, row.GallID, row.Detachable, row.Undescribed)
		// Attach image URL if available
		if path, ok := imageMap[row.ID]; ok {
			gall.ImageURL = imageBaseURL + "/" + path
		}
		galls = append(galls, gall)
	}

	middleware.RespondOK(w, galls)
}

// rowToIDGallResponse converts a gall row to an ID tool response with all filter fields.
func (h *GallHandler) rowToIDGallResponse(ctx context.Context, speciesID int64, name string, gallID int64, detachable sql.NullInt64, undescribed bool) IDGallResponse {
	response := IDGallResponse{
		ID:          speciesID,
		Name:        name,
		Undescribed: undescribed,
		Alignments:  []string{},
		Cells:       []string{},
		Colors:      []string{},
		Forms:       []string{},
		Locations:   []string{},
		Seasons:     []string{},
		Shapes:      []string{},
		Textures:    []string{},
		Walls:       []string{},
		Places:      []string{},
		Hosts:       []Host{},
	}

	// Convert detachable value
	if detachable.Valid {
		switch detachable.Int64 {
		case 0:
			response.Detachable = "integral"
		case 1:
			response.Detachable = "detachable"
		case 2:
			response.Detachable = "both"
		default:
			response.Detachable = ""
		}
	}

	// Fetch alignments
	alignments, err := h.queries.GetGallAlignments(ctx, gallID)
	if err == nil {
		for _, a := range alignments {
			response.Alignments = append(response.Alignments, a.Alignment)
		}
	}

	// Fetch cells
	cells, err := h.queries.GetGallCells(ctx, gallID)
	if err == nil {
		for _, c := range cells {
			response.Cells = append(response.Cells, c.Cells)
		}
	}

	// Fetch colors
	colors, err := h.queries.GetGallColors(ctx, gallID)
	if err == nil {
		for _, c := range colors {
			response.Colors = append(response.Colors, c.Color)
		}
	}

	// Fetch forms
	forms, err := h.queries.GetGallForms(ctx, gallID)
	if err == nil {
		for _, f := range forms {
			response.Forms = append(response.Forms, f.Form)
		}
	}

	// Fetch locations
	locations, err := h.queries.GetGallLocations(ctx, gallID)
	if err == nil {
		for _, l := range locations {
			response.Locations = append(response.Locations, l.Location)
		}
	}

	// Fetch seasons
	seasons, err := h.queries.GetGallSeasons(ctx, sql.NullInt64{Int64: gallID, Valid: true})
	if err == nil {
		for _, s := range seasons {
			response.Seasons = append(response.Seasons, s.Season)
		}
	}

	// Fetch shapes
	shapes, err := h.queries.GetGallShapes(ctx, gallID)
	if err == nil {
		for _, s := range shapes {
			response.Shapes = append(response.Shapes, s.Shape)
		}
	}

	// Fetch textures
	textures, err := h.queries.GetGallTextures(ctx, gallID)
	if err == nil {
		for _, t := range textures {
			response.Textures = append(response.Textures, t.Texture)
		}
	}

	// Fetch walls
	walls, err := h.queries.GetGallWalls(ctx, gallID)
	if err == nil {
		for _, w := range walls {
			response.Walls = append(response.Walls, w.Walls)
		}
	}

	// Fetch places
	places, err := h.queries.GetGallPlaces(ctx, sql.NullInt64{Int64: speciesID, Valid: true})
	if err == nil {
		response.Places = places
	}

	// Fetch taxonomy (genus and family)
	taxonomy, err := h.queries.GetGallTaxonomy(ctx, speciesID)
	if err == nil {
		response.Genus = taxonomy.Genus
		if taxonomy.Family.Valid {
			response.Family = taxonomy.Family.String
		}
	}

	// Fetch hosts
	hosts, err := h.queries.GetGallHosts(ctx, sql.NullInt64{Int64: speciesID, Valid: true})
	if err == nil {
		response.Hosts = make([]Host, len(hosts))
		for i, h := range hosts {
			response.Hosts[i] = Host{ID: h.HostSpeciesID, Name: h.HostName}
		}
	}

	return response
}

// Create handles POST /api/v2/galls
func (h *GallHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req GallCreateRequest
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

	speciesID, err := h.queries.CreateSpecies(ctx, db.CreateSpeciesParams{
		Name:         req.Name,
		Datacomplete: req.Datacomplete,
		AbundanceID:  abundanceID,
	})
	if err != nil {
		slog.Error("failed to create species", "error", err)
		middleware.RespondInternalError(w, "Failed to create gall")
		return
	}

	// Create the gall record
	var detachable sql.NullInt64
	if req.Detachable != nil {
		detachable = sql.NullInt64{Int64: *req.Detachable, Valid: true}
	}

	gallID, err := h.queries.CreateGall(ctx, db.CreateGallParams{
		Detachable:  detachable,
		Undescribed: req.Undescribed,
	})
	if err != nil {
		slog.Error("failed to create gall", "error", err)
		// Clean up species
		h.queries.DeleteSpeciesByID(ctx, speciesID)
		middleware.RespondInternalError(w, "Failed to create gall")
		return
	}

	// Link species to gall
	if err := h.queries.CreateGallSpecies(ctx, db.CreateGallSpeciesParams{
		SpeciesID: speciesID,
		GallID:    gallID,
	}); err != nil {
		slog.Error("failed to link species to gall", "error", err)
		h.queries.DeleteGallByID(ctx, gallID)
		h.queries.DeleteSpeciesByID(ctx, speciesID)
		middleware.RespondInternalError(w, "Failed to create gall")
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

	// Create host associations
	for _, hostID := range req.Hosts {
		if err := h.queries.InsertHost(ctx, db.InsertHostParams{
			HostSpeciesID: sql.NullInt64{Int64: hostID, Valid: true},
			GallSpeciesID: sql.NullInt64{Int64: speciesID, Valid: true},
		}); err != nil {
			slog.Error("failed to create host association", "error", err, "hostID", hostID)
		}
	}

	// Create filter field associations
	h.createFilterAssociations(ctx, gallID, req.Colors, req.Shapes, req.Textures,
		req.Locations, req.Alignments, req.Walls, req.Cells, req.Seasons, req.Forms)

	response := GallResponse{
		ID:           speciesID,
		Name:         req.Name,
		GallID:       gallID,
		Datacomplete: req.Datacomplete,
		AbundanceID:  req.AbundanceID,
		Detachable:   req.Detachable,
		Undescribed:  req.Undescribed,
		Aliases:      aliases,
	}

	middleware.RespondCreated(w, response)
}

// Update handles PUT /api/v2/galls/{id}
func (h *GallHandler) Update(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	speciesID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid gall ID")
		return
	}

	// Check if gall exists
	existing, err := h.queries.GetGallByID(ctx, speciesID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Gall not found")
			return
		}
		slog.Error("failed to get gall", "error", err, "id", speciesID)
		middleware.RespondInternalError(w, "Failed to get gall")
		return
	}

	var req GallUpdateRequest
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

	if err := h.queries.UpdateSpecies(ctx, db.UpdateSpeciesParams{
		Name:         req.Name,
		Datacomplete: req.Datacomplete,
		AbundanceID:  abundanceID,
		ID:           speciesID,
	}); err != nil {
		slog.Error("failed to update species", "error", err)
		middleware.RespondInternalError(w, "Failed to update gall")
		return
	}

	// Update gall
	var detachable sql.NullInt64
	if req.Detachable != nil {
		detachable = sql.NullInt64{Int64: *req.Detachable, Valid: true}
	}

	if err := h.queries.UpdateGall(ctx, db.UpdateGallParams{
		Detachable:  detachable,
		Undescribed: req.Undescribed,
		ID:          existing.GallID,
	}); err != nil {
		slog.Error("failed to update gall", "error", err)
		middleware.RespondInternalError(w, "Failed to update gall")
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

	// Update hosts - delete existing and recreate
	h.queries.DeleteHostsByGallSpeciesID(ctx, sql.NullInt64{Int64: speciesID, Valid: true})
	for _, hostID := range req.Hosts {
		if err := h.queries.InsertHost(ctx, db.InsertHostParams{
			HostSpeciesID: sql.NullInt64{Int64: hostID, Valid: true},
			GallSpeciesID: sql.NullInt64{Int64: speciesID, Valid: true},
		}); err != nil {
			slog.Error("failed to create host association", "error", err, "hostID", hostID)
		}
	}

	// Update filter associations - delete existing and recreate
	gallID := existing.GallID
	h.queries.DeleteGallColors(ctx, gallID)
	h.queries.DeleteGallShapes(ctx, gallID)
	h.queries.DeleteGallTextures(ctx, gallID)
	h.queries.DeleteGallLocations(ctx, gallID)
	h.queries.DeleteGallAlignments(ctx, gallID)
	h.queries.DeleteGallWalls(ctx, gallID)
	h.queries.DeleteGallCells(ctx, gallID)
	h.queries.DeleteGallSeasons(ctx, sql.NullInt64{Int64: gallID, Valid: true})
	h.queries.DeleteGallForms(ctx, gallID)

	h.createFilterAssociations(ctx, gallID, req.Colors, req.Shapes, req.Textures,
		req.Locations, req.Alignments, req.Walls, req.Cells, req.Seasons, req.Forms)

	response := GallResponse{
		ID:           speciesID,
		Name:         req.Name,
		GallID:       gallID,
		Datacomplete: req.Datacomplete,
		AbundanceID:  req.AbundanceID,
		Detachable:   req.Detachable,
		Undescribed:  req.Undescribed,
		Aliases:      aliases,
	}

	middleware.RespondOK(w, response)
}

// Delete handles DELETE /api/v2/galls/{id}
func (h *GallHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	speciesID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		middleware.RespondBadRequest(w, "Invalid gall ID")
		return
	}

	// Check if gall exists and get gall_id
	existing, err := h.queries.GetGallByID(ctx, speciesID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			middleware.RespondNotFound(w, "Gall not found")
			return
		}
		slog.Error("failed to get gall", "error", err, "id", speciesID)
		middleware.RespondInternalError(w, "Failed to delete gall")
		return
	}

	// Delete in order to respect foreign key constraints
	gallID := existing.GallID

	// Delete filter associations
	h.queries.DeleteGallColors(ctx, gallID)
	h.queries.DeleteGallShapes(ctx, gallID)
	h.queries.DeleteGallTextures(ctx, gallID)
	h.queries.DeleteGallLocations(ctx, gallID)
	h.queries.DeleteGallAlignments(ctx, gallID)
	h.queries.DeleteGallWalls(ctx, gallID)
	h.queries.DeleteGallCells(ctx, gallID)
	h.queries.DeleteGallSeasons(ctx, sql.NullInt64{Int64: gallID, Valid: true})
	h.queries.DeleteGallForms(ctx, gallID)

	// Delete hosts
	h.queries.DeleteHostsByGallSpeciesID(ctx, sql.NullInt64{Int64: speciesID, Valid: true})

	// Delete aliases
	h.queries.DeleteAliasSpeciesBySpeciesID(ctx, speciesID)
	h.queries.DeleteAliasBySpeciesID(ctx, speciesID)

	// Delete gall-species link
	h.queries.DeleteGallSpecies(ctx, speciesID)

	// Delete gall
	h.queries.DeleteGallByID(ctx, gallID)

	// Delete species (this should cascade, but being explicit)
	if err := h.queries.DeleteSpeciesByID(ctx, speciesID); err != nil {
		slog.Error("failed to delete species", "error", err, "id", speciesID)
		middleware.RespondInternalError(w, "Failed to delete gall")
		return
	}

	middleware.RespondNoContent(w)
}

// Helper methods

func (h *GallHandler) rowToGallResponse(ctx context.Context, id int64, name string, datacomplete bool,
	abundanceID sql.NullInt64, gallID int64, detachable sql.NullInt64, undescribed bool, includeDetails bool) GallResponse {

	response := GallResponse{
		ID:           id,
		Name:         name,
		GallID:       gallID,
		Datacomplete: datacomplete,
		Undescribed:  undescribed,
	}

	if abundanceID.Valid {
		response.AbundanceID = &abundanceID.Int64
	}
	if detachable.Valid {
		response.Detachable = &detachable.Int64
	}

	// Always fetch aliases
	aliases, err := h.queries.GetAliasesBySpeciesID(ctx, id)
	if err != nil {
		slog.Error("failed to get aliases", "error", err, "speciesID", id)
		response.Aliases = []Alias{}
	} else {
		response.Aliases = make([]Alias, len(aliases))
		for i, a := range aliases {
			response.Aliases[i] = Alias{
				ID:          a.ID,
				Name:        a.Name,
				Type:        a.Type,
				Description: a.Description,
			}
		}
	}

	// Only fetch detailed data for single-item requests (not lists)
	if includeDetails {
		// Fetch hosts
		hosts, err := h.queries.GetGallHosts(ctx, sql.NullInt64{Int64: id, Valid: true})
		if err != nil {
			slog.Error("failed to get hosts", "error", err, "speciesID", id)
		} else {
			response.Hosts = make([]Host, len(hosts))
			for i, h := range hosts {
				response.Hosts[i] = Host{ID: h.HostSpeciesID, Name: h.HostName}
			}
		}

		// Fetch filter fields
		response.Colors = h.getColors(ctx, gallID)
		response.Shapes = h.getShapes(ctx, gallID)
		response.Textures = h.getTextures(ctx, gallID)
		response.Locations = h.getLocations(ctx, gallID)
		response.Alignments = h.getAlignments(ctx, gallID)
		response.Walls = h.getWalls(ctx, gallID)
		response.Cells = h.getCells(ctx, gallID)
		response.Seasons = h.getSeasons(ctx, gallID)
		response.Forms = h.getForms(ctx, gallID)

		// Fetch places (from hosts) and excluded places (direct on species)
		places, err := h.queries.GetGallPlaces(ctx, sql.NullInt64{Int64: id, Valid: true})
		if err == nil {
			response.Places = places
		}
		excludedPlaces, err := h.queries.GetGallExcludedPlaces(ctx, sql.NullInt64{Int64: id, Valid: true})
		if err == nil {
			response.ExcludedPlaces = excludedPlaces
		}
	}

	return response
}

func (h *GallHandler) getColors(ctx context.Context, gallID int64) []FilterField {
	colors, err := h.queries.GetGallColors(ctx, gallID)
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(colors))
	for i, c := range colors {
		result[i] = FilterField{ID: c.ID, Field: c.Color}
	}
	return result
}

func (h *GallHandler) getShapes(ctx context.Context, gallID int64) []FilterField {
	shapes, err := h.queries.GetGallShapes(ctx, gallID)
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(shapes))
	for i, s := range shapes {
		result[i] = FilterField{ID: s.ID, Field: s.Shape}
		if s.Description.Valid {
			result[i].Description = &s.Description.String
		}
	}
	return result
}

func (h *GallHandler) getTextures(ctx context.Context, gallID int64) []FilterField {
	textures, err := h.queries.GetGallTextures(ctx, gallID)
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(textures))
	for i, t := range textures {
		result[i] = FilterField{ID: t.ID, Field: t.Texture}
		if t.Description.Valid {
			result[i].Description = &t.Description.String
		}
	}
	return result
}

func (h *GallHandler) getLocations(ctx context.Context, gallID int64) []FilterField {
	locations, err := h.queries.GetGallLocations(ctx, gallID)
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(locations))
	for i, l := range locations {
		result[i] = FilterField{ID: l.ID, Field: l.Location}
		if l.Description.Valid {
			result[i].Description = &l.Description.String
		}
	}
	return result
}

func (h *GallHandler) getAlignments(ctx context.Context, gallID int64) []FilterField {
	alignments, err := h.queries.GetGallAlignments(ctx, gallID)
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(alignments))
	for i, a := range alignments {
		result[i] = FilterField{ID: a.ID, Field: a.Alignment}
		if a.Description.Valid {
			result[i].Description = &a.Description.String
		}
	}
	return result
}

func (h *GallHandler) getWalls(ctx context.Context, gallID int64) []FilterField {
	walls, err := h.queries.GetGallWalls(ctx, gallID)
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(walls))
	for i, w := range walls {
		result[i] = FilterField{ID: w.ID, Field: w.Walls}
		if w.Description.Valid {
			result[i].Description = &w.Description.String
		}
	}
	return result
}

func (h *GallHandler) getCells(ctx context.Context, gallID int64) []FilterField {
	cells, err := h.queries.GetGallCells(ctx, gallID)
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(cells))
	for i, c := range cells {
		result[i] = FilterField{ID: c.ID, Field: c.Cells}
		if c.Description.Valid {
			result[i].Description = &c.Description.String
		}
	}
	return result
}

func (h *GallHandler) getSeasons(ctx context.Context, gallID int64) []FilterField {
	seasons, err := h.queries.GetGallSeasons(ctx, sql.NullInt64{Int64: gallID, Valid: true})
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(seasons))
	for i, s := range seasons {
		result[i] = FilterField{ID: s.ID, Field: s.Season}
	}
	return result
}

func (h *GallHandler) getForms(ctx context.Context, gallID int64) []FilterField {
	forms, err := h.queries.GetGallForms(ctx, gallID)
	if err != nil {
		return []FilterField{}
	}
	result := make([]FilterField, len(forms))
	for i, f := range forms {
		result[i] = FilterField{ID: f.ID, Field: f.Form}
		if f.Description.Valid {
			result[i].Description = &f.Description.String
		}
	}
	return result
}

func (h *GallHandler) createFilterAssociations(ctx context.Context, gallID int64,
	colors, shapes, textures, locations, alignments, walls, cells, seasons, forms []int64) {

	for _, id := range colors {
		h.queries.InsertGallColor(ctx, db.InsertGallColorParams{GallID: gallID, ColorID: id})
	}
	for _, id := range shapes {
		h.queries.InsertGallShape(ctx, db.InsertGallShapeParams{GallID: gallID, ShapeID: id})
	}
	for _, id := range textures {
		h.queries.InsertGallTexture(ctx, db.InsertGallTextureParams{GallID: gallID, TextureID: id})
	}
	for _, id := range locations {
		h.queries.InsertGallLocation(ctx, db.InsertGallLocationParams{GallID: gallID, LocationID: id})
	}
	for _, id := range alignments {
		h.queries.InsertGallAlignment(ctx, db.InsertGallAlignmentParams{GallID: gallID, AlignmentID: id})
	}
	for _, id := range walls {
		h.queries.InsertGallWalls(ctx, db.InsertGallWallsParams{GallID: gallID, WallsID: id})
	}
	for _, id := range cells {
		h.queries.InsertGallCells(ctx, db.InsertGallCellsParams{GallID: gallID, CellsID: id})
	}
	for _, id := range seasons {
		h.queries.InsertGallSeason(ctx, db.InsertGallSeasonParams{
			GallID:   sql.NullInt64{Int64: gallID, Valid: true},
			SeasonID: sql.NullInt64{Int64: id, Valid: true},
		})
	}
	for _, id := range forms {
		h.queries.InsertGallForm(ctx, db.InsertGallFormParams{GallID: gallID, FormID: id})
	}
}
