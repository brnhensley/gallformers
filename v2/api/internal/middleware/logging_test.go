package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestLogging(t *testing.T) {
	handler := Logging(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request ID is in context
		requestID := GetRequestID(r.Context())
		if requestID == "" {
			t.Error("expected request ID in context")
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}

func TestLogging_CapturesStatusCode(t *testing.T) {
	tests := []struct {
		name           string
		statusCode     int
		expectedStatus int
	}{
		{"200 OK", http.StatusOK, http.StatusOK},
		{"404 Not Found", http.StatusNotFound, http.StatusNotFound},
		{"500 Internal Server Error", http.StatusInternalServerError, http.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := Logging(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(tt.statusCode)
			}))

			req := httptest.NewRequest(http.MethodGet, "/test", nil)
			rec := httptest.NewRecorder()

			handler.ServeHTTP(rec, req)

			if rec.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, rec.Code)
			}
		})
	}
}

func TestGetRequestID_NoID(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	id := GetRequestID(req.Context())
	if id != "" {
		t.Errorf("expected empty string, got %q", id)
	}
}

func TestResponseWriter_WriteHeaderOnce(t *testing.T) {
	rec := httptest.NewRecorder()
	rw := newResponseWriter(rec)

	rw.WriteHeader(http.StatusCreated)
	rw.WriteHeader(http.StatusOK) // Should be ignored

	if rw.status != http.StatusCreated {
		t.Errorf("expected status 201, got %d", rw.status)
	}
}

func TestResponseWriter_WriteDefaultsStatus(t *testing.T) {
	rec := httptest.NewRecorder()
	rw := newResponseWriter(rec)

	rw.Write([]byte("test"))

	if rw.status != http.StatusOK {
		t.Errorf("expected status 200, got %d", rw.status)
	}
}
