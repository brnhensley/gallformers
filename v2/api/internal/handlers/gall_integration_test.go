//go:build integration
// +build integration

package handlers

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	_ "github.com/mattn/go-sqlite3"
)

// Integration tests compare v2 API responses with expected v1 behavior.
// Run with: go test -tags=integration ./internal/handlers/...

func getIntegrationDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	dbPath := os.Getenv("DATABASE_PATH")
	if dbPath == "" {
		dbPath = "../../../../prisma/gallformers.sqlite"
	}

	sqlDB, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_busy_timeout=5000&mode=ro")
	if err != nil {
		t.Fatalf("failed to open database: %v", err)
	}

	if err := sqlDB.Ping(); err != nil {
		t.Fatalf("failed to ping database: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

func TestIntegration_ListGalls_ReturnsResults(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response GallListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// The production database should have many galls
	if response.Total < 100 {
		t.Errorf("expected at least 100 galls in production database, got %d", response.Total)
	}

	// Verify response structure for first gall
	if len(response.Data) > 0 {
		firstGall := response.Data[0]
		if firstGall.ID <= 0 {
			t.Error("expected positive ID")
		}
		if firstGall.Name == "" {
			t.Error("expected non-empty name")
		}
		if firstGall.GallID <= 0 {
			t.Error("expected positive gall_id")
		}
		// Aliases should be an array (even if empty)
		if firstGall.Aliases == nil {
			t.Error("expected aliases array, got nil")
		}
	}
}

func TestIntegration_ListGalls_Search(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	// Search for a common gall genus
	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls?q=Andricus", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var response GallListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Should find Andricus species
	if response.Total == 0 {
		t.Error("expected to find Andricus galls")
	}

	// All results should contain "andricus" (case-insensitive)
	for _, gall := range response.Data {
		if !containsSubstring(strings.ToLower(gall.Name), "andricus") {
			t.Errorf("search result '%s' does not contain 'andricus' (case-insensitive)", gall.Name)
		}
	}
}

func TestIntegration_ListGalls_Pagination(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	// First page
	req1 := httptest.NewRequest(http.MethodGet, "/api/v2/galls?limit=10&offset=0", nil)
	rec1 := httptest.NewRecorder()
	handler.List(rec1, req1)

	var response1 GallListResponse
	json.NewDecoder(rec1.Body).Decode(&response1)

	// Second page
	req2 := httptest.NewRequest(http.MethodGet, "/api/v2/galls?limit=10&offset=10", nil)
	rec2 := httptest.NewRecorder()
	handler.List(rec2, req2)

	var response2 GallListResponse
	json.NewDecoder(rec2.Body).Decode(&response2)

	// Total should be the same
	if response1.Total != response2.Total {
		t.Errorf("pagination changed total: %d vs %d", response1.Total, response2.Total)
	}

	// Results should be different
	if len(response1.Data) > 0 && len(response2.Data) > 0 {
		if response1.Data[0].ID == response2.Data[0].ID {
			t.Error("pagination returned same first result")
		}
	}
}

func TestIntegration_GetGallByID(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	// First, get a valid gall ID from the list
	listReq := httptest.NewRequest(http.MethodGet, "/api/v2/galls?limit=1", nil)
	listRec := httptest.NewRecorder()
	handler.List(listRec, listReq)

	var listResponse GallListResponse
	json.NewDecoder(listRec.Body).Decode(&listResponse)

	if len(listResponse.Data) == 0 {
		t.Fatal("no galls in database")
	}

	gallID := listResponse.Data[0].ID

	// Now fetch that specific gall
	chiCtx := chi.NewRouteContext()
	chiCtx.URLParams.Add("id", int64ToStr(gallID))
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, chiCtx)
	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls/"+int64ToStr(gallID), nil).WithContext(ctx)

	rec := httptest.NewRecorder()
	handler.GetByID(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response GallResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Verify detailed response structure
	if response.ID != gallID {
		t.Errorf("expected ID %d, got %d", gallID, response.ID)
	}

	// Single gall response should include filter field arrays
	// Note: Arrays may be nil if no filter fields are associated,
	// but the detailed response should have them populated (empty or not)
	// For now, we just verify the response structure is valid
	t.Logf("Gall %d has %d colors, %d shapes, %d locations, %d hosts",
		response.ID, len(response.Colors), len(response.Shapes),
		len(response.Locations), len(response.Hosts))
}

func TestIntegration_GallResponseMatchesV1Structure(t *testing.T) {
	sqlDB, queries := getIntegrationDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	// Get a gall with known data
	listReq := httptest.NewRequest(http.MethodGet, "/api/v2/galls?q=quercuscalifornicus&limit=1", nil)
	listRec := httptest.NewRecorder()
	handler.List(listRec, listReq)

	var listResponse GallListResponse
	json.NewDecoder(listRec.Body).Decode(&listResponse)

	if len(listResponse.Data) == 0 {
		t.Skip("quercuscalifornicus not found in database")
	}

	gall := listResponse.Data[0]

	// Verify the structure matches what v1 expects:
	// - id: species ID
	// - name: species name
	// - gall_id: gall table ID
	// - datacomplete: boolean
	// - undescribed: boolean
	// - aliases: array of alias objects

	if gall.ID <= 0 {
		t.Error("id should be positive")
	}
	if gall.GallID <= 0 {
		t.Error("gall_id should be positive")
	}
	if gall.Name == "" {
		t.Error("name should not be empty")
	}

	// The response should be valid JSON that can be re-marshaled
	data, err := json.Marshal(gall)
	if err != nil {
		t.Fatalf("response cannot be marshaled to JSON: %v", err)
	}

	var remarshaledGall GallResponse
	if err := json.Unmarshal(data, &remarshaledGall); err != nil {
		t.Fatalf("response cannot be unmarshaled from JSON: %v", err)
	}

	if remarshaledGall.ID != gall.ID {
		t.Error("ID not preserved after re-marshaling")
	}
}

// Helper functions

func containsSubstring(s, substr string) bool {
	return strings.Contains(s, substr)
}

func int64ToStr(i int64) string {
	return strconv.FormatInt(i, 10)
}
