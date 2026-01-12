//go:build integration
// +build integration

package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/go-chi/chi/v5"
	_ "github.com/mattn/go-sqlite3"
)

// Integration tests for SpeciesSource handler compare v2 API responses with expected behavior.
// Run with: go test -tags=integration ./internal/handlers/... -run SpeciesSource

func TestIntegration_ListSpeciesSources_ReturnsResults(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	// Find a species that has sources in the production database
	// First, let's find any species-source relationship
	var speciesID int64
	err := sqlDB.QueryRow(`
		SELECT DISTINCT species_id
		FROM speciessource
		LIMIT 1
	`).Scan(&speciesID)
	if err != nil {
		t.Skipf("no species-source relationships in database: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid="+itoa(speciesID), nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response []SpeciesSourceResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) == 0 {
		t.Error("expected at least one species-source relationship")
	}

	// Verify response structure
	if len(response) > 0 {
		first := response[0]
		if first.ID <= 0 {
			t.Error("expected positive ID")
		}
		if first.SpeciesID != speciesID {
			t.Errorf("expected species_id %d, got %d", speciesID, first.SpeciesID)
		}
		if first.SourceID <= 0 {
			t.Error("expected positive source_id")
		}
		if first.Source == nil {
			t.Error("expected source to be populated")
		}
		if first.Source != nil && first.Source.Title == "" {
			t.Error("expected source title to be non-empty")
		}
	}
}

func TestIntegration_GetSpeciesSource_SingleMapping(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	// Find a specific species-source relationship
	var speciesID, sourceID int64
	err := sqlDB.QueryRow(`
		SELECT species_id, source_id
		FROM speciessource
		LIMIT 1
	`).Scan(&speciesID, &sourceID)
	if err != nil {
		t.Skipf("no species-source relationships in database: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid="+itoa(speciesID)+"&sourceid="+itoa(sourceID), nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response SpeciesSourceResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.SpeciesID != speciesID {
		t.Errorf("expected species_id %d, got %d", speciesID, response.SpeciesID)
	}
	if response.SourceID != sourceID {
		t.Errorf("expected source_id %d, got %d", sourceID, response.SourceID)
	}
	if response.Source == nil {
		t.Error("expected source to be populated")
	}
}

func TestIntegration_ListSpeciesSources_NotFound(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	// Use non-existent IDs
	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=999999&sourceid=999999", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestIntegration_ListSpeciesSources_EmptyForNonExistentSpecies(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	// Use non-existent species ID (without source ID, should return empty list)
	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=999999", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response []SpeciesSourceResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) != 0 {
		t.Errorf("expected empty list for non-existent species, got %d items", len(response))
	}
}

func TestIntegration_SpeciesSource_RegisterRoutes(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	r := chi.NewRouter()
	r.Route("/api/v2", func(r chi.Router) {
		handler.RegisterRoutes(r)
	})

	// Find a species with sources
	var speciesID int64
	err := sqlDB.QueryRow(`
		SELECT DISTINCT species_id
		FROM speciessource
		LIMIT 1
	`).Scan(&speciesID)
	if err != nil {
		t.Skipf("no species-source relationships in database: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid="+itoa(speciesID), nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}

func TestIntegration_ListSpeciesSources_OrderByCitation(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	// Find a species that has multiple sources
	var speciesID int64
	err := sqlDB.QueryRow(`
		SELECT species_id
		FROM speciessource
		GROUP BY species_id
		HAVING COUNT(*) > 1
		LIMIT 1
	`).Scan(&speciesID)
	if err != nil {
		t.Skipf("no species with multiple sources in database: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid="+itoa(speciesID), nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response []SpeciesSourceResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) < 2 {
		t.Skipf("expected at least 2 sources, got %d", len(response))
	}

	// Verify sources are ordered by citation (which is included in Source)
	// The SQL orders by source.citation
	for i := 1; i < len(response); i++ {
		prev := response[i-1].Source
		curr := response[i].Source
		if prev != nil && curr != nil {
			if prev.Citation > curr.Citation {
				t.Errorf("sources not ordered by citation: %s > %s", prev.Citation, curr.Citation)
			}
		}
	}
}

// Helper function to convert int64 to string
func itoa(n int64) string {
	return strconv.FormatInt(n, 10)
}
