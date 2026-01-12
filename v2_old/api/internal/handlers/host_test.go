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

// testHostDB creates an in-memory SQLite database for host testing.
func testHostDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	schema := `
		CREATE TABLE taxontype (
			taxoncode TEXT PRIMARY KEY NOT NULL,
			description TEXT UNIQUE NOT NULL
		);

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
			FOREIGN KEY (taxoncode) REFERENCES taxontype(taxoncode),
			FOREIGN KEY (abundance_id) REFERENCES abundance(id)
		);

		CREATE TABLE gall (
			id INTEGER PRIMARY KEY NOT NULL,
			taxoncode TEXT NOT NULL CHECK (taxoncode = 'gall'),
			detachable INTEGER,
			undescribed BOOLEAN NOT NULL DEFAULT 0,
			FOREIGN KEY (taxoncode) REFERENCES taxontype(taxoncode)
		);

		CREATE TABLE gallspecies (
			species_id INTEGER NOT NULL,
			gall_id INTEGER NOT NULL,
			FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE CASCADE,
			FOREIGN KEY (gall_id) REFERENCES gall(id) ON DELETE CASCADE,
			PRIMARY KEY (species_id, gall_id)
		);

		CREATE TABLE alias (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT NOT NULL,
			type TEXT NOT NULL CHECK (type = 'common' OR type = 'scientific'),
			description TEXT NOT NULL DEFAULT ''
		);

		CREATE TABLE aliasspecies (
			species_id INTEGER NOT NULL,
			alias_id INTEGER NOT NULL,
			FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE CASCADE,
			FOREIGN KEY (alias_id) REFERENCES alias(id) ON DELETE CASCADE,
			PRIMARY KEY (species_id, alias_id)
		);

		CREATE TABLE host (
			id INTEGER PRIMARY KEY NOT NULL,
			host_species_id INTEGER,
			gall_species_id INTEGER,
			FOREIGN KEY (host_species_id) REFERENCES species(id) ON DELETE CASCADE,
			FOREIGN KEY (gall_species_id) REFERENCES species(id) ON DELETE CASCADE
		);

		CREATE TABLE place (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT UNIQUE NOT NULL,
			code TEXT NOT NULL,
			type TEXT NOT NULL
		);

		CREATE TABLE speciesplace (
			species_id INTEGER,
			place_id INTEGER,
			FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE CASCADE,
			FOREIGN KEY (place_id) REFERENCES place(id) ON DELETE CASCADE,
			PRIMARY KEY (species_id, place_id)
		);

		INSERT INTO taxontype (taxoncode, description) VALUES ('gall', 'Gall species');
		INSERT INTO taxontype (taxoncode, description) VALUES ('plant', 'Plant species');
		INSERT INTO place (id, name, code, type) VALUES (1, 'California', 'CA', 'state');
		INSERT INTO place (id, name, code, type) VALUES (2, 'Oregon', 'OR', 'state');
	`

	if _, err := sqlDB.Exec(schema); err != nil {
		t.Fatalf("failed to create schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

// insertTestHost inserts a test host and returns its species ID.
func insertTestHost(t *testing.T, sqlDB *sql.DB, name string) int64 {
	t.Helper()

	result, err := sqlDB.Exec("INSERT INTO species (name, taxoncode, datacomplete) VALUES (?, 'plant', 0)", name)
	if err != nil {
		t.Fatalf("failed to insert host species: %v", err)
	}
	speciesID, _ := result.LastInsertId()

	return speciesID
}

func TestHostHandler_List(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	insertTestHost(t, sqlDB, "Quercus lobata")
	insertTestHost(t, sqlDB, "Quercus agrifolia")

	handler := NewHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response HostListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 2 {
		t.Errorf("expected total 2, got %d", response.Total)
	}
	if len(response.Data) != 2 {
		t.Errorf("expected 2 hosts, got %d", len(response.Data))
	}
}

func TestHostHandler_List_WithPagination(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	insertTestHost(t, sqlDB, "Quercus lobata")
	insertTestHost(t, sqlDB, "Quercus agrifolia")
	insertTestHost(t, sqlDB, "Quercus douglasii")

	handler := NewHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts?limit=2&offset=1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response HostListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 3 {
		t.Errorf("expected total 3, got %d", response.Total)
	}
	if len(response.Data) != 2 {
		t.Errorf("expected 2 hosts (paginated), got %d", len(response.Data))
	}
	if response.Offset != 1 {
		t.Errorf("expected offset 1, got %d", response.Offset)
	}
}

func TestHostHandler_List_WithSearch(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	insertTestHost(t, sqlDB, "Quercus lobata")
	insertTestHost(t, sqlDB, "Salix lasiolepis")
	insertTestHost(t, sqlDB, "Quercus agrifolia")

	handler := NewHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts?q=Quercus", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response HostListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 2 {
		t.Errorf("expected total 2 (matching 'Quercus'), got %d", response.Total)
	}
}

func TestHostHandler_List_Simple(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	insertTestHost(t, sqlDB, "Quercus lobata")

	handler := NewHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts?simple=true", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response HostSimpleListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 1 {
		t.Errorf("expected total 1, got %d", response.Total)
	}
}

