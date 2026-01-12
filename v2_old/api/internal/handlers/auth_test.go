package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jeffdc/gallformers/v2/api/internal/middleware"
)

func TestLogoutHandler(t *testing.T) {
	handler := LogoutHandler()

	req := httptest.NewRequest(http.MethodPost, "/api/v2/auth/logout", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	// Check that a cookie was set with MaxAge = -1 (expired)
	cookies := rec.Result().Cookies()
	found := false
	for _, cookie := range cookies {
		if cookie.Name == middleware.AuthCookieName {
			found = true
			if cookie.MaxAge != -1 {
				t.Errorf("expected MaxAge -1 to expire cookie, got %d", cookie.MaxAge)
			}
			if cookie.Value != "" {
				t.Errorf("expected empty cookie value, got %s", cookie.Value)
			}
		}
	}
	if !found {
		t.Error("expected auth cookie to be set (for clearing)")
	}

	// Check response body
	var resp map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp["message"] != "Logged out successfully" {
		t.Errorf("expected logout message, got %s", resp["message"])
	}
}

func TestMeHandler_Authenticated(t *testing.T) {
	handler := MeHandler()

	claims := &middleware.Claims{
		Email: "test@example.com",
		Roles: []string{"admin", "superadmin"},
	}
	ctx := context.WithValue(context.Background(), middleware.UserContextKey, claims)

	req := httptest.NewRequest(http.MethodGet, "/api/v2/me", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var resp userResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Email != "test@example.com" {
		t.Errorf("expected email test@example.com, got %s", resp.Email)
	}
	if len(resp.Roles) != 2 {
		t.Errorf("expected 2 roles, got %d", len(resp.Roles))
	}
}

func TestMeHandler_Unauthenticated(t *testing.T) {
	handler := MeHandler()

	req := httptest.NewRequest(http.MethodGet, "/api/v2/me", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected status 401, got %d", rec.Code)
	}
}

func TestAuthCallbackHandler_MissingCode(t *testing.T) {
	handler := AuthCallbackHandler()

	req := httptest.NewRequest(http.MethodGet, "/api/v2/auth/callback?redirect_uri=http://localhost", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	// If Auth0 isn't configured, we get 500; otherwise we should get 400 for missing code
	if rec.Code == http.StatusInternalServerError {
		body := rec.Body.String()
		if !strings.Contains(body, "Auth not configured") {
			t.Errorf("expected auth not configured error, got %s", body)
		}
		t.Skip("Auth0 not configured, skipping validation test")
	}

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}

	body := rec.Body.String()
	if !strings.Contains(body, "Missing authorization code") {
		t.Errorf("expected error about missing code, got %s", body)
	}
}

func TestAuthCallbackHandler_MissingRedirectURI(t *testing.T) {
	handler := AuthCallbackHandler()

	req := httptest.NewRequest(http.MethodGet, "/api/v2/auth/callback?code=abc123", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	// If Auth0 isn't configured, we get 500; otherwise we should get 400 for missing redirect_uri
	if rec.Code == http.StatusInternalServerError {
		body := rec.Body.String()
		if !strings.Contains(body, "Auth not configured") {
			t.Errorf("expected auth not configured error, got %s", body)
		}
		t.Skip("Auth0 not configured, skipping validation test")
	}

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}

	body := rec.Body.String()
	if !strings.Contains(body, "Missing redirect_uri") {
		t.Errorf("expected error about missing redirect_uri, got %s", body)
	}
}

func TestRefreshHandler_MissingRefreshToken(t *testing.T) {
	handler := RefreshHandler()

	req := httptest.NewRequest(http.MethodPost, "/api/v2/auth/refresh", strings.NewReader(`{}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	// If Auth0 isn't configured, we get 500; otherwise we should get 400 for missing token
	if rec.Code == http.StatusInternalServerError {
		body := rec.Body.String()
		if !strings.Contains(body, "Auth not configured") {
			t.Errorf("expected auth not configured error, got %s", body)
		}
		t.Skip("Auth0 not configured, skipping validation test")
	}

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}

	body := rec.Body.String()
	if !strings.Contains(body, "Missing refresh_token") {
		t.Errorf("expected error about missing refresh_token, got %s", body)
	}
}

func TestRefreshHandler_InvalidRequestBody(t *testing.T) {
	handler := RefreshHandler()

	req := httptest.NewRequest(http.MethodPost, "/api/v2/auth/refresh", strings.NewReader(`not json`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	// If Auth0 isn't configured, we get 500; otherwise we should get 400 for invalid body
	if rec.Code == http.StatusInternalServerError {
		body := rec.Body.String()
		if !strings.Contains(body, "Auth not configured") {
			t.Errorf("expected auth not configured error, got %s", body)
		}
		t.Skip("Auth0 not configured, skipping validation test")
	}

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", rec.Code)
	}

	body := rec.Body.String()
	if !strings.Contains(body, "Invalid request body") {
		t.Errorf("expected error about invalid request body, got %s", body)
	}
}
