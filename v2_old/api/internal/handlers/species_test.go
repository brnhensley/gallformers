package handlers_test

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	"github.com/jeffdc/gallformers/v2/api/internal/handlers"
	_ "github.com/mattn/go-sqlite3"
)

// setupTestDB creates an in-memory SQLite database with test data
func setupTestDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	// Create the schema
	schema := `
		CREATE TABLE abundance (
			id INTEGER PRIMARY KEY NOT NULL,
			abundance TEXT UNIQUE NOT NULL,
			description TEXT,
			reference TEXT
		);

		CREATE TABLE species (
			id INTEGER PRIMARY KEY NOT NULL,
			taxoncode TEXT,
			name TEXT UNIQUE NOT NULL,
			datacomplete BOOLEAN DEFAULT 0 NOT NULL,
			abundance_id INTEGER,
			FOREIGN KEY (abundance_id) REFERENCES abundance (id)
		);

		INSERT INTO abundance (id, abundance, description) VALUES
			(1, 'common', 'Frequently encountered'),
			(2, 'uncommon', 'Occasionally found'),
			(3, 'rare', 'Seldom seen');

		INSERT INTO species (id, taxoncode, name, datacomplete, abundance_id) VALUES
			(1, 'gall', 'Andricus quercuscalifornicus', 1, 1),
			(2, 'gall', 'Belonocnema treatae', 0, 2),
			(3, 'plant', 'Quercus lobata', 1, 1),
			(4, 'gall', 'Callirhytis quercuspomiformis', 0, NULL),
			(5, 'plant', 'Quercus agrifolia', 1, 1);
	`

	_, err = sqlDB.Exec(schema)
	if err != nil {
		t.Fatalf("failed to create test schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

func TestListSpecies(t *testing.T) {
	sqlDB, queries := setupTestDB(t)
	defer sqlDB.Close()

	r := chi.NewRouter()
	r.Get("/api/v2/species", handlers.ListSpecies(queries))

	tests := []struct {
		name           string
		queryString    string
		expectedStatus int
		expectedTotal  int64
		expectedCount  int
	}{
		{
			name:           "list all species",
			queryString:    "",
			expectedStatus: http.StatusOK,
			expectedTotal:  5,
			expectedCount:  5,
		},
		{
			name:           "search species by name - Andricus",
			queryString:    "?q=Andricus",
			expectedStatus: http.StatusOK,
			expectedTotal:  1,
			expectedCount:  1,
		},
		{
			name:           "search species by name - Quercus",
			queryString:    "?q=Quercus",
			expectedStatus: http.StatusOK,
			expectedTotal:  4, // Matches Quercus in name and quercus in scientific names
			expectedCount:  4,
		},
		{
			name:           "search species - no results",
			queryString:    "?q=nonexistent",
			expectedStatus: http.StatusOK,
			expectedTotal:  0,
			expectedCount:  0,
		},
		{
			name:           "search species - partial match",
			queryString:    "?q=gri",
			expectedStatus: http.StatusOK,
			expectedTotal:  1,
			expectedCount:  1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v2/species"+tc.queryString, nil)
			w := httptest.NewRecorder()

			r.ServeHTTP(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			var resp handlers.SpeciesListResponse
			if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
				t.Fatalf("failed to unmarshal response: %v", err)
			}

			if resp.Total != tc.expectedTotal {
				t.Errorf("expected total %d, got %d", tc.expectedTotal, resp.Total)
			}

			if len(resp.Data) != tc.expectedCount {
				t.Errorf("expected %d results, got %d", tc.expectedCount, len(resp.Data))
			}
		})
	}
}

func TestGetSpecies(t *testing.T) {
	sqlDB, queries := setupTestDB(t)
	defer sqlDB.Close()

	r := chi.NewRouter()
	r.Get("/api/v2/species/{id}", handlers.GetSpecies(queries))

	tests := []struct {
		name           string
		speciesID      string
		expectedStatus int
		expectedName   string
	}{
		{
			name:           "get existing species",
			speciesID:      "1",
			expectedStatus: http.StatusOK,
			expectedName:   "Andricus quercuscalifornicus",
		},
		{
			name:           "get another existing species",
			speciesID:      "3",
			expectedStatus: http.StatusOK,
			expectedName:   "Quercus lobata",
		},
		{
			name:           "get non-existent species",
			speciesID:      "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid species ID",
			speciesID:      "abc",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v2/species/"+tc.speciesID, nil)
			w := httptest.NewRecorder()

			r.ServeHTTP(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp handlers.SpeciesResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.Name != tc.expectedName {
					t.Errorf("expected name %q, got %q", tc.expectedName, resp.Name)
				}
			}
		})
	}
}

func TestGetSpeciesWithAbundance(t *testing.T) {
	sqlDB, queries := setupTestDB(t)
	defer sqlDB.Close()

	r := chi.NewRouter()
	r.Get("/api/v2/species/{id}", handlers.GetSpecies(queries))

	// Test species with abundance
	req := httptest.NewRequest(http.MethodGet, "/api/v2/species/1", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp handlers.SpeciesResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Abundance == nil {
		t.Error("expected abundance to be set")
	} else if *resp.Abundance != "common" {
		t.Errorf("expected abundance 'common', got %q", *resp.Abundance)
	}

	// Test species without abundance
	req = httptest.NewRequest(http.MethodGet, "/api/v2/species/4", nil)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var respNoAbundance handlers.SpeciesResponse
	if err := json.Unmarshal(w.Body.Bytes(), &respNoAbundance); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if respNoAbundance.Abundance != nil {
		t.Errorf("expected abundance to be nil, got %v", respNoAbundance.Abundance)
	}
}

func TestListSpeciesOrdering(t *testing.T) {
	sqlDB, queries := setupTestDB(t)
	defer sqlDB.Close()

	r := chi.NewRouter()
	r.Get("/api/v2/species", handlers.ListSpecies(queries))

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	var resp handlers.SpeciesListResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify alphabetical ordering
	expectedOrder := []string{
		"Andricus quercuscalifornicus",
		"Belonocnema treatae",
		"Callirhytis quercuspomiformis",
		"Quercus agrifolia",
		"Quercus lobata",
	}

	if len(resp.Data) != len(expectedOrder) {
		t.Fatalf("expected %d results, got %d", len(expectedOrder), len(resp.Data))
	}

	for i, expected := range expectedOrder {
		if resp.Data[i].Name != expected {
			t.Errorf("position %d: expected %q, got %q", i, expected, resp.Data[i].Name)
		}
	}
}
