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

// ExploreHandler handles explore page HTTP requests.
type ExploreHandler struct {
	queries *db.Queries
}

// NewExploreHandler creates a new ExploreHandler.
func NewExploreHandler(queries *db.Queries) *ExploreHandler {
	return &ExploreHandler{queries: queries}
}

// TreeNode represents a node in the explore tree (family, genus, or species).
type TreeNode struct {
	Key   string     `json:"key"`
	Label string     `json:"label"`
	URL   string     `json:"url,omitempty"`
	Nodes []TreeNode `json:"nodes,omitempty"`
}

// ExploreResponse contains tree data for all three explore views.
type ExploreResponse struct {
	Galls       []TreeNode `json:"galls"`
	Undescribed []TreeNode `json:"undescribed"`
	Hosts       []TreeNode `json:"hosts"`
}

// RegisterRoutes registers explore routes on the router.
func (h *ExploreHandler) RegisterRoutes(r chi.Router) {
	r.Get("/explore", h.GetExploreData)
}

// GetExploreData handles GET /api/v2/explore
// Returns hierarchical tree data for galls, undescribed galls, and hosts.
func (h *ExploreHandler) GetExploreData(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Fetch all three datasets in parallel would be nice, but for simplicity fetch sequentially
	gallRows, err := h.queries.GetGallFamiliesWithSpecies(ctx)
	if err != nil {
		slog.Error("failed to get gall families", "error", err)
		middleware.RespondInternalError(w, "Failed to get explore data")
		return
	}

	undescribedRows, err := h.queries.GetUndescribedGallFamiliesWithSpecies(ctx)
	if err != nil {
		slog.Error("failed to get undescribed gall families", "error", err)
		middleware.RespondInternalError(w, "Failed to get explore data")
		return
	}

	hostRows, err := h.queries.GetHostFamiliesWithSpecies(ctx)
	if err != nil {
		slog.Error("failed to get host families", "error", err)
		middleware.RespondInternalError(w, "Failed to get explore data")
		return
	}

	response := ExploreResponse{
		Galls:       buildGallTree(gallRows),
		Undescribed: buildUndescribedTree(undescribedRows),
		Hosts:       buildHostTree(hostRows),
	}

	middleware.RespondOK(w, response)
}

// buildGallTree converts flat rows into a hierarchical tree structure for galls.
func buildGallTree(rows []db.GetGallFamiliesWithSpeciesRow) []TreeNode {
	return buildTree(rows, func(r db.GetGallFamiliesWithSpeciesRow) treeRow {
		return treeRow{
			FamilyID:          r.FamilyID,
			FamilyName:        r.FamilyName,
			FamilyDescription: r.FamilyDescription,
			GenusID:           r.GenusID,
			GenusName:         r.GenusName,
			GenusDescription:  r.GenusDescription,
			SpeciesID:         r.SpeciesID,
			SpeciesName:       r.SpeciesName,
			URLPath:           "gall",
		}
	})
}

// buildUndescribedTree converts flat rows into a hierarchical tree structure for undescribed galls.
func buildUndescribedTree(rows []db.GetUndescribedGallFamiliesWithSpeciesRow) []TreeNode {
	return buildTree(rows, func(r db.GetUndescribedGallFamiliesWithSpeciesRow) treeRow {
		return treeRow{
			FamilyID:          r.FamilyID,
			FamilyName:        r.FamilyName,
			FamilyDescription: r.FamilyDescription,
			GenusID:           r.GenusID,
			GenusName:         r.GenusName,
			GenusDescription:  r.GenusDescription,
			SpeciesID:         r.SpeciesID,
			SpeciesName:       r.SpeciesName,
			URLPath:           "gall",
		}
	})
}

