package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCORSWithOrigins_AllowedOrigin(t *testing.T) {
	allowedOrigins := []string{"http://localhost:5173", "https://gallformers.org"}
	handler := CORSWithOrigins(allowedOrigins)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Header().Get("Access-Control-Allow-Origin") != "http://localhost:5173" {
		t.Errorf("expected Access-Control-Allow-Origin to be http://localhost:5173, got %s",
			rec.Header().Get("Access-Control-Allow-Origin"))
	}
	if rec.Header().Get("Access-Control-Allow-Credentials") != "true" {
		t.Error("expected Access-Control-Allow-Credentials to be true")
	}
}

func TestCORSWithOrigins_DisallowedOrigin(t *testing.T) {
	allowedOrigins := []string{"http://localhost:5173"}
	handler := CORSWithOrigins(allowedOrigins)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Origin", "http://evil.com")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Errorf("expected no Access-Control-Allow-Origin header, got %s",
			rec.Header().Get("Access-Control-Allow-Origin"))
	}
}

func TestCORSWithOrigins_PreflightRequest(t *testing.T) {
	allowedOrigins := []string{"http://localhost:5173"}
	handler := CORSWithOrigins(allowedOrigins)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("should not reach here"))
	}))

	req := httptest.NewRequest(http.MethodOptions, "/test", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected status 204, got %d", rec.Code)
	}
	if rec.Body.String() != "" {
		t.Error("expected empty body for preflight response")
	}
}

func TestCORSWithOrigins_NoOriginHeader(t *testing.T) {
	allowedOrigins := []string{"http://localhost:5173"}
	handler := CORSWithOrigins(allowedOrigins)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	// No Origin header
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Error("expected no CORS headers when Origin not present")
	}
	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}

func TestCORSWithOrigins_AllHeaders(t *testing.T) {
	allowedOrigins := []string{"http://localhost:5173"}
	handler := CORSWithOrigins(allowedOrigins)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	expectedHeaders := map[string]string{
		"Access-Control-Allow-Origin":      "http://localhost:5173",
		"Access-Control-Allow-Credentials": "true",
		"Access-Control-Allow-Methods":     "GET, POST, PUT, DELETE, OPTIONS",
		"Access-Control-Allow-Headers":     "Accept, Authorization, Content-Type, X-Requested-With",
		"Access-Control-Max-Age":           "86400",
	}

	for header, expected := range expectedHeaders {
		if got := rec.Header().Get(header); got != expected {
			t.Errorf("expected %s to be %q, got %q", header, expected, got)
		}
	}
}
