package handlers

import (
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	"github.com/jeffdc/gallformers/v2/api/internal/middleware"
)

// StatsHandler handles statistics-related HTTP requests.
type StatsHandler struct {
	queries *db.Queries
}

// NewStatsHandler creates a new StatsHandler.
func NewStatsHandler(queries *db.Queries) *StatsHandler {
	return &StatsHandler{queries: queries}
}

// StatsResponse contains site statistics.
type StatsResponse struct {
	Galls        int64 `json:"galls"`
	GallFamilies int64 `json:"gallFamilies"`
	GallGenera   int64 `json:"gallGenera"`
	Undescribed  int64 `json:"undescribed"`
	Hosts        int64 `json:"hosts"`
	HostFamilies int64 `json:"hostFamilies"`
	HostGenera   int64 `json:"hostGenera"`
	Sources      int64 `json:"sources"`
}

// RegisterRoutes registers stats routes on the router.
func (h *StatsHandler) RegisterRoutes(r chi.Router) {
	r.Get("/stats", h.GetStats)
}

// GetStats handles GET /api/v2/stats
// Returns aggregated site statistics.
func (h *StatsHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var stats StatsResponse

	// Count galls
	galls, err := h.queries.CountGalls(ctx)
	if err != nil {
		slog.Error("failed to count galls", "error", err)
		middleware.RespondInternalError(w, "Failed to get statistics")
		return
	}
	stats.Galls = galls

	// Count undescribed galls
	undescribed, err := h.queries.CountUndescribedGalls(ctx)
	if err != nil {
		slog.Error("failed to count undescribed galls", "error", err)
		middleware.RespondInternalError(w, "Failed to get statistics")
		return
	}
	stats.Undescribed = undescribed

	// Count gall families
	gallFamilies, err := h.queries.CountGallFamilies(ctx)
	if err != nil {
		slog.Error("failed to count gall families", "error", err)
		middleware.RespondInternalError(w, "Failed to get statistics")
		return
	}
	stats.GallFamilies = gallFamilies

	// Count gall genera
	gallGenera, err := h.queries.CountGallGenera(ctx)
	if err != nil {
		slog.Error("failed to count gall genera", "error", err)
		middleware.RespondInternalError(w, "Failed to get statistics")
		return
	}
	stats.GallGenera = gallGenera

	// Count hosts
	hosts, err := h.queries.CountHosts(ctx)
	if err != nil {
		slog.Error("failed to count hosts", "error", err)
		middleware.RespondInternalError(w, "Failed to get statistics")
		return
	}
	stats.Hosts = hosts

	// Count host families
	hostFamilies, err := h.queries.CountHostFamilies(ctx)
	if err != nil {
		slog.Error("failed to count host families", "error", err)
		middleware.RespondInternalError(w, "Failed to get statistics")
		return
	}
	stats.HostFamilies = hostFamilies

	// Count host genera
	hostGenera, err := h.queries.CountHostGenera(ctx)
	if err != nil {
		slog.Error("failed to count host genera", "error", err)
		middleware.RespondInternalError(w, "Failed to get statistics")
		return
	}
	stats.HostGenera = hostGenera

	// Count sources
	sources, err := h.queries.CountSources(ctx)
	if err != nil {
		slog.Error("failed to count sources", "error", err)
		middleware.RespondInternalError(w, "Failed to get statistics")
		return
	}
	stats.Sources = sources

	middleware.RespondOK(w, stats)
}
