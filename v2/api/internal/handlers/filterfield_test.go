package handlers

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	_ "github.com/mattn/go-sqlite3"
)

// setupFilterFieldTestDB creates an in-memory SQLite database with filter field test data
func setupFilterFieldTestDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	// Create the schema for filter field tables
	schema := `
		CREATE TABLE color (
			id INTEGER PRIMARY KEY NOT NULL,
			color TEXT UNIQUE NOT NULL
		);

		CREATE TABLE shape (
			id INTEGER PRIMARY KEY NOT NULL,
			shape TEXT UNIQUE NOT NULL,
			description TEXT
		);

		CREATE TABLE location (
			id INTEGER PRIMARY KEY NOT NULL,
			location TEXT UNIQUE NOT NULL,
			description TEXT
		);

		CREATE TABLE texture (
			id INTEGER PRIMARY KEY NOT NULL,
			texture TEXT UNIQUE NOT NULL,
			description TEXT
		);

		CREATE TABLE walls (
			id INTEGER PRIMARY KEY NOT NULL,
			walls TEXT UNIQUE NOT NULL,
			description TEXT
		);

		CREATE TABLE cells (
			id INTEGER PRIMARY KEY NOT NULL,
			cells TEXT UNIQUE NOT NULL,
			description TEXT
		);

		CREATE TABLE alignment (
			id INTEGER PRIMARY KEY NOT NULL,
			alignment TEXT UNIQUE NOT NULL,
			description TEXT
		);

		CREATE TABLE season (
			id INTEGER PRIMARY KEY NOT NULL,
			season TEXT UNIQUE NOT NULL
		);

		CREATE TABLE form (
			id INTEGER PRIMARY KEY NOT NULL,
			form TEXT UNIQUE NOT NULL,
			description TEXT
		);

		CREATE TABLE abundance (
			id INTEGER PRIMARY KEY NOT NULL,
			abundance TEXT UNIQUE NOT NULL,
			description TEXT,
			reference TEXT
		);

		-- Insert test data
		INSERT INTO color (id, color) VALUES
			(1, 'red'),
			(2, 'green'),
			(3, 'brown');

		INSERT INTO shape (id, shape, description) VALUES
			(1, 'spherical', 'Round like a ball'),
			(2, 'conical', 'Cone-shaped'),
			(3, 'irregular', NULL);

		INSERT INTO location (id, location, description) VALUES
			(1, 'leaf', 'On a leaf'),
			(2, 'stem', 'On the stem'),
			(3, 'bud', 'On a bud');

		INSERT INTO texture (id, texture, description) VALUES
			(1, 'smooth', 'Smooth surface'),
			(2, 'hairy', 'Covered with hair-like structures');

		INSERT INTO walls (id, walls, description) VALUES
			(1, 'thin', 'Thin-walled'),
			(2, 'thick', 'Thick-walled');

		INSERT INTO cells (id, cells, description) VALUES
			(1, 'single', 'Single-celled'),
			(2, 'multi', 'Multi-celled');

		INSERT INTO alignment (id, alignment, description) VALUES
			(1, 'integral', 'Integral to plant'),
			(2, 'free', 'Free from plant');

		INSERT INTO season (id, season) VALUES
			(1, 'spring'),
			(2, 'summer'),
			(3, 'fall'),
			(4, 'winter');

		INSERT INTO form (id, form, description) VALUES
			(1, 'detachable', 'Can be detached'),
			(2, 'non-detachable', 'Cannot be detached');

		INSERT INTO abundance (id, abundance, description, reference) VALUES
			(1, 'common', 'Frequently encountered', 'Russo 2021'),
			(2, 'uncommon', 'Less frequently encountered', 'Russo 2021'),
			(3, 'rare', 'Rarely encountered', NULL);
	`

	_, err = sqlDB.Exec(schema)
	if err != nil {
		t.Fatalf("failed to create test schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

func TestListFilterFieldTypes(t *testing.T) {
	sqlDB, queries := setupFilterFieldTestDB(t)
	defer sqlDB.Close()

	handler := NewFilterFieldHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/filter-fields", nil)
	w := httptest.NewRecorder()

	handler.ListTypes(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp []FilterFieldTypeInfo
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify we got all 10 filter field types
	if len(resp) != 10 {
		t.Errorf("expected 10 filter field types, got %d", len(resp))
	}

	// Verify color has no description
	for _, ft := range resp {
		if ft.Type == "color" {
			if ft.HasDescription {
				t.Error("expected color to not have description")
			}
			if ft.HasReference {
				t.Error("expected color to not have reference")
			}
		}
		if ft.Type == "abundance" {
			if !ft.HasDescription {
				t.Error("expected abundance to have description")
			}
			if !ft.HasReference {
				t.Error("expected abundance to have reference")
			}
		}
	}
}

func TestListFilterFieldsByType(t *testing.T) {
	sqlDB, queries := setupFilterFieldTestDB(t)
	defer sqlDB.Close()

	handler := NewFilterFieldHandler(queries)

	tests := []struct {
		name           string
		fieldType      string
		expectedStatus int
		expectedCount  int
	}{
		{
			name:           "list colors",
			fieldType:      "color",
			expectedStatus: http.StatusOK,
			expectedCount:  3,
		},
		{
			name:           "list shapes",
			fieldType:      "shape",
			expectedStatus: http.StatusOK,
			expectedCount:  3,
		},
		{
			name:           "list seasons",
			fieldType:      "season",
			expectedStatus: http.StatusOK,
			expectedCount:  4,
		},
		{
			name:           "list abundance",
			fieldType:      "abundance",
			expectedStatus: http.StatusOK,
			expectedCount:  3,
		},
		{
			name:           "invalid type",
			fieldType:      "invalid",
			expectedStatus: http.StatusBadRequest,
			expectedCount:  0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("type", tc.fieldType)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodGet, "/api/v2/filter-fields/"+tc.fieldType, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.ListByType(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp []FilterFieldResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if len(resp) != tc.expectedCount {
					t.Errorf("expected %d results, got %d", tc.expectedCount, len(resp))
				}
			}
		})
	}
}

func TestGetFilterFieldByID(t *testing.T) {
	sqlDB, queries := setupFilterFieldTestDB(t)
	defer sqlDB.Close()

	handler := NewFilterFieldHandler(queries)

	tests := []struct {
		name           string
		fieldType      string
		fieldID        string
		expectedStatus int
		expectedField  string
	}{
		{
			name:           "get color by ID",
			fieldType:      "color",
			fieldID:        "1",
			expectedStatus: http.StatusOK,
			expectedField:  "red",
		},
		{
			name:           "get shape by ID",
			fieldType:      "shape",
			fieldID:        "1",
			expectedStatus: http.StatusOK,
			expectedField:  "spherical",
		},
		{
			name:           "get abundance by ID",
			fieldType:      "abundance",
			fieldID:        "1",
			expectedStatus: http.StatusOK,
			expectedField:  "common",
		},
		{
			name:           "get non-existent color",
			fieldType:      "color",
			fieldID:        "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid ID",
			fieldType:      "color",
			fieldID:        "abc",
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "invalid type",
			fieldType:      "invalid",
			fieldID:        "1",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("type", tc.fieldType)
			rctx.URLParams.Add("id", tc.fieldID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodGet, "/api/v2/filter-fields/"+tc.fieldType+"/"+tc.fieldID, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.GetByID(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp FilterFieldResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.Field != tc.expectedField {
					t.Errorf("expected field %q, got %q", tc.expectedField, resp.Field)
				}
			}
		})
	}
}

func TestCreateFilterField(t *testing.T) {
	sqlDB, queries := setupFilterFieldTestDB(t)
	defer sqlDB.Close()

	handler := NewFilterFieldHandler(queries)

	tests := []struct {
		name           string
		body           FilterFieldCreateRequest
		expectedStatus int
	}{
		{
			name: "create color",
			body: FilterFieldCreateRequest{
				Type:  "color",
				Field: "blue",
			},
			expectedStatus: http.StatusCreated,
		},
		{
			name: "create shape with description",
			body: FilterFieldCreateRequest{
				Type:        "shape",
				Field:       "oval",
				Description: stringPtr("Oval-shaped"),
			},
			expectedStatus: http.StatusCreated,
		},
		{
			name: "create abundance with reference",
			body: FilterFieldCreateRequest{
				Type:        "abundance",
				Field:       "very common",
				Description: stringPtr("Very frequently encountered"),
				Reference:   stringPtr("Test Reference"),
			},
			expectedStatus: http.StatusCreated,
		},
		{
			name: "missing type",
			body: FilterFieldCreateRequest{
				Field: "test",
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "missing field",
			body: FilterFieldCreateRequest{
				Type: "color",
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "invalid type",
			body: FilterFieldCreateRequest{
				Type:  "invalid",
				Field: "test",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest(http.MethodPost, "/api/v2/filter-fields", bytes.NewReader(bodyBytes))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Create(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusCreated {
				var resp FilterFieldResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.ID == 0 {
					t.Error("expected non-zero ID")
				}

				if resp.Field != tc.body.Field {
					t.Errorf("expected field %q, got %q", tc.body.Field, resp.Field)
				}
			}
		})
	}
}

func TestUpdateFilterField(t *testing.T) {
	sqlDB, queries := setupFilterFieldTestDB(t)
	defer sqlDB.Close()

	handler := NewFilterFieldHandler(queries)

	tests := []struct {
		name           string
		fieldType      string
		fieldID        string
		body           FilterFieldUpdateRequest
		expectedStatus int
	}{
		{
			name:      "update color",
			fieldType: "color",
			fieldID:   "1",
			body: FilterFieldUpdateRequest{
				Field: "bright red",
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:      "update shape with description",
			fieldType: "shape",
			fieldID:   "1",
			body: FilterFieldUpdateRequest{
				Field:       "round",
				Description: stringPtr("Completely round"),
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:      "update abundance with reference",
			fieldType: "abundance",
			fieldID:   "1",
			body: FilterFieldUpdateRequest{
				Field:       "very common",
				Description: stringPtr("Updated description"),
				Reference:   stringPtr("Updated reference"),
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:      "update non-existent",
			fieldType: "color",
			fieldID:   "999",
			body: FilterFieldUpdateRequest{
				Field: "test",
			},
			expectedStatus: http.StatusNotFound,
		},
		{
			name:      "update with missing field",
			fieldType: "color",
			fieldID:   "1",
			body: FilterFieldUpdateRequest{
				Description: stringPtr("no field"),
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:      "invalid type",
			fieldType: "invalid",
			fieldID:   "1",
			body: FilterFieldUpdateRequest{
				Field: "test",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("type", tc.fieldType)
			rctx.URLParams.Add("id", tc.fieldID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest(http.MethodPut, "/api/v2/filter-fields/"+tc.fieldType+"/"+tc.fieldID, bytes.NewReader(bodyBytes)).WithContext(ctx)
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Update(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusOK {
				var resp FilterFieldResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.Field != tc.body.Field {
					t.Errorf("expected field %q, got %q", tc.body.Field, resp.Field)
				}
			}
		})
	}
}

func TestDeleteFilterField(t *testing.T) {
	sqlDB, queries := setupFilterFieldTestDB(t)
	defer sqlDB.Close()

	handler := NewFilterFieldHandler(queries)

	tests := []struct {
		name           string
		fieldType      string
		fieldID        string
		expectedStatus int
	}{
		{
			name:           "delete color",
			fieldType:      "color",
			fieldID:        "3", // Delete brown
			expectedStatus: http.StatusNoContent,
		},
		{
			name:           "delete shape",
			fieldType:      "shape",
			fieldID:        "3", // Delete irregular
			expectedStatus: http.StatusNoContent,
		},
		{
			name:           "delete non-existent",
			fieldType:      "color",
			fieldID:        "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid ID",
			fieldType:      "color",
			fieldID:        "abc",
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "invalid type",
			fieldType:      "invalid",
			fieldID:        "1",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("type", tc.fieldType)
			rctx.URLParams.Add("id", tc.fieldID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodDelete, "/api/v2/filter-fields/"+tc.fieldType+"/"+tc.fieldID, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.Delete(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}
		})
	}
}

func TestFilterFieldDescriptionHandling(t *testing.T) {
	sqlDB, queries := setupFilterFieldTestDB(t)
	defer sqlDB.Close()

	handler := NewFilterFieldHandler(queries)

	// Test shape - should have description
	t.Run("shape has description", func(t *testing.T) {
		rctx := chi.NewRouteContext()
		rctx.URLParams.Add("type", "shape")
		rctx.URLParams.Add("id", "1")
		ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

		req := httptest.NewRequest(http.MethodGet, "/api/v2/filter-fields/shape/1", nil).WithContext(ctx)
		w := httptest.NewRecorder()

		handler.GetByID(w, req)

		var resp FilterFieldResponse
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to unmarshal response: %v", err)
		}

		if resp.Description == nil {
			t.Error("expected description to be present for shape")
		}
	})

	// Test color - should not have description
	t.Run("color has no description", func(t *testing.T) {
		rctx := chi.NewRouteContext()
		rctx.URLParams.Add("type", "color")
		rctx.URLParams.Add("id", "1")
		ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

		req := httptest.NewRequest(http.MethodGet, "/api/v2/filter-fields/color/1", nil).WithContext(ctx)
		w := httptest.NewRecorder()

		handler.GetByID(w, req)

		var resp FilterFieldResponse
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to unmarshal response: %v", err)
		}

		if resp.Description != nil {
			t.Error("expected description to be nil for color")
		}
	})

	// Test abundance - should have reference
	t.Run("abundance has reference", func(t *testing.T) {
		rctx := chi.NewRouteContext()
		rctx.URLParams.Add("type", "abundance")
		rctx.URLParams.Add("id", "1")
		ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

		req := httptest.NewRequest(http.MethodGet, "/api/v2/filter-fields/abundance/1", nil).WithContext(ctx)
		w := httptest.NewRecorder()

		handler.GetByID(w, req)

		var resp FilterFieldResponse
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to unmarshal response: %v", err)
		}

		if resp.Reference == nil {
			t.Error("expected reference to be present for abundance")
		}

		if *resp.Reference != "Russo 2021" {
			t.Errorf("expected reference 'Russo 2021', got %q", *resp.Reference)
		}
	})
}

func TestAllFilterFieldTypes(t *testing.T) {
	sqlDB, queries := setupFilterFieldTestDB(t)
	defer sqlDB.Close()

	handler := NewFilterFieldHandler(queries)

	// Test listing each type
	types := []string{"color", "shape", "location", "texture", "walls", "cells", "alignment", "season", "form", "abundance"}

	for _, fieldType := range types {
		t.Run("list "+fieldType, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("type", fieldType)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodGet, "/api/v2/filter-fields/"+fieldType, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.ListByType(w, req)

			if w.Code != http.StatusOK {
				t.Errorf("expected status %d for type %s, got %d", http.StatusOK, fieldType, w.Code)
			}

			var resp []FilterFieldResponse
			if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
				t.Fatalf("failed to unmarshal response for type %s: %v", fieldType, err)
			}

			if len(resp) == 0 {
				t.Errorf("expected at least one result for type %s", fieldType)
			}
		})
	}
}

// Helper function for creating string pointers
func stringPtr(s string) *string {
	return &s
}
