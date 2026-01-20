package middleware

import (
	"net/http"
	"os"
	"strings"
)

// CORS is a middleware that handles Cross-Origin Resource Sharing.
// It reads allowed origins from the CORS_ORIGINS environment variable.
// Origins should be comma-separated, e.g., "http://localhost:5173,https://gallformers.org"
func CORS(next http.Handler) http.Handler {
	// Parse allowed origins from environment variable at startup
	originsEnv := os.Getenv("CORS_ORIGINS")
	allowedOrigins := make(map[string]bool)
	if originsEnv != "" {
		for _, origin := range strings.Split(originsEnv, ",") {
			origin = strings.TrimSpace(origin)
			if origin != "" {
				allowedOrigins[origin] = true
			}
		}
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		// Check if the origin is allowed
		if origin != "" && allowedOrigins[origin] {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type, X-Requested-With")
			w.Header().Set("Access-Control-Max-Age", "86400") // 24 hours
		}

		// Handle preflight requests
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// CORSWithOrigins creates a CORS middleware with the specified allowed origins.
// This is useful for testing or when you want to configure origins programmatically.
func CORSWithOrigins(origins []string) func(http.Handler) http.Handler {
	allowedOrigins := make(map[string]bool)
	for _, origin := range origins {
		allowedOrigins[origin] = true
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")

			// Check if the origin is allowed
			if origin != "" && allowedOrigins[origin] {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Access-Control-Allow-Credentials", "true")
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
				w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type, X-Requested-With")
				w.Header().Set("Access-Control-Max-Age", "86400")
			}

			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
