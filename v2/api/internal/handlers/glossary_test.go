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

// setupGlossaryTestDB creates an in-memory SQLite database with glossary test data
func setupGlossaryTestDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()

	sqlDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	// Create the schema
	schema := `
		CREATE TABLE glossary (
			id INTEGER PRIMARY KEY NOT NULL,
			word TEXT UNIQUE NOT NULL,
			definition TEXT NOT NULL,
			urls TEXT NOT NULL
		);

		INSERT INTO glossary (id, word, definition, urls) VALUES
			(1, 'agamic', 'Reproducing asexually', 'https://example.com/agamic'),
			(2, 'cecidium', 'A gall or plant tumor', 'https://example.com/cecidium'),
			(3, 'gall', 'An abnormal plant growth caused by insects, mites, or other organisms', 'https://example.com/gall	https://example2.com/gall'),
			(4, 'inquiline', 'An organism that lives in the gall of another species', '');
	`

	_, err = sqlDB.Exec(schema)
	if err != nil {
		t.Fatalf("failed to create test schema: %v", err)
	}

	return sqlDB, db.New(sqlDB)
}

func TestListGlossary(t *testing.T) {
	sqlDB, queries := setupGlossaryTestDB(t)
	defer sqlDB.Close()

	handler := NewGlossaryHandler(queries)

	tests := []struct {
		name           string
		queryString    string
		expectedStatus int
		expectedTotal  int64
		expectedCount  int
	}{
		{
			name:           "list all glossary entries",
			queryString:    "",
			expectedStatus: http.StatusOK,
			expectedTotal:  4,
			expectedCount:  4,
		},
		{
			name:           "search glossary by word - gall",
			queryString:    "?q=gall",
			expectedStatus: http.StatusOK,
			expectedTotal:  1,
			expectedCount:  1,
		},
		{
			name:           "search glossary by word - partial match",
			queryString:    "?q=amic",
			expectedStatus: http.StatusOK,
			expectedTotal:  1, // matches 'agamic'
			expectedCount:  1,
		},
		{
			name:           "search glossary - no results",
			queryString:    "?q=nonexistent",
			expectedStatus: http.StatusOK,
			expectedTotal:  0,
			expectedCount:  0,
		},
		{
			name:           "list with pagination - limit 2",
			queryString:    "?limit=2",
			expectedStatus: http.StatusOK,
			expectedTotal:  4,
			expectedCount:  2,
		},
		{
			name:           "list with pagination - limit 2 offset 2",
			queryString:    "?limit=2&offset=2",
			expectedStatus: http.StatusOK,
			expectedTotal:  4,
			expectedCount:  2,
		},
		{
			name:           "list with pagination - limit 2 offset 3",
			queryString:    "?limit=2&offset=3",
			expectedStatus: http.StatusOK,
			expectedTotal:  4,
			expectedCount:  1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v2/glossary"+tc.queryString, nil)
			w := httptest.NewRecorder()

			handler.List(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			var resp GlossaryListResponse
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

func TestGetGlossaryByID(t *testing.T) {
	sqlDB, queries := setupGlossaryTestDB(t)
	defer sqlDB.Close()

	handler := NewGlossaryHandler(queries)

	tests := []struct {
		name           string
		glossaryID     string
		expectedStatus int
		expectedWord   string
	}{
		{
			name:           "get existing glossary entry",
			glossaryID:     "1",
			expectedStatus: http.StatusOK,
			expectedWord:   "agamic",
		},
		{
			name:           "get another existing glossary entry",
			glossaryID:     "3",
			expectedStatus: http.StatusOK,
			expectedWord:   "gall",
		},
		{
			name:           "get non-existent glossary entry",
			glossaryID:     "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid glossary ID",
			glossaryID:     "abc",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.glossaryID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodGet, "/api/v2/glossary/"+tc.glossaryID, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.GetByID(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp GlossaryResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.Word != tc.expectedWord {
					t.Errorf("expected word %q, got %q", tc.expectedWord, resp.Word)
				}
			}
		})
	}
}

func TestGetGlossaryByWord(t *testing.T) {
	sqlDB, queries := setupGlossaryTestDB(t)
	defer sqlDB.Close()

	handler := NewGlossaryHandler(queries)

	tests := []struct {
		name           string
		word           string
		expectedStatus int
		expectedID     int64
	}{
		{
			name:           "get existing glossary entry by word",
			word:           "gall",
			expectedStatus: http.StatusOK,
			expectedID:     3,
		},
		{
			name:           "get non-existent glossary entry by word",
			word:           "nonexistent",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "partial word match should not work",
			word:           "gal",
			expectedStatus: http.StatusNotFound, // Exact match only
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("word", tc.word)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			encodedWord := url.PathEscape(tc.word)
			req := httptest.NewRequest(http.MethodGet, "/api/v2/glossary/by-word/"+encodedWord, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.GetByWord(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}

			if tc.expectedStatus == http.StatusOK {
				var resp GlossaryResponse
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

func TestCreateGlossary(t *testing.T) {
	sqlDB, queries := setupGlossaryTestDB(t)
	defer sqlDB.Close()

	handler := NewGlossaryHandler(queries)

	tests := []struct {
		name           string
		body           GlossaryCreateRequest
		expectedStatus int
	}{
		{
			name: "create valid glossary entry",
			body: GlossaryCreateRequest{
				Word:       "alternation of generations",
				Definition: "A life cycle with alternating sexual and asexual phases",
				URLs:       "https://example.com/alternation",
			},
			expectedStatus: http.StatusCreated,
		},
		{
			name: "create glossary entry without URLs",
			body: GlossaryCreateRequest{
				Word:       "cynipid",
				Definition: "A gall wasp of the family Cynipidae",
				URLs:       "",
			},
			expectedStatus: http.StatusCreated,
		},
		{
			name: "create glossary entry with missing word",
			body: GlossaryCreateRequest{
				Definition: "Some definition",
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "create glossary entry with missing definition",
			body: GlossaryCreateRequest{
				Word: "someword",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest(http.MethodPost, "/api/v2/glossary", bytes.NewReader(bodyBytes))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Create(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusCreated {
				var resp GlossaryResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.ID == 0 {
					t.Error("expected non-zero ID")
				}

				if resp.Word != tc.body.Word {
					t.Errorf("expected word %q, got %q", tc.body.Word, resp.Word)
				}

				if resp.Definition != tc.body.Definition {
					t.Errorf("expected definition %q, got %q", tc.body.Definition, resp.Definition)
				}
			}
		})
	}
}

func TestUpdateGlossary(t *testing.T) {
	sqlDB, queries := setupGlossaryTestDB(t)
	defer sqlDB.Close()

	handler := NewGlossaryHandler(queries)

	tests := []struct {
		name           string
		glossaryID     string
		body           GlossaryUpdateRequest
		expectedStatus int
	}{
		{
			name:       "update existing glossary entry",
			glossaryID: "1",
			body: GlossaryUpdateRequest{
				Word:       "agamic (updated)",
				Definition: "Updated definition for agamic",
				URLs:       "https://example.com/updated",
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:       "update non-existent glossary entry",
			glossaryID: "999",
			body: GlossaryUpdateRequest{
				Word:       "Won't Work",
				Definition: "This won't work",
			},
			expectedStatus: http.StatusNotFound,
		},
		{
			name:       "update with missing word",
			glossaryID: "2",
			body: GlossaryUpdateRequest{
				Definition: "Some definition",
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:       "update with missing definition",
			glossaryID: "2",
			body: GlossaryUpdateRequest{
				Word: "someword",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.glossaryID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest(http.MethodPut, "/api/v2/glossary/"+tc.glossaryID, bytes.NewReader(bodyBytes)).WithContext(ctx)
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.Update(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d: %s", tc.expectedStatus, w.Code, w.Body.String())
			}

			if tc.expectedStatus == http.StatusOK {
				var resp GlossaryResponse
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("failed to unmarshal response: %v", err)
				}

				if resp.Word != tc.body.Word {
					t.Errorf("expected word %q, got %q", tc.body.Word, resp.Word)
				}

				if resp.Definition != tc.body.Definition {
					t.Errorf("expected definition %q, got %q", tc.body.Definition, resp.Definition)
				}
			}
		})
	}
}

func TestDeleteGlossary(t *testing.T) {
	sqlDB, queries := setupGlossaryTestDB(t)
	defer sqlDB.Close()

	handler := NewGlossaryHandler(queries)

	tests := []struct {
		name           string
		glossaryID     string
		expectedStatus int
	}{
		{
			name:           "delete existing glossary entry",
			glossaryID:     "4", // Delete inquiline entry
			expectedStatus: http.StatusNoContent,
		},
		{
			name:           "delete non-existent glossary entry",
			glossaryID:     "999",
			expectedStatus: http.StatusNotFound,
		},
		{
			name:           "invalid glossary ID",
			glossaryID:     "abc",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rctx := chi.NewRouteContext()
			rctx.URLParams.Add("id", tc.glossaryID)
			ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

			req := httptest.NewRequest(http.MethodDelete, "/api/v2/glossary/"+tc.glossaryID, nil).WithContext(ctx)
			w := httptest.NewRecorder()

			handler.Delete(w, req)

			if w.Code != tc.expectedStatus {
				t.Errorf("expected status %d, got %d", tc.expectedStatus, w.Code)
			}
		})
	}
}

func TestListGlossaryOrdering(t *testing.T) {
	sqlDB, queries := setupGlossaryTestDB(t)
	defer sqlDB.Close()

	handler := NewGlossaryHandler(queries)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/glossary", nil)
	w := httptest.NewRecorder()
	handler.List(w, req)

	var resp GlossaryListResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify alphabetical ordering by word (case-insensitive)
	expectedOrder := []string{
		"agamic",
		"cecidium",
		"gall",
		"inquiline",
	}

	if len(resp.Data) != len(expectedOrder) {
		t.Fatalf("expected %d results, got %d", len(expectedOrder), len(resp.Data))
	}

	for i, expected := range expectedOrder {
		if resp.Data[i].Word != expected {
			t.Errorf("position %d: expected %q, got %q", i, expected, resp.Data[i].Word)
		}
	}
}

func TestGlossaryURLsField(t *testing.T) {
	sqlDB, queries := setupGlossaryTestDB(t)
	defer sqlDB.Close()

	handler := NewGlossaryHandler(queries)

	// Test that entry with multiple URLs (tab-separated) is returned correctly
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "3") // gall entry has multiple URLs
	ctx := context.WithValue(context.Background(), chi.RouteCtxKey, rctx)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/glossary/3", nil).WithContext(ctx)
	w := httptest.NewRecorder()

	handler.GetByID(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp GlossaryResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// URLs should contain tab-separated values
	expectedURLs := "https://example.com/gall\thttps://example2.com/gall"
	if resp.URLs != expectedURLs {
		t.Errorf("expected URLs %q, got %q", expectedURLs, resp.URLs)
	}

	// Test entry with empty URLs
	rctx2 := chi.NewRouteContext()
	rctx2.URLParams.Add("id", "4") // inquiline entry has empty URLs
	ctx2 := context.WithValue(context.Background(), chi.RouteCtxKey, rctx2)

	req2 := httptest.NewRequest(http.MethodGet, "/api/v2/glossary/4", nil).WithContext(ctx2)
	w2 := httptest.NewRecorder()

	handler.GetByID(w2, req2)

	var resp2 GlossaryResponse
	if err := json.Unmarshal(w2.Body.Bytes(), &resp2); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp2.URLs != "" {
		t.Errorf("expected empty URLs, got %q", resp2.URLs)
	}
}
