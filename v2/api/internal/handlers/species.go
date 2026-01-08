package handlers

import (
	"database/sql"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	"github.com/jeffdc/gallformers/v2/api/internal/middleware"
)

// SpeciesResponse represents a species in API responses.
type SpeciesResponse struct {
	ID           int64   `json:"id"`
	Name         string  `json:"name"`
	Taxoncode    *string `json:"taxoncode,omitempty"`
	Datacomplete bool    `json:"datacomplete"`
	AbundanceID  *int64  `json:"abundance_id,omitempty"`
	Abundance    *string `json:"abundance,omitempty"`
}

// SpeciesListResponse wraps a list of species with pagination info.
type SpeciesListResponse struct {
	Data   []SpeciesResponse `json:"data"`
	Total  int64             `json:"total"`
	Limit  *int              `json:"limit,omitempty"`
	Offset int               `json:"offset"`
}

// ListSpecies returns a handler for GET /api/v2/species
// Supports search via ?q= parameter
func ListSpecies(queries *db.Queries) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		searchQuery := r.URL.Query().Get("q")

		var species []SpeciesResponse
		var total int64
		var err error

		if searchQuery != "" {
			// Search mode - wrap with % for LIKE
			searchTerm := "%" + searchQuery + "%"
			rows, searchErr := queries.SearchSpecies(ctx, searchTerm)
			if searchErr != nil {
				slog.Error("failed to search species", "error", searchErr, "query", searchQuery)
				middleware.RespondInternalError(w, "Failed to search species")
				return
			}

			total, err = queries.CountSpeciesSearch(ctx, searchTerm)
			if err != nil {
				slog.Error("failed to count species search results", "error", err)
				middleware.RespondInternalError(w, "Failed to count species")
				return
			}

			species = make([]SpeciesResponse, len(rows))
			for i, row := range rows {
				species[i] = speciesFromSearchRow(row)
			}
		} else {
			// List all mode
			rows, listErr := queries.ListSpecies(ctx)
			if listErr != nil {
				slog.Error("failed to list species", "error", listErr)
				middleware.RespondInternalError(w, "Failed to list species")
				return
			}

			total, err = queries.CountSpecies(ctx)
			if err != nil {
				slog.Error("failed to count species", "error", err)
				middleware.RespondInternalError(w, "Failed to count species")
				return
			}

			species = make([]SpeciesResponse, len(rows))
			for i, row := range rows {
				species[i] = speciesFromListRow(row)
			}
		}

		middleware.RespondOK(w, SpeciesListResponse{
			Data:   species,
			Total:  total,
			Offset: 0,
		})
	}
}

// GetSpecies returns a handler for GET /api/v2/species/{id}
func GetSpecies(queries *db.Queries) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		idStr := chi.URLParam(r, "id")

		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil {
			middleware.RespondBadRequest(w, "Invalid species ID")
			return
		}

		row, err := queries.GetSpeciesByID(ctx, id)
		if err != nil {
			if err == sql.ErrNoRows {
				middleware.RespondNotFound(w, "Species not found")
				return
			}
			slog.Error("failed to get species", "error", err, "id", id)
			middleware.RespondInternalError(w, "Failed to get species")
			return
		}

		middleware.RespondOK(w, speciesFromGetByIDRow(row))
	}
}

// Helper functions to convert db rows to API responses

func speciesFromListRow(row db.ListSpeciesRow) SpeciesResponse {
	resp := SpeciesResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
	}
	if row.Taxoncode.Valid {
		resp.Taxoncode = &row.Taxoncode.String
	}
	if row.AbundanceID.Valid {
		resp.AbundanceID = &row.AbundanceID.Int64
	}
	if row.AbundanceName.Valid {
		resp.Abundance = &row.AbundanceName.String
	}
	return resp
}

func speciesFromSearchRow(row db.SearchSpeciesRow) SpeciesResponse {
	resp := SpeciesResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
	}
	if row.Taxoncode.Valid {
		resp.Taxoncode = &row.Taxoncode.String
	}
	if row.AbundanceID.Valid {
		resp.AbundanceID = &row.AbundanceID.Int64
	}
	if row.AbundanceName.Valid {
		resp.Abundance = &row.AbundanceName.String
	}
	return resp
}

func speciesFromGetByIDRow(row db.GetSpeciesByIDRow) SpeciesResponse {
	resp := SpeciesResponse{
		ID:           row.ID,
		Name:         row.Name,
		Datacomplete: row.Datacomplete,
	}
	if row.Taxoncode.Valid {
		resp.Taxoncode = &row.Taxoncode.String
	}
	if row.AbundanceID.Valid {
		resp.AbundanceID = &row.AbundanceID.Int64
	}
	if row.AbundanceName.Valid {
		resp.Abundance = &row.AbundanceName.String
	}
	return resp
}
