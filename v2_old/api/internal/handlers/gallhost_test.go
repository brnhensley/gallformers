package handlers

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	db "github.com/jeffdc/gallformers/v2/api/internal/db/generated"
	_ "github.com/mattn/go-sqlite3"
)

// testGallHostDB creates an in-memory SQLite database for gallhost testing.
func testGallHostDB(t *testing.T) (*sql.DB, *db.Queries) {
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

		CREATE TABLE host (
			id INTEGER PRIMARY KEY NOT NULL,
			host_species_id INTEGER,
			gall_species_id INTEGER,
			FOREIGN KEY (host_species_id) REFERENCES species(id) ON DELETE CASCADE,
			FOREIGN KEY (gall_species_id) REFERENCES species(id) ON DELETE CASCADE
		);

		INSERT INTO taxontype (taxoncode, description) VALUES ('gall', 'Gall species');
		INSERT INTO taxontype (taxoncode, description) VALUES ('plant', 'Plant species');
	`

	if _, err := sqlDB.Exec(schema); err != nil {
		t.Fatalf("failed to create schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

// insertTestGallHostGall inserts a test gall species and returns its ID.
func insertTestGallHostGall(t *testing.T, sqlDB *sql.DB, name string) int64 {
	t.Helper()

	result, err := sqlDB.Exec("INSERT INTO species (name, taxoncode, datacomplete) VALUES (?, 'gall', 0)", name)
	if err != nil {
		t.Fatalf("failed to insert gall species: %v", err)
	}
	speciesID, _ := result.LastInsertId()

	result2, err := sqlDB.Exec("INSERT INTO gall (taxoncode, undescribed) VALUES ('gall', 0)")
	if err != nil {
		t.Fatalf("failed to insert gall: %v", err)
	}
	gallID, _ := result2.LastInsertId()

	_, err = sqlDB.Exec("INSERT INTO gallspecies (species_id, gall_id) VALUES (?, ?)", speciesID, gallID)
	if err != nil {
		t.Fatalf("failed to insert gallspecies: %v", err)
	}

	return speciesID
}

// insertTestGallHostHost inserts a test host species and returns its ID.
func insertTestGallHostHost(t *testing.T, sqlDB *sql.DB, name string) int64 {
	t.Helper()

	result, err := sqlDB.Exec("INSERT INTO species (name, taxoncode, datacomplete) VALUES (?, 'plant', 0)", name)
	if err != nil {
		t.Fatalf("failed to insert host species: %v", err)
	}
	speciesID, _ := result.LastInsertId()

	return speciesID
}

// insertTestGallHostRelation inserts a gall-host relationship.
func insertTestGallHostRelation(t *testing.T, sqlDB *sql.DB, gallID, hostID int64) int64 {
	t.Helper()

	result, err := sqlDB.Exec("INSERT INTO host (gall_species_id, host_species_id) VALUES (?, ?)", gallID, hostID)
	if err != nil {
		t.Fatalf("failed to insert gall-host relation: %v", err)
	}
	id, _ := result.LastInsertId()
	return id
}

func TestGallHostHandler_List(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	gallID := insertTestGallHostGall(t, sqlDB, "Test Gall")
	hostID1 := insertTestGallHostHost(t, sqlDB, "Quercus lobata")
	hostID2 := insertTestGallHostHost(t, sqlDB, "Quercus agrifolia")
	insertTestGallHostRelation(t, sqlDB, gallID, hostID1)
	insertTestGallHostRelation(t, sqlDB, gallID, hostID2)

	handler := NewGallHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid=1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response GallHostListResponse
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

func TestGallHostHandler_List_EmptyResult(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	insertTestGallHostGall(t, sqlDB, "Test Gall")

	handler := NewGallHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid=1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response GallHostListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 0 {
		t.Errorf("expected total 0, got %d", response.Total)
	}
	if len(response.Data) != 0 {
		t.Errorf("expected 0 hosts, got %d", len(response.Data))
	}
}

func TestGallHostHandler_List_MissingGallID(t *testing.T) {
	_, queries := testGallHostDB(t)

	handler := NewGallHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHostHandler_List_InvalidGallID(t *testing.T) {
	_, queries := testGallHostDB(t)

	handler := NewGallHostHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid=invalid", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHostHandler_Create(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	gallID := insertTestGallHostGall(t, sqlDB, "Test Gall")
	hostID := insertTestGallHostHost(t, sqlDB, "Quercus lobata")

	handler := NewGallHostHandler(queries)

	body := GallHostCreateRequest{
		GallSpeciesID: gallID,
		HostSpeciesID: hostID,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/gall-hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var response GallHostResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.GallSpeciesID != gallID {
		t.Errorf("expected gall_species_id %d, got %d", gallID, response.GallSpeciesID)
	}
	if response.HostSpeciesID != hostID {
		t.Errorf("expected host_species_id %d, got %d", hostID, response.HostSpeciesID)
	}
	if response.HostName != "Quercus lobata" {
		t.Errorf("expected host_name 'Quercus lobata', got %s", response.HostName)
	}
}

func TestGallHostHandler_Create_Duplicate(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	gallID := insertTestGallHostGall(t, sqlDB, "Test Gall")
	hostID := insertTestGallHostHost(t, sqlDB, "Quercus lobata")
	insertTestGallHostRelation(t, sqlDB, gallID, hostID)

	handler := NewGallHostHandler(queries)

	body := GallHostCreateRequest{
		GallSpeciesID: gallID,
		HostSpeciesID: hostID,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/gall-hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestGallHostHandler_Create_MissingGallID(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	hostID := insertTestGallHostHost(t, sqlDB, "Quercus lobata")

	handler := NewGallHostHandler(queries)

	body := GallHostCreateRequest{
		HostSpeciesID: hostID,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/gall-hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHostHandler_Create_MissingHostID(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	gallID := insertTestGallHostGall(t, sqlDB, "Test Gall")

	handler := NewGallHostHandler(queries)

	body := GallHostCreateRequest{
		GallSpeciesID: gallID,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/gall-hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHostHandler_Create_InvalidJSON(t *testing.T) {
	_, queries := testGallHostDB(t)

	handler := NewGallHostHandler(queries)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/gall-hosts", bytes.NewReader([]byte("invalid json")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHostHandler_Delete(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	gallID := insertTestGallHostGall(t, sqlDB, "Test Gall")
	hostID := insertTestGallHostHost(t, sqlDB, "Quercus lobata")
	insertTestGallHostRelation(t, sqlDB, gallID, hostID)

	handler := NewGallHostHandler(queries)

	body := GallHostDeleteRequest{
		GallSpeciesID: gallID,
		HostSpeciesID: hostID,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/gall-hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected status 204, got %d: %s", rec.Code, rec.Body.String())
	}

	// Verify the relationship was deleted
	listReq := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid=1", nil)
	listRec := httptest.NewRecorder()
	handler.List(listRec, listReq)

	var response GallHostListResponse
	json.NewDecoder(listRec.Body).Decode(&response)
	if response.Total != 0 {
		t.Errorf("expected relationship to be deleted, but total is %d", response.Total)
	}
}

func TestGallHostHandler_Delete_NotFound(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	handler := NewGallHostHandler(queries)

	body := GallHostDeleteRequest{
		GallSpeciesID: 999,
		HostSpeciesID: 999,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/gall-hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestGallHostHandler_Delete_MissingGallID(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	handler := NewGallHostHandler(queries)

	body := GallHostDeleteRequest{
		HostSpeciesID: 1,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/gall-hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHostHandler_Delete_MissingHostID(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	handler := NewGallHostHandler(queries)

	body := GallHostDeleteRequest{
		GallSpeciesID: 1,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/gall-hosts", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHostHandler_Delete_InvalidJSON(t *testing.T) {
	_, queries := testGallHostDB(t)

	handler := NewGallHostHandler(queries)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/gall-hosts", bytes.NewReader([]byte("invalid json")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestGallHostHandler_RegisterRoutes(t *testing.T) {
	sqlDB, queries := testGallHostDB(t)
	defer sqlDB.Close()

	handler := NewGallHostHandler(queries)

	r := chi.NewRouter()
	r.Route("/api/v2", func(r chi.Router) {
		handler.RegisterRoutes(r)
	})

	// Test that routes are registered by making a request
	gallID := insertTestGallHostGall(t, sqlDB, "Test Gall")
	hostID := insertTestGallHostHost(t, sqlDB, "Quercus lobata")
	insertTestGallHostRelation(t, sqlDB, gallID, hostID)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/gall-hosts?gallid=1", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}
