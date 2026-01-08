package middleware

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"slices"
	"sync"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

// UserContextKey is the context key for user claims.
const UserContextKey contextKey = "user"

// AuthCookieName is the name of the httpOnly cookie containing the JWT.
const AuthCookieName = "auth_token"

// Claims represents the JWT claims including Auth0 roles.
type Claims struct {
	jwt.RegisteredClaims
	Email string   `json:"email"`
	Roles []string `json:"https://gallformers.org/roles"`
}

// Auth0Config holds the Auth0 configuration.
type Auth0Config struct {
	Domain   string
	Audience string
}

var (
	auth0Config *Auth0Config
	jwks        keyfunc.Keyfunc
	jwksOnce    sync.Once
	jwksErr     error
)

// InitAuth0 initializes the Auth0 configuration from environment variables.
// This should be called during application startup.
func InitAuth0() error {
	domain := os.Getenv("AUTH0_DOMAIN")
	audience := os.Getenv("AUTH0_AUDIENCE")

	if domain == "" {
		return errors.New("AUTH0_DOMAIN environment variable is required")
	}
	if audience == "" {
		return errors.New("AUTH0_AUDIENCE environment variable is required")
	}

	auth0Config = &Auth0Config{
		Domain:   domain,
		Audience: audience,
	}

	// Initialize JWKS for RS256 validation
	jwksOnce.Do(func() {
		jwksURL := "https://" + domain + "/.well-known/jwks.json"
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		jwks, jwksErr = keyfunc.NewDefaultCtx(ctx, []string{jwksURL})
		if jwksErr != nil {
			slog.Error("failed to initialize JWKS", "error", jwksErr)
		}
	})

	return jwksErr
}

// RequireAuth is a middleware that validates Auth0 JWT tokens.
// It extracts the token from the auth_token httpOnly cookie.
func RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Extract token from httpOnly cookie
		cookie, err := r.Cookie(AuthCookieName)
		if err != nil {
			slog.Debug("no auth cookie found", "error", err)
			RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "No auth token")
			return
		}

		claims, err := validateToken(cookie.Value)
		if err != nil {
			slog.Debug("token validation failed", "error", err)
			RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid token")
			return
		}

		// Add claims to context
		ctx := context.WithValue(r.Context(), UserContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// OptionalAuth is a middleware that validates Auth0 JWT tokens if present,
// but allows unauthenticated requests to continue.
func OptionalAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie(AuthCookieName)
		if err == nil {
			claims, err := validateToken(cookie.Value)
			if err == nil {
				ctx := context.WithValue(r.Context(), UserContextKey, claims)
				r = r.WithContext(ctx)
			}
		}
		next.ServeHTTP(w, r)
	})
}

// validateToken validates the JWT and returns the claims.
func validateToken(tokenString string) (*Claims, error) {
	if auth0Config == nil || jwks == nil {
		return nil, errors.New("auth0 not initialized")
	}

	claims := &Claims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, jwks.Keyfunc,
		jwt.WithAudience(auth0Config.Audience),
		jwt.WithIssuer("https://"+auth0Config.Domain+"/"),
		jwt.WithValidMethods([]string{"RS256"}),
	)
	if err != nil {
		return nil, err
	}

	if !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}

// GetUser retrieves the user claims from the context.
func GetUser(ctx context.Context) *Claims {
	if claims, ok := ctx.Value(UserContextKey).(*Claims); ok {
		return claims
	}
	return nil
}

// RequireSuperAdmin is a middleware that requires the user to have the superadmin role.
// It must be used after RequireAuth.
func RequireSuperAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims := GetUser(r.Context())
		if claims == nil {
			RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			return
		}

		if !slices.Contains(claims.Roles, "superadmin") {
			RespondError(w, http.StatusForbidden, "FORBIDDEN", "Super admin required")
			return
		}

		next.ServeHTTP(w, r)
	})
}

// RequireAdmin is a middleware that requires the user to have admin or superadmin role.
// It must be used after RequireAuth.
func RequireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims := GetUser(r.Context())
		if claims == nil {
			RespondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			return
		}

		if !slices.Contains(claims.Roles, "admin") && !slices.Contains(claims.Roles, "superadmin") {
			RespondError(w, http.StatusForbidden, "FORBIDDEN", "Admin access required")
			return
		}

		next.ServeHTTP(w, r)
	})
}
