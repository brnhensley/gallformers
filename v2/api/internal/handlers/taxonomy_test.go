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

// taxonomyTestDB creates an in-memory SQLite database for taxonomy testing.
func taxonomyTestDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	schema := `
		CREATE TABLE taxonomy (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT NOT NULL,
			description TEXT DEFAULT '',
			type TEXT NOT NULL CHECK (type = 'family' OR type = 'genus' OR type = 'section'),
			parent_id INTEGER DEFAULT NULL,
			FOREIGN KEY (parent_id) REFERENCES taxonomy(id) ON DELETE CASCADE
		);

		CREATE TABLE taxonomytaxonomy (
			taxonomy_id INTEGER NOT NULL,
			child_id INTEGER NOT NULL,
			PRIMARY KEY (taxonomy_id, child_id),
			FOREIGN KEY (taxonomy_id) REFERENCES taxonomy(id) ON DELETE CASCADE,
			FOREIGN KEY (child_id) REFERENCES taxonomy(id) ON DELETE CASCADE
		);

		CREATE TABLE species (
			id INTEGER PRIMARY KEY NOT NULL,
			taxoncode TEXT,
			name TEXT UNIQUE NOT NULL,
			datacomplete BOOLEAN DEFAULT 0 NOT NULL,
			abundance_id INTEGER
		);

		CREATE TABLE speciestaxonomy (
			species_id INTEGER NOT NULL,
			taxonomy_id INTEGER NOT NULL,
			PRIMARY KEY (species_id, taxonomy_id),
			FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE CASCADE,
			FOREIGN KEY (taxonomy_id) REFERENCES taxonomy(id) ON DELETE CASCADE
		);

		CREATE TABLE alias (
			id INTEGER PRIMARY KEY NOT NULL,
			name TEXT NOT NULL,
			type TEXT NOT NULL CHECK (type = 'common' OR type = 'scientific'),
			description TEXT NOT NULL DEFAULT ''
		);

		CREATE TABLE taxonomyalias (
			taxonomy_id INTEGER NOT NULL,
			alias_id INTEGER NOT NULL,
			PRIMARY KEY (taxonomy_id, alias_id),
			FOREIGN KEY (taxonomy_id) REFERENCES taxonomy(id) ON DELETE CASCADE,
			FOREIGN KEY (alias_id) REFERENCES alias(id) ON DELETE CASCADE
		);
	`

	if _, err := sqlDB.Exec(schema); err != nil {
		t.Fatalf("failed to create schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

// insertTestFamily inserts a test family and returns its ID.
func insertTestFamily(t *testing.T, sqlDB *sql.DB, name string, desc string) int64 {
	t.Helper()
	result, err := sqlDB.Exec(
		"INSERT INTO taxonomy (name, description, type) VALUES (?, ?, 'family')",
		name, desc,
	)
	if err != nil {
		t.Fatalf("failed to insert family: %v", err)
	}
	id, _ := result.LastInsertId()
	return id
}

// insertTestGenus inserts a test genus and returns its ID.
func insertTestGenus(t *testing.T, sqlDB *sql.DB, name string, parentID int64) int64 {
	t.Helper()
	result, err := sqlDB.Exec(
		"INSERT INTO taxonomy (name, description, type, parent_id) VALUES (?, '', 'genus', ?)",
		name, parentID,
	)
	if err != nil {
		t.Fatalf("failed to insert genus: %v", err)
	}
	genusID, _ := result.LastInsertId()

	// Create taxonomytaxonomy relationship
	_, err = sqlDB.Exec(
		"INSERT INTO taxonomytaxonomy (taxonomy_id, child_id) VALUES (?, ?)",
		parentID, genusID,
	)
	if err != nil {
		t.Fatalf("failed to create taxonomytaxonomy: %v", err)
	}

	return genusID
}

// insertTestSection inserts a test section and returns its ID.
func insertTestSection(t *testing.T, sqlDB *sql.DB, name string) int64 {
	t.Helper()
	result, err := sqlDB.Exec(
		"INSERT INTO taxonomy (name, description, type) VALUES (?, '', 'section')",
		name,
	)
	if err != nil {
		t.Fatalf("failed to insert section: %v", err)
	}
	id, _ := result.LastInsertId()
	return id
}

// insertTestSpecies inserts a test species and returns its ID.
func insertTestSpeciesForTaxonomy(t *testing.T, sqlDB *sql.DB, name string, genusID int64) int64 {
	t.Helper()
	result, err := sqlDB.Exec(
		"INSERT INTO species (name, taxoncode, datacomplete) VALUES (?, 'gall', 0)",
		name,
	)
	if err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}
	speciesID, _ := result.LastInsertId()

	// Link to genus
	_, err = sqlDB.Exec(
		"INSERT INTO speciestaxonomy (species_id, taxonomy_id) VALUES (?, ?)",
		speciesID, genusID,
	)
	if err != nil {
		t.Fatalf("failed to link species to taxonomy: %v", err)
	}

	return speciesID
}

func TestTaxonomyHandler_ListFamilies(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestFamily(t, sqlDB, "Cynipidae", "Insect")
	insertTestFamily(t, sqlDB, "Fagaceae", "Plant")

	handler := NewTaxonomyHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/families", nil)
	rec := httptest.NewRecorder()

	handler.ListFamilies(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response TaxonomyListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 2 {
		t.Errorf("expected total 2, got %d", response.Total)
	}
	if len(response.Data) != 2 {
		t.Errorf("expected 2 families, got %d", len(response.Data))
	}
}

func TestTaxonomyHandler_ListFamilies_Search(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestFamily(t, sqlDB, "Cynipidae", "Insect")
	insertTestFamily(t, sqlDB, "Cecidomyiidae", "Insect")
	insertTestFamily(t, sqlDB, "Fagaceae", "Plant")

	handler := NewTaxonomyHandler(queries)

	// Search for "nip" - should only match Cynipidae
	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/families?q=nip", nil)
	rec := httptest.NewRecorder()

	handler.ListFamilies(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response []TaxonomyEntry
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) != 1 {
		t.Errorf("expected 1 family matching 'nip', got %d", len(response))
	}
}

func TestTaxonomyHandler_GetFamilyByID(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	familyID := insertTestFamily(t, sqlDB, "Cynipidae", "Insect")
	insertTestGenus(t, sqlDB, "Andricus", familyID)

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/families/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetFamilyByID(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response FamilyResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "Cynipidae" {
		t.Errorf("expected name 'Cynipidae', got %s", response.Name)
	}
	if len(response.Genera) != 1 {
		t.Errorf("expected 1 genus, got %d", len(response.Genera))
	}
}

func TestTaxonomyHandler_GetFamilyByID_NotFound(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/families/999", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetFamilyByID(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestTaxonomyHandler_ListGenera(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	familyID := insertTestFamily(t, sqlDB, "Cynipidae", "Insect")
	insertTestGenus(t, sqlDB, "Andricus", familyID)
	insertTestGenus(t, sqlDB, "Disholcaspis", familyID)

	handler := NewTaxonomyHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/genera?famid=1", nil)
	rec := httptest.NewRecorder()

	handler.ListGenera(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response []TaxonomyEntry
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) != 2 {
		t.Errorf("expected 2 genera, got %d", len(response))
	}
}

func TestTaxonomyHandler_ListGenera_Search(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	familyID := insertTestFamily(t, sqlDB, "Cynipidae", "Insect")
	insertTestGenus(t, sqlDB, "Andricus", familyID)
	insertTestGenus(t, sqlDB, "Amphibolips", familyID)
	insertTestGenus(t, sqlDB, "Disholcaspis", familyID)

	handler := NewTaxonomyHandler(queries)

	// Search for "Andr" - should only match Andricus
	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/genera?q=Andr", nil)
	rec := httptest.NewRecorder()

	handler.ListGenera(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response []TaxonomyEntry
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) != 1 {
		t.Errorf("expected 1 genus matching 'Andr', got %d", len(response))
	}
}

func TestTaxonomyHandler_ListGenera_MissingParams(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/genera", nil)
	rec := httptest.NewRecorder()

	handler.ListGenera(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestTaxonomyHandler_ListSections(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestSection(t, sqlDB, "Quercus")
	insertTestSection(t, sqlDB, "Lobatae")

	handler := NewTaxonomyHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/sections", nil)
	rec := httptest.NewRecorder()

	handler.ListSections(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response TaxonomyListResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Total != 2 {
		t.Errorf("expected total 2, got %d", response.Total)
	}
}

func TestTaxonomyHandler_GetSectionByID(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestSection(t, sqlDB, "Quercus")

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/sections/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetSectionByID(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response SectionResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "Quercus" {
		t.Errorf("expected name 'Quercus', got %s", response.Name)
	}
}

func TestTaxonomyHandler_GetTaxonomy_BySpeciesID(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	familyID := insertTestFamily(t, sqlDB, "Cynipidae", "Insect")
	genusID := insertTestGenus(t, sqlDB, "Andricus", familyID)
	insertTestSpeciesForTaxonomy(t, sqlDB, "Andricus quercuscalifornicus", genusID)

	handler := NewTaxonomyHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy?id=1", nil)
	rec := httptest.NewRecorder()

	handler.GetTaxonomy(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var response FGS
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Genus.Name != "Andricus" {
		t.Errorf("expected genus 'Andricus', got %s", response.Genus.Name)
	}
	if response.Family.Name != "Cynipidae" {
		t.Errorf("expected family 'Cynipidae', got %s", response.Family.Name)
	}
}

func TestTaxonomyHandler_GetTaxonomy_ByName(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestFamily(t, sqlDB, "Cynipidae", "Insect")

	handler := NewTaxonomyHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy?name=Cynipidae", nil)
	rec := httptest.NewRecorder()

	handler.GetTaxonomy(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response []TaxonomyEntry
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(response) != 1 {
		t.Errorf("expected 1 result, got %d", len(response))
	}
	if response[0].Name != "Cynipidae" {
		t.Errorf("expected name 'Cynipidae', got %s", response[0].Name)
	}
}

func TestTaxonomyHandler_GetTaxonomy_MissingParams(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy", nil)
	rec := httptest.NewRecorder()

	handler.GetTaxonomy(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestTaxonomyHandler_GetTaxonomyByID(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestFamily(t, sqlDB, "Cynipidae", "Insect")

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetTaxonomyByID(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var response TaxonomyEntry
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "Cynipidae" {
		t.Errorf("expected name 'Cynipidae', got %s", response.Name)
	}
}

func TestTaxonomyHandler_GetTaxonomyByID_NotFound(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/999", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.GetTaxonomyByID(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestTaxonomyHandler_UpsertTaxonomy_Create(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	body := TaxonomyUpsertRequest{
		Name:        "NewFamily",
		Description: "A new family",
		Type:        "family",
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/taxonomy", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.UpsertTaxonomy(rec, req)

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var response TaxonomyEntry
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "NewFamily" {
		t.Errorf("expected name 'NewFamily', got %s", response.Name)
	}
}

func TestTaxonomyHandler_UpsertTaxonomy_MissingName(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	body := TaxonomyUpsertRequest{
		Description: "Missing name",
		Type:        "family",
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/taxonomy", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.UpsertTaxonomy(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}
}

func TestTaxonomyHandler_DeleteTaxonomy(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestFamily(t, sqlDB, "ToDelete", "Test")

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/taxonomy/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.DeleteTaxonomy(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected status 204, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestTaxonomyHandler_DeleteTaxonomy_NotFound(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "999")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/taxonomy/999", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.DeleteTaxonomy(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestTaxonomyHandler_UpsertFamily_Create(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	body := FamilyUpsertRequest{
		Name:        "NewFamily",
		Description: "Insect",
		Genera: []GenusRequest{
			{Name: "Genus1", Description: "First genus"},
			{Name: "Genus2", Description: "Second genus"},
		},
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/taxonomy/families", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.UpsertFamily(rec, req)

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var response FamilyResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if response.Name != "NewFamily" {
		t.Errorf("expected name 'NewFamily', got %s", response.Name)
	}
	if len(response.Genera) != 2 {
		t.Errorf("expected 2 genera, got %d", len(response.Genera))
	}
}

func TestTaxonomyHandler_DeleteFamily(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestFamily(t, sqlDB, "ToDelete", "Test")

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/taxonomy/families/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.DeleteFamily(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected status 204, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestTaxonomyHandler_DeleteSection(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	insertTestSection(t, sqlDB, "ToDelete")

	handler := NewTaxonomyHandler(queries)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodDelete, "/api/v2/taxonomy/sections/1", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.DeleteSection(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected status 204, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestTaxonomyHandler_MoveGenera(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	family1ID := insertTestFamily(t, sqlDB, "Family1", "Test")
	family2ID := insertTestFamily(t, sqlDB, "Family2", "Test")
	genusID := insertTestGenus(t, sqlDB, "MoveMe", family1ID)

	handler := NewTaxonomyHandler(queries)

	body := GeneraMoveRequest{
		Genera:      []int64{genusID},
		OldFamilyID: family1ID,
		NewFamilyID: family2ID,
	}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/taxonomy/genera/move", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.MoveGenera(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d: %s", rec.Code, rec.Body.String())
	}

	// Verify the genus was moved
	var genusParent int64
	err := sqlDB.QueryRow("SELECT parent_id FROM taxonomy WHERE id = ?", genusID).Scan(&genusParent)
	if err != nil {
		t.Fatalf("failed to query genus: %v", err)
	}
	if genusParent != family2ID {
		t.Errorf("expected genus parent to be %d, got %d", family2ID, genusParent)
	}
}

func TestTaxonomyHandler_RegisterRoutes(t *testing.T) {
	sqlDB, queries := taxonomyTestDB(t)
	defer sqlDB.Close()

	handler := NewTaxonomyHandler(queries)

	r := chi.NewRouter()
	r.Route("/api/v2", func(r chi.Router) {
		handler.RegisterRoutes(r)
	})

	insertTestFamily(t, sqlDB, "TestFamily", "Test")

	req := httptest.NewRequest(http.MethodGet, "/api/v2/taxonomy/families", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}
