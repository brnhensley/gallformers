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

// testSpeciesSourceDB creates an in-memory SQLite database for speciessource testing.
func testSpeciesSourceDB(t *testing.T) (*sql.DB, *db.Queries) {
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

		CREATE TABLE alias (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT NOT NULL,
			type TEXT NOT NULL CHECK (type = 'common' OR type = 'scientific'),
			description TEXT NOT NULL DEFAULT ''
		);

		CREATE TABLE speciessource (
			id INTEGER PRIMARY KEY NOT NULL,
			species_id INTEGER NOT NULL,
			source_id INTEGER NOT NULL,
			description TEXT DEFAULT '' NOT NULL,
			useasdefault INTEGER DEFAULT 0 NOT NULL,
			externallink TEXT DEFAULT '' NOT NULL,
			alias_id INTEGER,
			FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE CASCADE,
			FOREIGN KEY (source_id) REFERENCES source(id) ON DELETE CASCADE,
			FOREIGN KEY (alias_id) REFERENCES alias(id)
		);

		INSERT INTO taxontype (taxoncode, description) VALUES ('gall', 'Gall species');
		INSERT INTO taxontype (taxoncode, description) VALUES ('plant', 'Plant species');
	`

	if _, err := sqlDB.Exec(schema); err != nil {
		t.Fatalf("failed to create schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

// insertTestSpeciesSourceSpecies inserts a test species and returns its ID.
func insertTestSpeciesSourceSpecies(t *testing.T, sqlDB *sql.DB, name string) int64 {
	t.Helper()

	result, err := sqlDB.Exec("INSERT INTO species (name, taxoncode, datacomplete) VALUES (?, 'gall', 0)", name)
	if err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}
	id, _ := result.LastInsertId()
	return id
}

// insertTestSpeciesSourceSource inserts a test source and returns its ID.
func insertTestSpeciesSourceSource(t *testing.T, sqlDB *sql.DB, title string) int64 {
	t.Helper()

	result, err := sqlDB.Exec(
		"INSERT INTO source (title, author, pubyear, link, citation, datacomplete, license, licenselink) VALUES (?, 'Test Author', '2023', 'http://test.com', 'Test Citation', 0, 'CC0', 'http://license.com')",
		title,
	)
	if err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}
	id, _ := result.LastInsertId()
	return id
}

// insertTestSpeciesSourceRelation inserts a species-source relationship and returns its ID.
func insertTestSpeciesSourceRelation(t *testing.T, sqlDB *sql.DB, speciesID, sourceID int64, description string, useasdefault int64) int64 {
	t.Helper()

	result, err := sqlDB.Exec(
		"INSERT INTO speciessource (species_id, source_id, description, useasdefault, externallink) VALUES (?, ?, ?, ?, '')",
		speciesID, sourceID, description, useasdefault,
	)
	if err != nil {
		t.Fatalf("failed to insert speciessource: %v", err)
	}
	id, _ := result.LastInsertId()
	return id
}

func TestSpeciesSourceHandler_List(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")
	sourceID1 := insertTestSpeciesSourceSource(t, sqlDB, "Source One")
	sourceID2 := insertTestSpeciesSourceSource(t, sqlDB, "Source Two")
	insertTestSpeciesSourceRelation(t, sqlDB, speciesID, sourceID1, "Description 1", 0)
	insertTestSpeciesSourceRelation(t, sqlDB, speciesID, sourceID2, "Description 2", 1)

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response []SpeciesSourceResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) != 2 {
		t.Errorf("expected 2 sources, got %d", len(response))
	}
}

func TestSpeciesSourceHandler_List_SingleMapping(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")
	sourceID := insertTestSpeciesSourceSource(t, sqlDB, "Source One")
	insertTestSpeciesSourceRelation(t, sqlDB, speciesID, sourceID, "Test Description", 0)

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=1&sourceid=1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response SpeciesSourceResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Description != "Test Description" {
		t.Errorf("expected description 'Test Description', got %s", response.Description)
	}
	if response.Source == nil {
		t.Error("expected source to be populated")
	}
	if response.Source != nil && response.Source.Title != "Source One" {
		t.Errorf("expected source title 'Source One', got %s", response.Source.Title)
	}
}

func TestSpeciesSourceHandler_List_EmptyResult(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=1", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response []SpeciesSourceResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) != 0 {
		t.Errorf("expected 0 sources, got %d", len(response))
	}
}

func TestSpeciesSourceHandler_List_MissingSpeciesID(t *testing.T) {
	_, queries := testSpeciesSourceDB(t)

	handler := NewSpeciesSourceHandler(queries, nil)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_List_InvalidSpeciesID(t *testing.T) {
	_, queries := testSpeciesSourceDB(t)

	handler := NewSpeciesSourceHandler(queries, nil)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=invalid", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_List_NotFound(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=999&sourceid=999", nil)
	rec := httptest.NewRecorder()

	handler.List(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Create(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")
	sourceID := insertTestSpeciesSourceSource(t, sqlDB, "Test Source")

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	body := SpeciesSourceCreateRequest{
		SpeciesID:    speciesID,
		SourceID:     sourceID,
		Description:  "Test Description",
		Useasdefault: false,
		Externallink: "http://example.com",
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/species-sources", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
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
	if response.Description != "Test Description" {
		t.Errorf("expected description 'Test Description', got %s", response.Description)
	}
}

func TestSpeciesSourceHandler_Create_UseasdefaultClearsOthers(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")
	sourceID1 := insertTestSpeciesSourceSource(t, sqlDB, "Source One")
	sourceID2 := insertTestSpeciesSourceSource(t, sqlDB, "Source Two")

	// Insert first source as default
	insertTestSpeciesSourceRelation(t, sqlDB, speciesID, sourceID1, "First", 1)

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	// Create second source as new default
	body := SpeciesSourceCreateRequest{
		SpeciesID:    speciesID,
		SourceID:     sourceID2,
		Description:  "Second",
		Useasdefault: true,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/species-sources", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
	}

	// Verify the first source's useasdefault was cleared
	var useasdefault int64
	err := sqlDB.QueryRowContext(context.Background(), "SELECT useasdefault FROM speciessource WHERE source_id = ?", sourceID1).Scan(&useasdefault)
	if err != nil {
		t.Fatalf("failed to query useasdefault: %v", err)
	}
	if useasdefault != 0 {
		t.Errorf("expected first source's useasdefault to be 0, got %d", useasdefault)
	}
}

func TestSpeciesSourceHandler_Create_MissingSpeciesID(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	sourceID := insertTestSpeciesSourceSource(t, sqlDB, "Test Source")

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	body := SpeciesSourceCreateRequest{
		SourceID:    sourceID,
		Description: "Test Description",
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/species-sources", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Create_MissingSourceID(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	body := SpeciesSourceCreateRequest{
		SpeciesID:   speciesID,
		Description: "Test Description",
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/species-sources", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Create_InvalidJSON(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/species-sources", bytes.NewReader([]byte("invalid json")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Update(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")
	sourceID := insertTestSpeciesSourceSource(t, sqlDB, "Test Source")
	relationID := insertTestSpeciesSourceRelation(t, sqlDB, speciesID, sourceID, "Original Description", 0)

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	body := SpeciesSourceUpdateRequest{
		Description:  "Updated Description",
		Useasdefault: true,
		Externallink: "http://updated.com",
	}
	bodyBytes, _ := json.Marshal(body)

	r := chi.NewRouter()
	r.Put("/api/v2/species-sources/{id}", handler.Update)

	req := httptest.NewRequest(http.MethodPut, "/api/v2/species-sources/1", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response SpeciesSourceResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.ID != relationID {
		t.Errorf("expected id %d, got %d", relationID, response.ID)
	}
	if response.Description != "Updated Description" {
		t.Errorf("expected description 'Updated Description', got %s", response.Description)
	}
	if response.Useasdefault != 1 {
		t.Errorf("expected useasdefault 1, got %d", response.Useasdefault)
	}
	if response.Externallink != "http://updated.com" {
		t.Errorf("expected externallink 'http://updated.com', got %s", response.Externallink)
	}
}

func TestSpeciesSourceHandler_Update_NotFound(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	body := SpeciesSourceUpdateRequest{
		Description: "Test",
	}
	bodyBytes, _ := json.Marshal(body)

	r := chi.NewRouter()
	r.Put("/api/v2/species-sources/{id}", handler.Update)

	req := httptest.NewRequest(http.MethodPut, "/api/v2/species-sources/999", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Update_InvalidID(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	body := SpeciesSourceUpdateRequest{
		Description: "Test",
	}
	bodyBytes, _ := json.Marshal(body)

	r := chi.NewRouter()
	r.Put("/api/v2/species-sources/{id}", handler.Update)

	req := httptest.NewRequest(http.MethodPut, "/api/v2/species-sources/invalid", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Update_InvalidJSON(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")
	sourceID := insertTestSpeciesSourceSource(t, sqlDB, "Test Source")
	insertTestSpeciesSourceRelation(t, sqlDB, speciesID, sourceID, "Original", 0)

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	r := chi.NewRouter()
	r.Put("/api/v2/species-sources/{id}", handler.Update)

	req := httptest.NewRequest(http.MethodPut, "/api/v2/species-sources/1", bytes.NewReader([]byte("invalid json")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Delete(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")
	sourceID := insertTestSpeciesSourceSource(t, sqlDB, "Test Source")
	insertTestSpeciesSourceRelation(t, sqlDB, speciesID, sourceID, "Test", 0)

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/species-sources?speciesid=1&sourceid=1", nil)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected status 204, got %d: %s", rec.Code, rec.Body.String())
	}

	// Verify the relationship was deleted
	listReq := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=1", nil)
	listRec := httptest.NewRecorder()
	handler.List(listRec, listReq)

	var response []SpeciesSourceResponse
	json.NewDecoder(listRec.Body).Decode(&response)
	if len(response) != 0 {
		t.Errorf("expected relationship to be deleted, but got %d", len(response))
	}
}

func TestSpeciesSourceHandler_Delete_NotFound(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/species-sources?speciesid=999&sourceid=999", nil)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Delete_MissingSpeciesID(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/species-sources?sourceid=1", nil)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Delete_MissingSourceID(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/species-sources?speciesid=1", nil)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Delete_InvalidSpeciesID(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/species-sources?speciesid=invalid&sourceid=1", nil)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_Delete_InvalidSourceID(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/species-sources?speciesid=1&sourceid=invalid", nil)
	rec := httptest.NewRecorder()

	handler.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestSpeciesSourceHandler_RegisterRoutes(t *testing.T) {
	sqlDB, queries := testSpeciesSourceDB(t)
	defer sqlDB.Close()

	handler := NewSpeciesSourceHandler(queries, sqlDB)

	r := chi.NewRouter()
	r.Route("/api/v2", func(r chi.Router) {
		handler.RegisterRoutes(r)
	})

	// Test that routes are registered by making a request
	speciesID := insertTestSpeciesSourceSpecies(t, sqlDB, "Test Species")
	sourceID := insertTestSpeciesSourceSource(t, sqlDB, "Test Source")
	insertTestSpeciesSourceRelation(t, sqlDB, speciesID, sourceID, "Test", 0)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/species-sources?speciesid=1", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}
