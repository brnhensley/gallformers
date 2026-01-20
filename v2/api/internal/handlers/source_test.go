package handlers

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	_ "github.com/mattn/go-sqlite3"
)

// setupSourceTestDB creates an in-memory SQLite database with source test data
func setupSourceTestDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	// Create the schema
	schema := `
		CREATE TABLE source (
			id INTEGER PRIMARY KEY NOT NULL,
			title TEXT UNIQUE NOT NULL,
			author TEXT NOT NULL,
			pubyear TEXT NOT NULL,
			link TEXT NOT NULL,
			citation TEXT NOT NULL,
			datacomplete BOOLEAN DEFAULT 0 NOT NULL,
			license TEXT DEFAULT '' NOT NULL,
			licenselink TEXT DEFAULT '' NOT NULL
		);

		CREATE TABLE species (
			id INTEGER PRIMARY KEY NOT NULL,
			taxoncode TEXT,
			name TEXT UNIQUE NOT NULL,
			datacomplete BOOLEAN DEFAULT 0 NOT NULL,
			abundance_id INTEGER
		);

		CREATE TABLE speciessource (
			id INTEGER PRIMARY KEY NOT NULL,
			species_id INTEGER NOT NULL,
			source_id INTEGER NOT NULL,
			description TEXT DEFAULT '' NOT NULL,
			useasdefault INTEGER DEFAULT 0 NOT NULL,
			externallink TEXT DEFAULT '' NOT NULL,
			alias_id INTEGER,
			FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
			FOREIGN KEY (source_id) REFERENCES source (id) ON DELETE CASCADE
		);

		INSERT INTO source (id, title, author, pubyear, link, citation, datacomplete, license, licenselink) VALUES
			(1, 'Plant Galls of North America', 'Russo, R.', '2021', 'https://example.com/book1', 'Russo, R. (2021). Plant Galls of North America.', 1, 'CC BY', 'https://creativecommons.org/licenses/by/4.0/'),
			(2, 'Cynipid Galls of the Western United States', 'Kinsey, A.C.', '1930', 'https://example.com/book2', 'Kinsey, A.C. (1930). Cynipid Galls.', 0, '', ''),
			(3, 'Gallformers Database', 'Gallformers Team', '2024', 'https://gallformers.org', 'Gallformers Database (2024).', 1, 'CC BY-NC', 'https://creativecommons.org/licenses/by-nc/4.0/');

		INSERT INTO species (id, taxoncode, name, datacomplete) VALUES
			(1, 'gall', 'Andricus quercuscalifornicus', 1),
			(2, 'gall', 'Belonocnema treatae', 0);

		INSERT INTO speciessource (id, species_id, source_id, description, useasdefault, externallink) VALUES
			(1, 1, 1, 'Primary source', 1, 'https://example.com/link1'),
			(2, 1, 2, 'Historical reference', 0, ''),
			(3, 2, 1, 'Description source', 1, '');
	`

	_, err = sqlDB.Exec(schema)
	if err != nil {
		t.Fatalf("failed to create test schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

func TestListSources(t *testing.T) {
	sqlDB, queries := setupSourceTestDB(t)
	defer sqlDB.Close()

	handler := NewSourceHandler(queries)

	tests := []struct {
		name           string
		queryString    string
		expectedStatus int
		expectedTotal  int64
		expectedCount  int
	}{
		{
			name:           "list all sources",
			queryString:    "",
			expectedStatus: http.StatusOK,
			expectedTotal:  3,
			expectedCount:  3,
		},
		{
			name:           "search sources by title - Galls",
			queryString:    "?q=Galls",
			expectedStatus: http.StatusOK,
			expectedTotal:  2,
			expectedCount:  2,
		},
		{
			name:           "search sources by title - Gallformers",
			queryString:    "?q=Gallformers",
			expectedStatus: http.StatusOK,
			expectedTotal:  1,
			expectedCount:  1,
		},
		{
			name:           "search sources - no results",
			queryString:    "?q=nonexistent",
			expectedStatus: http.StatusOK,
			expectedTotal:  0,
			expectedCount:  0,
		},
		{
			name:           "list with pagination - limit 2",
			queryString:    "?limit=2",
			expectedStatus: http.StatusOK,
			expectedTotal:  3,
			expectedCount:  2,
		},
		{
			name:           "list with pagination - limit 2 offset 2",
			queryString:    "?limit=2&offset=2",
			expectedStatus: http.StatusOK,
			expectedTotal:  3,
			expectedCount:  1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v2/sources"+tc.queryString, nil)
			w := httptest.NewRecorder()

			handler.List(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			var resp SourceListResponse
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

func TestListSourcesBySpeciesID(t *testing.T) {
	sqlDB, queries := setupSourceTestDB(t)
	defer sqlDB.Close()

	handler := NewSourceHandler(queries)

	tests := []struct {
		name           string
		speciesID      string
		expectedStatus int
		expectedCount  int
	}{
		{
			name:           "get sources for species 1",
			speciesID:      "1",
			expectedStatus: http.StatusOK,
			expectedCount:  2, // Species 1 has 2 sources
		},
		{
			name:           "get sources for species 2",
			speciesID:      "2",
			expectedStatus: http.StatusOK,
			expectedCount:  1, // Species 2 has 1 source
		},
		{
			name:           "get sources for non-existent species",
			speciesID:      "999",
			expectedStatus: http.StatusOK,
			expectedCount:  0,
		},
		{
			name:           "invalid species ID",
			speciesID:      "abc",
			expectedStatus: http.StatusBadRequest,
			expectedCount:  0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v2/sources?speciesid="+tc.speciesID, nil)
			w := httptest.NewRecorder()

			handler.List(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp []SourceWithSpeciesSourceResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if len(resp) != tc.expectedCount {
					t.Errorf("expected %d results, got %d", tc.expectedCount, len(resp))
				}

				// Verify speciessource info is included
				if len(resp) > 0 {
					if resp[0].SpeciesSource.ID == 0 {
						t.Error("expected speciessource ID to be set")
					}
				}
			}
		})
	}
}

func TestGetSourceByID(t *testing.T) {
	sqlDB, queries := setupSourceTestDB(t)
	defer sqlDB.Close()

	handler := NewSourceHandler(queries)

	tests := []struct {
		name           string
		sourceID       string
		expectedStatus int
		expectedTitle  string
	}{
		{
			name:           "get existing source",
			sourceID:       "1",
			expectedStatus: http.StatusOK,
			expectedTitle:  "Plant Galls of North America",
		},
		{
			name:           "get another existing source",
			sourceID:       "2",
			expectedStatus: http.StatusOK,
			expectedTitle:  "Cynipid Galls of the Western United States",
		},
		{
			name:           "get non-existent source",
			sourceID:       "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid source ID",
			sourceID:       "abc",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.sourceID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodGet, "/api/v2/sources/"+tc.sourceID, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.GetByID(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp SourceResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.Title != tc.expectedTitle {
					t.Errorf("expected title %q, got %q", tc.expectedTitle, resp.Title)
				}
			}
		})
	}
}

func TestGetSourceByTitle(t *testing.T) {
	sqlDB, queries := setupSourceTestDB(t)
	defer sqlDB.Close()

	handler := NewSourceHandler(queries)

	tests := []struct {
		name           string
		title          string
		expectedStatus int
		expectedID     int64
	}{
		{
			name:           "get existing source by title",
			title:          "Plant Galls of North America",
			expectedStatus: http.StatusOK,
			expectedID:     1,
		},
		{
			name:           "get non-existent source by title",
			title:          "Nonexistent Book",
			expectedStatus: http.StatusNotFound,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("title", tc.title)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			encodedTitle := url.PathEscape(tc.title)
			req := httptest.NewRequest(http.MethodGet, "/api/v2/sources/by-title/"+encodedTitle, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.GetByTitle(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp SourceResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.ID != tc.expectedID {
					t.Errorf("expected ID %d, got %d", tc.expectedID, resp.ID)
				}
			}
		})
	}
}

func TestCreateSource(t *testing.T) {
	sqlDB, queries := setupSourceTestDB(t)
	defer sqlDB.Close()

	handler := NewSourceHandler(queries)

	tests := []struct {
		name           string
		body           SourceCreateRequest
		expectedStatus int
	}{
		{
			name: "create valid source",
			body: SourceCreateRequest{
				Title:        "New Test Source",
				Author:       "Test Author",
				Pubyear:      "2024",
				Link:         "https://example.com/new",
				Citation:     "Test Author (2024). New Test Source.",
				Datacomplete: true,
				License:      "CC BY",
				Licenselink:  "https://creativecommons.org/licenses/by/4.0/",
			},
			expectedStatus: http.StatusCreated,
		},
		{
			name: "create source with missing title",
			body: SourceCreateRequest{
				Author:  "Test Author",
				Pubyear: "2024",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest(http.MethodPost, "/api/v2/sources", bytes.NewReader(bodyBytes))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Create(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusCreated {
				var resp SourceResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.ID == 0 {
					t.Error("expected non-zero ID")
				}

				if resp.Title != tc.body.Title {
					t.Errorf("expected title %q, got %q", tc.body.Title, resp.Title)
				}
			}
		})
	}
}

func TestUpdateSource(t *testing.T) {
	sqlDB, queries := setupSourceTestDB(t)
	defer sqlDB.Close()

	handler := NewSourceHandler(queries)

	tests := []struct {
		name           string
		sourceID       string
		body           SourceUpdateRequest
		expectedStatus int
	}{
		{
			name:     "update existing source",
			sourceID: "1",
			body: SourceUpdateRequest{
				Title:        "Updated Title",
				Author:       "Updated Author",
				Pubyear:      "2025",
				Link:         "https://example.com/updated",
				Citation:     "Updated Author (2025). Updated Title.",
				Datacomplete: true,
				License:      "CC BY-SA",
				Licenselink:  "https://creativecommons.org/licenses/by-sa/4.0/",
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:     "update non-existent source",
			sourceID: "999",
			body: SourceUpdateRequest{
				Title: "Won't Work",
			},
			expectedStatus: http.StatusNotFound,
		},
		{
			name:     "update with missing title",
			sourceID: "2",
			body: SourceUpdateRequest{
				Author: "Some Author",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.sourceID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest(http.MethodPut, "/api/v2/sources/"+tc.sourceID, bytes.NewReader(bodyBytes)).WithContext(ctx)
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Update(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusOK {
				var resp SourceResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.Title != tc.body.Title {
					t.Errorf("expected title %q, got %q", tc.body.Title, resp.Title)
				}
			}
		})
	}
}

func TestDeleteSource(t *testing.T) {
	sqlDB, queries := setupSourceTestDB(t)
	defer sqlDB.Close()

	handler := NewSourceHandler(queries)

	tests := []struct {
		name           string
		sourceID       string
		expectedStatus int
	}{
		{
			name:           "delete existing source",
			sourceID:       "3", // Delete source 3 which has no speciessource links
			expectedStatus: http.StatusNoContent,
		},
		{
			name:           "delete non-existent source",
			sourceID:       "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid source ID",
			sourceID:       "abc",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.sourceID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodDelete, "/api/v2/sources/"+tc.sourceID, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.Delete(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}
		})
	}
}

func TestListSourcesOrdering(t *testing.T) {
	sqlDB, queries := setupSourceTestDB(t)
	defer sqlDB.Close()

	handler := NewSourceHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/sources", nil)
	w := httptest.NewRecorder()
	handler.List(w, req)

	var resp SourceListResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify alphabetical ordering by title
	expectedOrder := []string{
		"Cynipid Galls of the Western United States",
		"Gallformers Database",
		"Plant Galls of North America",
	}

	if len(resp.Data) != len(expectedOrder) {
		t.Fatalf("expected %d results, got %d", len(expectedOrder), len(resp.Data))
	}

	for i, expected := range expectedOrder {
		if resp.Data[i].Title != expected {
			t.Errorf("position %d: expected %q, got %q", i, expected, resp.Data[i].Title)
		}
	}
}
