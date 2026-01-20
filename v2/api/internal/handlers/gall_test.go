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

// testDB creates an in-memory SQLite database for testing.
func testDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	// Create the necessary tables
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

		CREATE TABLE color (id INTEGER PRIMARY KEY, color TEXT UNIQUE NOT NULL);
		CREATE TABLE shape (id INTEGER PRIMARY KEY, shape TEXT UNIQUE NOT NULL, description TEXT);
		CREATE TABLE texture (id INTEGER PRIMARY KEY, texture TEXT UNIQUE NOT NULL, description TEXT);
		CREATE TABLE location (id INTEGER PRIMARY KEY, location TEXT UNIQUE NOT NULL, description TEXT);
		CREATE TABLE alignment (id INTEGER PRIMARY KEY, alignment TEXT UNIQUE NOT NULL, description TEXT);
		CREATE TABLE walls (id INTEGER PRIMARY KEY, walls TEXT UNIQUE NOT NULL, description TEXT);
		CREATE TABLE cells (id INTEGER PRIMARY KEY, cells TEXT UNIQUE NOT NULL, description TEXT);
		CREATE TABLE season (id INTEGER PRIMARY KEY, season TEXT UNIQUE NOT NULL);
		CREATE TABLE form (id INTEGER PRIMARY KEY, form TEXT UNIQUE NOT NULL, description TEXT);

		CREATE TABLE gallcolor (gall_id INTEGER, color_id INTEGER, PRIMARY KEY (gall_id, color_id));
		CREATE TABLE gallshape (gall_id INTEGER, shape_id INTEGER, PRIMARY KEY (gall_id, shape_id));
		CREATE TABLE galltexture (gall_id INTEGER, texture_id INTEGER, PRIMARY KEY (gall_id, texture_id));
		CREATE TABLE galllocation (gall_id INTEGER, location_id INTEGER, PRIMARY KEY (gall_id, location_id));
		CREATE TABLE gallalignment (gall_id INTEGER, alignment_id INTEGER, PRIMARY KEY (gall_id, alignment_id));
		CREATE TABLE gallwalls (gall_id INTEGER, walls_id INTEGER, PRIMARY KEY (gall_id, walls_id));
		CREATE TABLE gallcells (gall_id INTEGER, cells_id INTEGER, PRIMARY KEY (gall_id, cells_id));
		CREATE TABLE gallseason (id INTEGER PRIMARY KEY, gall_id INTEGER, season_id INTEGER);
		CREATE TABLE gallform (gall_id INTEGER, form_id INTEGER, PRIMARY KEY (gall_id, form_id));

		INSERT INTO taxontype (taxoncode, description) VALUES ('gall', 'Gall species');
		INSERT INTO taxontype (taxoncode, description) VALUES ('plant', 'Plant species');
	`

	if _, err := sqlDB.Exec(schema); err != nil {
		t.Fatalf("failed to create schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

// insertTestGall inserts a test gall and returns its species ID.
func insertTestGall(t *testing.T, sqlDB *sql.DB, name string) int64 {
	t.Helper()

	// Insert species
	result, err := sqlDB.Exec("INSERT INTO species (name, taxoncode, datacomplete) VALUES (?, 'gall', 0)", name)
	if err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}
	speciesID, _ := result.LastInsertId()

	// Insert gall
	result, err = sqlDB.Exec("INSERT INTO gall (taxoncode, undescribed) VALUES ('gall', 0)")
	if err != nil {
		t.Fatalf("failed to insert gall: %v", err)
	}
	gallID, _ := result.LastInsertId()

	// Link species to gall
	_, err = sqlDB.Exec("INSERT INTO gallspecies (species_id, gall_id) VALUES (?, ?)", speciesID, gallID)
	if err != nil {
		t.Fatalf("failed to link species to gall: %v", err)
	}

	return speciesID
}

func TestGallHandler_List(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	// Insert test data
	insertTestGall(t, sqlDB, "Test Gall 1")
	insertTestGall(t, sqlDB, "Test Gall 2")

	handler := NewGallHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response GallListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 2 {
		t.Errorf("expected total 2, got %d", response.Total)
	}
	if len(response.Data) != 2 {
		t.Errorf("expected 2 galls, got %d", len(response.Data))
	}
}

func TestGallHandler_List_WithPagination(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	// Insert test data
	insertTestGall(t, sqlDB, "Test Gall 1")
	insertTestGall(t, sqlDB, "Test Gall 2")
	insertTestGall(t, sqlDB, "Test Gall 3")

	handler := NewGallHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls?limit=2&offset=1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response GallListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 3 {
		t.Errorf("expected total 3, got %d", response.Total)
	}
	if len(response.Data) != 2 {
		t.Errorf("expected 2 galls (paginated), got %d", len(response.Data))
	}
	if response.Offset != 1 {
		t.Errorf("expected offset 1, got %d", response.Offset)
	}
}

func TestGallHandler_List_WithSearch(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	insertTestGall(t, sqlDB, "Andricus quercuscalifornicus")
	insertTestGall(t, sqlDB, "Disholcaspis eldoradensis")
	insertTestGall(t, sqlDB, "Andricus kingi")

	handler := NewGallHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls?q=Andricus", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response GallListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 2 {
		t.Errorf("expected total 2 (matching 'Andricus'), got %d", response.Total)
	}
}

func TestGallHandler_List_InvalidLimit(t *testing.T) {
	_, queries := testDB(t)

	handler := NewGallHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls?limit=invalid", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHandler_List_InvalidOffset(t *testing.T) {
	_, queries := testDB(t)

	handler := NewGallHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls?offset=-1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHandler_GetByID(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	speciesID := insertTestGall(t, sqlDB, "Test Gall")

	handler := NewGallHandler(queries)

	// Set up chi router context
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetByID(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response GallResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.ID != speciesID {
		t.Errorf("expected ID %d, got %d", speciesID, response.ID)
	}
	if response.Name != "Test Gall" {
		t.Errorf("expected name 'Test Gall', got %s", response.Name)
	}
}

func TestGallHandler_GetByID_NotFound(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls/999", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetByID(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestGallHandler_GetByID_InvalidID(t *testing.T) {
	_, queries := testDB(t)

	handler := NewGallHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "invalid")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls/invalid", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetByID(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHandler_Create(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	body := GallCreateRequest{
		Name:        "New Test Gall",
		Undescribed: false,
		Aliases: []Alias{
			{Name: "Common Name", Type: "common", Description: "A common name"},
		},
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/galls", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var response GallResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "New Test Gall" {
		t.Errorf("expected name 'New Test Gall', got %s", response.Name)
	}
	if len(response.Aliases) != 1 {
		t.Errorf("expected 1 alias, got %d", len(response.Aliases))
	}
}

func TestGallHandler_Create_MissingName(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	body := GallCreateRequest{
		Undescribed: false,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/galls", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHandler_Create_InvalidJSON(t *testing.T) {
	_, queries := testDB(t)

	handler := NewGallHandler(queries)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/galls", bytes.NewReader([]byte("invalid json")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHandler_Update(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	insertTestGall(t, sqlDB, "Original Name")

	handler := NewGallHandler(queries)

	body := GallUpdateRequest{
		Name:        "Updated Name",
		Undescribed: true,
	}
	bodyBytes, _ := json.Marshal(body)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodPut, "/api/v2/galls/1", bytes.NewReader(bodyBytes)).WithContext(ctx)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Update(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response GallResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "Updated Name" {
		t.Errorf("expected name 'Updated Name', got %s", response.Name)
	}
	if !response.Undescribed {
		t.Error("expected undescribed to be true")
	}
}

func TestGallHandler_Update_NotFound(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	body := GallUpdateRequest{Name: "Updated Name"}
	bodyBytes, _ := json.Marshal(body)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodPut, "/api/v2/galls/999", bytes.NewReader(bodyBytes)).WithContext(ctx)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Update(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestGallHandler_Delete(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	insertTestGall(t, sqlDB, "To Be Deleted")

	handler := NewGallHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/galls/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected status 204, got %d: %s", rec.Code, rec.Body.String())
	}

	// Verify the gall was deleted
	rctx2 := chi.NewRouteContext()
	rctx2.URLParams.Add("id", "1")
	ctx2 := context.WithValue(context.Background(), chi.RouteCtxKey, rctx2)

	req2 := httptest.NewRequest(http.MethodGet, "/api/v2/galls/1", nil).WithContext(ctx2)
	rec2 := httptest.NewRecorder()

	handler.GetByID(rec2, req2)

	if rec2.Code != http.StatusNotFound {
		t.Errorf("expected deleted gall to return 404, got %d", rec2.Code)
	}
}

func TestGallHandler_Delete_NotFound(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/galls/999", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestGallHandler_Delete_InvalidID(t *testing.T) {
	_, queries := testDB(t)

	handler := NewGallHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "invalid")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/galls/invalid", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHandler_RegisterRoutes(t *testing.T) {
	sqlDB, queries := testDB(t)
	defer sqlDB.Close()

	handler := NewGallHandler(queries)

	r := chi.NewRouter()
	r.Route("/api/v2", func(r chi.Router) {
		handler.RegisterRoutes(r)
	})

	// Test that routes are registered by making a request
	insertTestGall(t, sqlDB, "Test Gall")

	req := httptest.NewRequest(http.MethodGet, "/api/v2/galls", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}
