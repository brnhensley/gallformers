package handlers

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/jeffdc/gallformers/v2/api/internal/middleware"
)

// tokenResponse represents the Auth0 token endpoint response.
type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	IDToken      string `json:"id_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
	TokenType    string `json:"token_type"`
}

// userResponse represents the response for /api/v2/me endpoint.
type userResponse struct {
	Email string   `json:"email"`
	Roles []string `json:"roles"`
}

// AuthCallbackHandler handles the OAuth callback from Auth0.
// It exchanges the authorization code for tokens and sets the httpOnly cookie.
func AuthCallbackHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		config := middleware.GetAuth0Config()
		if config == nil {
			middleware.RespondError(w, http.StatusInternalServerError, "SERVER_ERROR", "Auth not configured")
			return
		}

		// Get the authorization code and redirect URI from the request
		code := r.URL.Query().Get("code")
		if code == "" {
			middleware.RespondError(w, http.StatusBadRequest, "BAD_REQUEST", "Missing authorization code")
			return
		}

		redirectURI := r.URL.Query().Get("redirect_uri")
		if redirectURI == "" {
			middleware.RespondError(w, http.StatusBadRequest, "BAD_REQUEST", "Missing redirect_uri")
			return
		}

		// Exchange code for tokens
		tokens, err := exchangeCodeForTokens(config, code, redirectURI)
		if err != nil {
			slog.Error("failed to exchange code for tokens", "error", err)
			middleware.RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Failed to authenticate")
			return
		}

		// Validate the access token and get claims
		claims, err := middleware.ValidateToken(tokens.AccessToken)
		if err != nil {
			slog.Error("failed to validate access token", "error", err)
			middleware.RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid token")
			return
		}

		// Set the auth cookie
		middleware.SetAuthCookie(w, tokens.AccessToken, tokens.ExpiresIn)

		// Return user info in the response body
		middleware.RespondJSON(w, http.StatusOK, userResponse{
			Email: claims.Email,
			Roles: claims.Roles,
		})
	}
}

// MeHandler returns the current user's information from the token.
// Requires authentication (use with RequireAuth middleware).
func MeHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims := middleware.GetUser(r.Context())
		if claims == nil {
			middleware.RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Not authenticated")
			return
		}

		middleware.RespondJSON(w, http.StatusOK, userResponse{
			Email: claims.Email,
			Roles: claims.Roles,
		})
	}
}

// RefreshHandler refreshes an expired access token using the refresh token.
func RefreshHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		config := middleware.GetAuth0Config()
		if config == nil {
			middleware.RespondError(w, http.StatusInternalServerError, "SERVER_ERROR", "Auth not configured")
			return
		}

		// Parse request body for refresh token
		var req struct {
			RefreshToken string `json:"refresh_token"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			middleware.RespondError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
			return
		}

		if req.RefreshToken == "" {
			middleware.RespondError(w, http.StatusBadRequest, "BAD_REQUEST", "Missing refresh_token")
			return
		}

		// Use refresh token to get new access token
		tokens, err := refreshAccessToken(config, req.RefreshToken)
		if err != nil {
			slog.Error("failed to refresh token", "error", err)
			middleware.RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Failed to refresh token")
			return
		}

		// Validate the new access token
		claims, err := middleware.ValidateToken(tokens.AccessToken)
		if err != nil {
			slog.Error("failed to validate refreshed token", "error", err)
			middleware.RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid token")
			return
		}

		// Set the new auth cookie
		middleware.SetAuthCookie(w, tokens.AccessToken, tokens.ExpiresIn)

		// Return user info
		middleware.RespondJSON(w, http.StatusOK, userResponse{
			Email: claims.Email,
			Roles: claims.Roles,
		})
	}
}

// LogoutHandler clears the auth cookie to log the user out.
func LogoutHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		middleware.ClearAuthCookie(w)
		middleware.RespondJSON(w, http.StatusOK, map[string]string{
			"message": "Logged out successfully",
		})
	}
}

// exchangeCodeForTokens exchanges an authorization code for tokens via Auth0.
func exchangeCodeForTokens(config *middleware.Auth0Config, code, redirectURI string) (*tokenResponse, error) {
	tokenURL := "https://" + config.Domain + "/oauth/token"

	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("client_id", config.ClientID)
	data.Set("client_secret", config.ClientSecret)
	data.Set("code", code)
	data.Set("redirect_uri", redirectURI)
	data.Set("audience", config.Audience)

	return postToTokenEndpoint(tokenURL, data)
}

// refreshAccessToken uses a refresh token to get a new access token.
func refreshAccessToken(config *middleware.Auth0Config, refreshToken string) (*tokenResponse, error) {
	tokenURL := "https://" + config.Domain + "/oauth/token"

	data := url.Values{}
	data.Set("grant_type", "refresh_token")
	data.Set("client_id", config.ClientID)
	data.Set("client_secret", config.ClientSecret)
	data.Set("refresh_token", refreshToken)
	data.Set("audience", config.Audience)

	return postToTokenEndpoint(tokenURL, data)
}

// postToTokenEndpoint makes a POST request to the Auth0 token endpoint.
func postToTokenEndpoint(tokenURL string, data url.Values) (*tokenResponse, error) {
	req, err := http.NewRequest("POST", tokenURL, strings.NewReader(data.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		slog.Error("token endpoint error", "status", resp.StatusCode, "body", string(body))
		return nil, errors.New("token endpoint returned non-200 status")
	}

	var tokens tokenResponse
	if err := json.NewDecoder(bytes.NewReader(body)).Decode(&tokens); err != nil {
		return nil, err
	}

	return &tokens, nil
}