func TestHostHandler_List_InvalidLimit(t *testing.T) {
	_, queries := testHostDB(t)

	handler := NewHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts?limit=invalid", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestHostHandler_List_InvalidOffset(t *testing.T) {
	_, queries := testHostDB(t)

	handler := NewHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts?offset=-1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestHostHandler_GetByID(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	speciesID := insertTestHost(t, sqlDB, "Quercus lobata")

	handler := NewHostHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetByID(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response HostResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.ID != speciesID {
		t.Errorf("expected ID %d, got %d", speciesID, response.ID)
	}
	if response.Name != "Quercus lobata" {
		t.Errorf("expected name 'Quercus lobata', got %s", response.Name)
	}
}

func TestHostHandler_GetByID_NotFound(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	handler := NewHostHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts/999", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetByID(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestHostHandler_GetByID_InvalidID(t *testing.T) {
	_, queries := testHostDB(t)

	handler := NewHostHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "invalid")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts/invalid", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetByID(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestHostHandler_Create(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	handler := NewHostHandler(queries)

	body := HostCreateRequest{
		Name:         "Quercus lobata",
		Datacomplete: false,
		Aliases: []Alias{
			{Name: "Valley Oak", Type: "common", Description: "Common name"},
		},
		Places: []int64{1},
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var response HostResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "Quercus lobata" {
		t.Errorf("expected name 'Quercus lobata', got %s", response.Name)
	}
	if len(response.Aliases) != 1 {
		t.Errorf("expected 1 alias, got %d", len(response.Aliases))
	}
}

func TestHostHandler_Create_MissingName(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	handler := NewHostHandler(queries)

	body := HostCreateRequest{
		Datacomplete: false,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestHostHandler_Create_InvalidJSON(t *testing.T) {
	_, queries := testHostDB(t)

	handler := NewHostHandler(queries)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/hosts", bytes.NewReader([]byte("invalid json")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestHostHandler_Update(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	insertTestHost(t, sqlDB, "Original Name")

	handler := NewHostHandler(queries)

	body := HostUpdateRequest{
		Name:         "Updated Name",
		Datacomplete: true,
	}
	bodyBytes, _ := json.Marshal(body)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodPut, "/api/v2/hosts/1", bytes.NewReader(bodyBytes)).WithContext(ctx)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Update(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response HostResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "Updated Name" {
		t.Errorf("expected name 'Updated Name', got %s", response.Name)
	}
	if !response.Datacomplete {
		t.Error("expected datacomplete to be true")
	}
}

func TestHostHandler_Update_NotFound(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	handler := NewHostHandler(queries)

	body := HostUpdateRequest{Name: "Updated Name"}
	bodyBytes, _ := json.Marshal(body)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodPut, "/api/v2/hosts/999", bytes.NewReader(bodyBytes)).WithContext(ctx)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Update(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestHostHandler_Delete(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	insertTestHost(t, sqlDB, "To Be Deleted")

	handler := NewHostHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/hosts/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected status 204, got %d: %s", rec.Code, rec.Body.String())
	}

	// Verify the host was deleted
	rctx2 := chi.NewRouteContext()
	rctx2.URLParams.Add("id", "1")
	ctx2 := context.WithValue(context.Background(), chi.RouteCtxKey, rctx2)

	req2 := httptest.NewRequest(http.MethodGet, "/api/v2/hosts/1", nil).WithContext(ctx2)
	rec2 := httptest.NewRecorder()

	handler.GetByID(rec2, req2)

	if rec2.Code != http.StatusNotFound {
		t.Errorf("expected deleted host to return 404, got %d", rec2.Code)
	}
}

func TestHostHandler_Delete_NotFound(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	handler := NewHostHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/hosts/999", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestHostHandler_Delete_InvalidID(t *testing.T) {
	_, queries := testHostDB(t)

	handler := NewHostHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "invalid")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/hosts/invalid", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestHostHandler_RegisterRoutes(t *testing.T) {
	sqlDB, queries := testHostDB(t)
	defer sqlDB.Close()

	handler := NewHostHandler(queries)

	r := chi.NewRouter()
	r.Route("/api/v2", func(r chi.Router) {
		handler.RegisterRoutes(r)
	})

	// Test that routes are registered by making a request
	insertTestHost(t, sqlDB, "Test Host")

	req := httptest.NewRequest(http.MethodGet, "/api/v2/hosts", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}
