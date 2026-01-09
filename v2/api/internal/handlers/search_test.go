package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	_ "github.com/mattn/go-sqlite3"
)

// setupSearchTestDB creates an in-memory SQLite database with test data for global search
func setupSearchTestDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	// Create the schema with test data
	schema := `
		-- Species table
		CREATE TABLE species (
			id INTEGER PRIMARY KEY NOT NULL,
			taxoncode TEXT,
			name TEXT NOT NULL UNIQUE,
			datacomplete INTEGER DEFAULT 0,
			abundance_id INTEGER
		);

		-- Alias table
		CREATE TABLE alias (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT NOT NULL,
			type TEXT NOT NULL CHECK (type = 'common' OR type = 'scientific'),
			description TEXT NOT NULL DEFAULT ''
		);

		-- Alias-Species join table
		CREATE TABLE aliasspecies (
			species_id INTEGER NOT NULL,
			alias_id INTEGER NOT NULL,
			FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
			FOREIGN KEY (alias_id) REFERENCES alias (id) ON DELETE CASCADE,
			PRIMARY KEY (species_id, alias_id)
		);

		-- Glossary table
		CREATE TABLE glossary (
			id INTEGER PRIMARY KEY NOT NULL,
			word TEXT UNIQUE NOT NULL,
			definition TEXT NOT NULL,
			urls TEXT NOT NULL
		);

		-- Source table
		CREATE TABLE source (
			id INTEGER PRIMARY KEY NOT NULL,
			title TEXT NOT NULL,
			author TEXT NOT NULL,
			pubyear TEXT NOT NULL,
			link TEXT NOT NULL,
			citation TEXT NOT NULL,
			datacomplete INTEGER DEFAULT 0,
			license TEXT NOT NULL,
			licenselink TEXT NOT NULL
		);

		-- Taxonomy table
		CREATE TABLE taxonomy (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT NOT NULL,
			description TEXT,
			type TEXT NOT NULL,
			parent_id INTEGER
		);

		-- Place table
		CREATE TABLE place (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT NOT NULL,
			code TEXT NOT NULL,
			type TEXT NOT NULL
		);

		-- Insert test species
		INSERT INTO species (id, taxoncode, name, datacomplete) VALUES
			(1, 'gall', 'Andricus quercuscalifornicus', 1),
			(2, 'gall', 'Cynips douglasii', 0),
			(3, 'plant', 'Quercus lobata', 1),
			(4, 'plant', 'Quercus agrifolia', 1);

		-- Insert test aliases
		INSERT INTO alias (id, name, type, description) VALUES
			(1, 'California gall wasp', 'common', ''),
			(2, 'Valley oak', 'common', ''),
			(3, 'Coast live oak', 'common', '');

		-- Link aliases to species
		INSERT INTO aliasspecies (species_id, alias_id) VALUES
			(1, 1),
			(3, 2),
			(4, 3);

		-- Insert test glossary entries
		INSERT INTO glossary (id, word, definition, urls) VALUES
			(1, 'gall', 'An abnormal plant growth caused by insects', 'https://example.com'),
			(2, 'cecidium', 'A gall or plant tumor', ''),
			(3, 'oak', 'A tree or shrub of the genus Quercus', '');

		-- Insert test sources
		INSERT INTO source (id, title, author, pubyear, link, citation, datacomplete, license, licenselink) VALUES
			(1, 'Gall Biology', 'Smith, John', '2020', '', '', 1, '', ''),
			(2, 'Oak Galls of California', 'Johnson, Mary', '2018', '', '', 0, '', ''),
			(3, 'Plant Physiology', 'Williams, Bob', '2015', '', '', 1, '', '');

		-- Insert test taxonomy entries
		INSERT INTO taxonomy (id, name, description, type, parent_id) VALUES
			(1, 'Fagaceae', 'Oak family', 'family', NULL),
			(2, 'Quercus', 'Oak genus', 'genus', 1),
			(3, 'Lobatae', 'Red oaks section', 'section', 2);

		-- Insert test places
		INSERT INTO place (id, name, code, type) VALUES
			(1, 'California', 'CA', 'state'),
			(2, 'Oregon', 'OR', 'state'),
			(3, 'United States', 'US', 'country');
	`

	_, err = sqlDB.Exec(schema)
	if err != nil {
		t.Fatalf("failed to create test schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

func TestGlobalSearch(t *testing.T) {
	sqlDB, queries := setupSearchTestDB(t)
	defer sqlDB.Close()

	handler := NewSearchHandler(queries)

	tests := []struct {
		name             string
		queryString      string
		expectedStatus   int
		expectedSpecies  int
		expectedGlossary int
		expectedSources  int
		expectedTaxa     int
		expectedPlaces   int
	}{
		{
			name:             "search for 'gall' - matches species, glossary, sources",
			queryString:      "?q=gall",
			expectedStatus:   http.StatusOK,
			expectedSpecies:  1, // matches "Andricus quercuscalifornicus" via alias "California gall wasp"
			expectedGlossary: 2, // matches "gall" (exact) and "cecidium" (definition contains "gall")
			expectedSources:  2, // matches "Gall Biology" and "Oak Galls of California"
			expectedTaxa:     0,
			expectedPlaces:   0,
		},
		{
			name:             "search for 'oak' - matches species, glossary, sources, taxa",
			queryString:      "?q=oak",
			expectedStatus:   http.StatusOK,
			expectedSpecies:  2, // "Valley oak" alias and "Coast live oak" alias
			expectedGlossary: 1, // matches "oak" (exact)
			expectedSources:  1, // matches "Oak Galls of California"
			expectedTaxa:     3, // matches "Oak family", "Oak genus", "Red oaks section" (all have "oak" in description)
			expectedPlaces:   0,
		},
		{
			name:             "search for 'Quercus' - matches species names and taxonomy",
			queryString:      "?q=Quercus",
			expectedStatus:   http.StatusOK,
			expectedSpecies:  3, // matches via alias search too (California gall wasp alias includes "Quercus" in related species)
			expectedGlossary: 1, // matches "oak" (definition contains "Quercus")
			expectedSources:  0,
			expectedTaxa:     1, // matches "Quercus" genus
			expectedPlaces:   0,
		},
		{
			name:             "search for 'California' - matches species alias and places",
			queryString:      "?q=California",
			expectedStatus:   http.StatusOK,
			expectedSpecies:  1, // "California gall wasp" alias
			expectedGlossary: 0,
			expectedSources:  1, // "Oak Galls of California"
			expectedTaxa:     0,
			expectedPlaces:   1, // "California"
		},
		{
			name:             "search for 'lobata' - specific species name",
			queryString:      "?q=lobata",
			expectedStatus:   http.StatusOK,
			expectedSpecies:  1, // "Quercus lobata"
			expectedGlossary: 0,
			expectedSources:  0,
			expectedTaxa:     1, // "Lobatae" section
			expectedPlaces:   0,
		},
		{
			name:             "search for 'Smith' - matches source author",
			queryString:      "?q=Smith",
			expectedStatus:   http.StatusOK,
			expectedSpecies:  0,
			expectedGlossary: 0,
			expectedSources:  1, // "Gall Biology" by Smith
			expectedTaxa:     0,
			expectedPlaces:   0,
		},
		{
			name:             "search with no results",
			queryString:      "?q=xyz123nonexistent",
			expectedStatus:   http.StatusOK,
			expectedSpecies:  0,
			expectedGlossary: 0,
			expectedSources:  0,
			expectedTaxa:     0,
			expectedPlaces:   0,
		},
		{
			name:           "search with missing query parameter",
			queryString:    "",
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "search with empty query",
			queryString:    "?q=",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v2/search"+tc.queryString, nil)
			w := httptest.NewRecorder()

			handler.Search(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusOK {
				var resp GlobalSearchResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if len(resp.Species) != tc.expectedSpecies {
					t.Errorf("expected %d species, got %d", tc.expectedSpecies, len(resp.Species))
				}

				if len(resp.Glossary) != tc.expectedGlossary {
					t.Errorf("expected %d glossary entries, got %d", tc.expectedGlossary, len(resp.Glossary))
				}

				if len(resp.Sources) != tc.expectedSources {
					t.Errorf("expected %d sources, got %d", tc.expectedSources, len(resp.Sources))
				}

				if len(resp.Taxa) != tc.expectedTaxa {
					t.Errorf("expected %d taxa, got %d", tc.expectedTaxa, len(resp.Taxa))
				}

				if len(resp.Places) != tc.expectedPlaces {
					t.Errorf("expected %d places, got %d", tc.expectedPlaces, len(resp.Places))
				}
			}
		})
	}
}

func TestGlobalSearchSpeciesIncludesAliases(t *testing.T) {
	sqlDB, queries := setupSearchTestDB(t)
	defer sqlDB.Close()

	handler := NewSearchHandler(queries)

	// Search for something that matches a species with an alias
	req := httptest.NewRequest(http.MethodGet, "/api/v2/search?q=quercuscalifornicus", nil)
	w := httptest.NewRecorder()

	handler.Search(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp GlobalSearchResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if len(resp.Species) != 1 {
		t.Fatalf("expected 1 species, got %d", len(resp.Species))
	}

	species := resp.Species[0]
	if species.Name != "Andricus quercuscalifornicus" {
		t.Errorf("expected species name 'Andricus quercuscalifornicus', got %q", species.Name)
	}

	if species.Taxoncode != "gall" {
		t.Errorf("expected taxoncode 'gall', got %q", species.Taxoncode)
	}

	// Verify aliases are included
	if len(species.Aliases) != 1 {
		t.Fatalf("expected 1 alias, got %d", len(species.Aliases))
	}

	if species.Aliases[0] != "California gall wasp" {
		t.Errorf("expected alias 'California gall wasp', got %q", species.Aliases[0])
	}
}

func TestGlobalSearchSourceFormatting(t *testing.T) {
	sqlDB, queries := setupSearchTestDB(t)
	defer sqlDB.Close()

	handler := NewSearchHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/search?q=Gall%20Biology", nil)
	w := httptest.NewRecorder()

	handler.Search(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp GlobalSearchResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if len(resp.Sources) != 1 {
		t.Fatalf("expected 1 source, got %d", len(resp.Sources))
	}

	source := resp.Sources[0]
	// The Source field should be formatted as "author, year. title"
	expectedFormat := "Smith, John, 2020. Gall Biology"
	if source.Source != expectedFormat {
		t.Errorf("expected source format %q, got %q", expectedFormat, source.Source)
	}
}

func TestGlobalSearchTaxonomyTypes(t *testing.T) {
	sqlDB, queries := setupSearchTestDB(t)
	defer sqlDB.Close()

	handler := NewSearchHandler(queries)

	// Search for something that matches different taxonomy types
	req := httptest.NewRequest(http.MethodGet, "/api/v2/search?q=oak", nil)
	w := httptest.NewRecorder()

	handler.Search(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp GlobalSearchResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify we get family, genus, and section (all have "oak" in description)
	if len(resp.Taxa) != 3 {
		t.Fatalf("expected 3 taxa, got %d", len(resp.Taxa))
	}

	// Find the family, genus, and section entries
	var foundFamily, foundGenus, foundSection bool
	for _, tax := range resp.Taxa {
		switch tax.Type {
		case "family":
			foundFamily = true
			if tax.Name != "Fagaceae" {
				t.Errorf("expected family name 'Fagaceae', got %q", tax.Name)
			}
		case "genus":
			foundGenus = true
			if tax.Name != "Quercus" {
				t.Errorf("expected genus name 'Quercus', got %q", tax.Name)
			}
		case "section":
			foundSection = true
			if tax.Name != "Lobatae" {
				t.Errorf("expected section name 'Lobatae', got %q", tax.Name)
			}
		}
	}

	if !foundFamily {
		t.Error("expected to find family in results")
	}
	if !foundGenus {
		t.Error("expected to find genus in results")
	}
	if !foundSection {
		t.Error("expected to find section in results")
	}
}

func TestGlobalSearchGlossaryFiltering(t *testing.T) {
	sqlDB, queries := setupSearchTestDB(t)
	defer sqlDB.Close()

	handler := NewSearchHandler(queries)

	// Test exact word match - "gall" matches as exact word AND "cecidium" (definition contains "gall")
	req := httptest.NewRequest(http.MethodGet, "/api/v2/search?q=gall", nil)
	w := httptest.NewRecorder()

	handler.Search(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp GlobalSearchResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Should match "gall" (exact word) and "cecidium" (definition contains "gall")
	if len(resp.Glossary) != 2 {
		t.Fatalf("expected 2 glossary entries, got %d", len(resp.Glossary))
	}

	// Verify both entries are present
	foundGall, foundCecidium := false, false
	for _, entry := range resp.Glossary {
		if entry.Word == "gall" {
			foundGall = true
		}
		if entry.Word == "cecidium" {
			foundCecidium = true
		}
	}
	if !foundGall {
		t.Error("expected to find 'gall' in results")
	}
	if !foundCecidium {
		t.Error("expected to find 'cecidium' in results (definition contains 'gall')")
	}

	// Test definition contains match
	req2 := httptest.NewRequest(http.MethodGet, "/api/v2/search?q=plant", nil)
	w2 := httptest.NewRecorder()

	handler.Search(w2, req2)

	if w2.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w2.Code)
	}

	var resp2 GlobalSearchResponse
	if err := json.Unmarshal(w2.Body.Bytes(), &resp2); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Should match "gall" (definition contains "plant") and "cecidium" (definition contains "plant")
	if len(resp2.Glossary) != 2 {
		t.Errorf("expected 2 glossary entries (with 'plant' in definition), got %d", len(resp2.Glossary))
	}
}

func TestGlobalSearchSpaceHandling(t *testing.T) {
	sqlDB, queries := setupSearchTestDB(t)
	defer sqlDB.Close()

	handler := NewSearchHandler(queries)

	// Search with spaces (should be converted to % for LIKE matching)
	req := httptest.NewRequest(http.MethodGet, "/api/v2/search?q=Quercus+lobata", nil)
	w := httptest.NewRecorder()

	handler.Search(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp GlobalSearchResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Should match "Quercus lobata" species
	if len(resp.Species) < 1 {
		t.Error("expected at least 1 species matching 'Quercus lobata'")
	}
}

func TestGlobalSearchEmptyArraysNotNull(t *testing.T) {
	sqlDB, queries := setupSearchTestDB(t)
	defer sqlDB.Close()

	handler := NewSearchHandler(queries)

	// Search for something that won't match anything
	req := httptest.NewRequest(http.MethodGet, "/api/v2/search?q=xyz123nonexistent", nil)
	w := httptest.NewRecorder()

	handler.Search(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	// Verify the response contains empty arrays, not null
	bodyStr := w.Body.String()
	if bodyStr == "" {
		t.Fatal("expected non-empty response body")
	}

	var resp GlobalSearchResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// All arrays should be empty but not nil
	if resp.Species == nil {
		t.Error("expected species to be empty array, got nil")
	}
	if resp.Glossary == nil {
		t.Error("expected glossary to be empty array, got nil")
	}
	if resp.Sources == nil {
		t.Error("expected sources to be empty array, got nil")
	}
	if resp.Taxa == nil {
		t.Error("expected taxa to be empty array, got nil")
	}
	if resp.Places == nil {
		t.Error("expected places to be empty array, got nil")
	}
}
