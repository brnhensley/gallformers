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

// setupPlaceTestDB creates an in-memory SQLite database with place test data
func setupPlaceTestDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	// Create the schema
	schema := `
		CREATE TABLE place (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT UNIQUE NOT NULL,
			code TEXT NOT NULL,
			type TEXT NOT NULL CHECK (type IN ("continent", "country", "region", "state", "province", "county", "city"))
		);

		INSERT INTO place (id, name, code, type) VALUES
			(1, 'North America', 'NA', 'continent'),
			(2, 'United States', 'US', 'country'),
			(3, 'California', 'CA', 'state'),
			(4, 'Los Angeles County', 'LAC', 'county'),
			(5, 'Los Angeles', 'LA', 'city');
	`

	_, err = sqlDB.Exec(schema)
	if err != nil {
		t.Fatalf("failed to create test schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

func TestListPlaces(t *testing.T) {
	sqlDB, queries := setupPlaceTestDB(t)
	defer sqlDB.Close()

	handler := NewPlaceHandler(queries)

	tests := []struct {
		name           string
		queryString    string
		expectedStatus int
		expectedTotal  int64
		expectedCount  int
	}{
		{
			name:           "list all places",
			queryString:    "",
			expectedStatus: http.StatusOK,
			expectedTotal:  5,
			expectedCount:  5,
		},
		{
			name:           "search places by name - Los",
			queryString:    "?q=Los",
			expectedStatus: http.StatusOK,
			expectedTotal:  2,
			expectedCount:  2,
		},
		{
			name:           "search places by name - America",
			queryString:    "?q=America",
			expectedStatus: http.StatusOK,
			expectedTotal:  1,
			expectedCount:  1,
		},
		{
			name:           "search places - no results",
			queryString:    "?q=nonexistent",
			expectedStatus: http.StatusOK,
			expectedTotal:  0,
			expectedCount:  0,
		},
		{
			name:           "list with pagination - limit 2",
			queryString:    "?limit=2",
			expectedStatus: http.StatusOK,
			expectedTotal:  5,
			expectedCount:  2,
		},
		{
			name:           "list with pagination - limit 2 offset 4",
			queryString:    "?limit=2&offset=4",
			expectedStatus: http.StatusOK,
			expectedTotal:  5,
			expectedCount:  1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v2/places"+tc.queryString, nil)
			w := httptest.NewRecorder()

			handler.List(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			var resp PlaceListResponse
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

func TestGetPlaceByID(t *testing.T) {
	sqlDB, queries := setupPlaceTestDB(t)
	defer sqlDB.Close()

	handler := NewPlaceHandler(queries)

	tests := []struct {
		name           string
		placeID        string
		expectedStatus int
		expectedName   string
	}{
		{
			name:           "get existing place",
			placeID:        "1",
			expectedStatus: http.StatusOK,
			expectedName:   "North America",
		},
		{
			name:           "get another existing place",
			placeID:        "3",
			expectedStatus: http.StatusOK,
			expectedName:   "California",
		},
		{
			name:           "get non-existent place",
			placeID:        "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid place ID",
			placeID:        "abc",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.placeID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodGet, "/api/v2/places/"+tc.placeID, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.GetByID(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp PlaceResponse
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

func TestGetPlaceByName(t *testing.T) {
	sqlDB, queries := setupPlaceTestDB(t)
	defer sqlDB.Close()

	handler := NewPlaceHandler(queries)

	tests := []struct {
		name           string
		placeName      string
		expectedStatus int
		expectedID     int64
	}{
		{
			name:           "get existing place by name",
			placeName:      "California",
			expectedStatus: http.StatusOK,
			expectedID:     3,
		},
		{
			name:           "get non-existent place by name",
			placeName:      "Nonexistent Place",
			expectedStatus: http.StatusNotFound,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("name", tc.placeName)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			encodedName := url.PathEscape(tc.placeName)
			req := httptest.NewRequest(http.MethodGet, "/api/v2/places/by-name/"+encodedName, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.GetByName(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp PlaceResponse
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

func TestCreatePlace(t *testing.T) {
	sqlDB, queries := setupPlaceTestDB(t)
	defer sqlDB.Close()

	handler := NewPlaceHandler(queries)

	tests := []struct {
		name           string
		body           PlaceCreateRequest
		expectedStatus int
	}{
		{
			name: "create valid place",
			body: PlaceCreateRequest{
				Name: "Texas",
				Code: "TX",
				Type: "state",
			},
			expectedStatus: http.StatusCreated,
		},
		{
			name: "create place with missing name",
			body: PlaceCreateRequest{
				Code: "TX",
				Type: "state",
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "create place with missing code",
			body: PlaceCreateRequest{
				Name: "Texas",
				Type: "state",
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "create place with missing type",
			body: PlaceCreateRequest{
				Name: "Texas",
				Code: "TX",
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "create place with invalid type",
			body: PlaceCreateRequest{
				Name: "Texas",
				Code: "TX",
				Type: "invalid",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest(http.MethodPost, "/api/v2/places", bytes.NewReader(bodyBytes))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Create(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusCreated {
				var resp PlaceResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.ID == 0 {
					t.Error("expected non-zero ID")
				}

				if resp.Name != tc.body.Name {
					t.Errorf("expected name %q, got %q", tc.body.Name, resp.Name)
				}

				if resp.Code != tc.body.Code {
					t.Errorf("expected code %q, got %q", tc.body.Code, resp.Code)
				}

				if resp.Type != tc.body.Type {
					t.Errorf("expected type %q, got %q", tc.body.Type, resp.Type)
				}
			}
		})
	}
}

func TestUpdatePlace(t *testing.T) {
	sqlDB, queries := setupPlaceTestDB(t)
	defer sqlDB.Close()

	handler := NewPlaceHandler(queries)

	tests := []struct {
		name           string
		placeID        string
		body           PlaceUpdateRequest
		expectedStatus int
	}{
		{
			name:    "update existing place",
			placeID: "3",
			body: PlaceUpdateRequest{
				Name: "California Updated",
				Code: "CAL",
				Type: "state",
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:    "update non-existent place",
			placeID: "999",
			body: PlaceUpdateRequest{
				Name: "Won't Work",
				Code: "WW",
				Type: "state",
			},
			expectedStatus: http.StatusNotFound,
		},
		{
			name:    "update with missing name",
			placeID: "3",
			body: PlaceUpdateRequest{
				Code: "CA",
				Type: "state",
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:    "update with invalid type",
			placeID: "3",
			body: PlaceUpdateRequest{
				Name: "California",
				Code: "CA",
				Type: "invalid",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.placeID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest(http.MethodPut, "/api/v2/places/"+tc.placeID, bytes.NewReader(bodyBytes)).WithContext(ctx)
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Update(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusOK {
				var resp PlaceResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.Name != tc.body.Name {
					t.Errorf("expected name %q, got %q", tc.body.Name, resp.Name)
				}
			}
		})
	}
}

func TestDeletePlace(t *testing.T) {
	sqlDB, queries := setupPlaceTestDB(t)
	defer sqlDB.Close()

	handler := NewPlaceHandler(queries)

	tests := []struct {
		name           string
		placeID        string
		expectedStatus int
	}{
		{
			name:           "delete existing place",
			placeID:        "5", // Delete Los Angeles city
			expectedStatus: http.StatusNoContent,
		},
		{
			name:           "delete non-existent place",
			placeID:        "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid place ID",
			placeID:        "abc",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.placeID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodDelete, "/api/v2/places/"+tc.placeID, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.Delete(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}
		})
	}
}

func TestListPlacesOrdering(t *testing.T) {
	sqlDB, queries := setupPlaceTestDB(t)
	defer sqlDB.Close()

	handler := NewPlaceHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/places", nil)
	w := httptest.NewRecorder()
	handler.List(w, req)

	var resp PlaceListResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify alphabetical ordering by name
	expectedOrder := []string{
		"California",
		"Los Angeles",
		"Los Angeles County",
		"North America",
		"United States",
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

func TestPlaceTypeValidation(t *testing.T) {
	sqlDB, queries := setupPlaceTestDB(t)
	defer sqlDB.Close()

	handler := NewPlaceHandler(queries)

	validTypes := []string{"continent", "country", "region", "state", "province", "county", "city"}

	for _, placeType := range validTypes {
		t.Run("valid type "+placeType, func(t *testing.T) {
			body := PlaceCreateRequest{
				Name: "Test " + placeType,
				Code: "T" + placeType[:1],
				Type: placeType,
			}
			bodyBytes, _ := json.Marshal(body)
			req := httptest.NewRequest(http.MethodPost, "/api/v2/places", bytes.NewReader(bodyBytes))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Create(w, req)

			if w.Code != http.StatusCreated {
				t.Errorf("expected status %d for type %s, got %d: %s", http.StatusCreated, placeType, w.Code, w.Body.String())
			}
		})
	}
}