// buildHostTree converts flat rows into a hierarchical tree structure for hosts.
func buildHostTree(rows []db.GetHostFamiliesWithSpeciesRow) []TreeNode {
	return buildTree(rows, func(r db.GetHostFamiliesWithSpeciesRow) treeRow {
		return treeRow{
			FamilyID:          r.FamilyID,
			FamilyName:        r.FamilyName,
			FamilyDescription: r.FamilyDescription,
			GenusID:           r.GenusID,
			GenusName:         r.GenusName,
			GenusDescription:  r.GenusDescription,
			SpeciesID:         r.SpeciesID,
			SpeciesName:       r.SpeciesName,
			URLPath:           "host",
		}
	})
}

// treeRow is a common structure for building trees.
type treeRow struct {
	FamilyID          int64
	FamilyName        string
	FamilyDescription sql.NullString
	GenusID           int64
	GenusName         string
	GenusDescription  sql.NullString
	SpeciesID         int64
	SpeciesName       string
	URLPath           string
}

// buildTree is a generic tree builder that works with any row type.
func buildTree[T any](rows []T, toRow func(T) treeRow) []TreeNode {
	// Build family -> genus -> species hierarchy
	// Use maps to track unique entries and maintain order
	type speciesEntry struct {
		id   int64
		name string
		url  string
	}

	type genusEntry struct {
		id          int64
		name        string
		description string
		species     []speciesEntry
		speciesMap  map[int64]bool
	}

	type familyEntry struct {
		id          int64
		name        string
		description string
		genera      []*genusEntry
		genusMap    map[int64]*genusEntry
	}

	families := make([]*familyEntry, 0)
	familyMap := make(map[int64]*familyEntry)

	for _, row := range rows {
		r := toRow(row)

		// Get or create family
		family, exists := familyMap[r.FamilyID]
		if !exists {
			family = &familyEntry{
				id:          r.FamilyID,
				name:        r.FamilyName,
				description: nullStringToString(r.FamilyDescription),
				genera:      make([]*genusEntry, 0),
				genusMap:    make(map[int64]*genusEntry),
			}
			familyMap[r.FamilyID] = family
			families = append(families, family)
		}

		// Get or create genus within family
		genus, exists := family.genusMap[r.GenusID]
		if !exists {
			genus = &genusEntry{
				id:          r.GenusID,
				name:        r.GenusName,
				description: nullStringToString(r.GenusDescription),
				species:     make([]speciesEntry, 0),
				speciesMap:  make(map[int64]bool),
			}
			family.genusMap[r.GenusID] = genus
			family.genera = append(family.genera, genus)
		}

		// Add species to genus (avoid duplicates)
		if !genus.speciesMap[r.SpeciesID] {
			genus.speciesMap[r.SpeciesID] = true
			genus.species = append(genus.species, speciesEntry{
				id:   r.SpeciesID,
				name: r.SpeciesName,
				url:  "/" + r.URLPath + "/" + intToString(r.SpeciesID),
			})
		}
	}

	// Convert to TreeNode structure
	result := make([]TreeNode, len(families))
	for i, family := range families {
		familyNode := TreeNode{
			Key:   intToString(family.id),
			Label: formatWithDescription(family.name, family.description),
			Nodes: make([]TreeNode, len(family.genera)),
		}

		for j, genus := range family.genera {
			genusNode := TreeNode{
				Key:   intToString(genus.id),
				Label: formatWithDescription(genus.name, genus.description),
				Nodes: make([]TreeNode, len(genus.species)),
			}

			for k, sp := range genus.species {
				genusNode.Nodes[k] = TreeNode{
					Key:   intToString(sp.id),
					Label: sp.name,
					URL:   sp.url,
				}
			}

			familyNode.Nodes[j] = genusNode
		}

		result[i] = familyNode
	}

	return result
}

// formatWithDescription formats a name with an optional description in parentheses.
func formatWithDescription(name, description string) string {
	if description == "" {
		return name
	}
	return name + " (" + description + ")"
}

// nullStringToString converts a sql.NullString to a string.
func nullStringToString(ns sql.NullString) string {
	if ns.Valid {
		return ns.String
	}
	return ""
}

// intToString converts an int64 to a string.
func intToString(n int64) string {
	return strconv.FormatInt(n, 10)
}
