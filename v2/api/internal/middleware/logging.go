package middleware

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
)

// contextKey is a type for context keys to avoid collisions.
type contextKey string

// RequestIDKey is the context key for the request ID.
const RequestIDKey contextKey = "request_id"

// responseWriter wraps http.ResponseWriter to capture the status code.
type responseWriter struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func newResponseWriter(w http.ResponseWriter) *responseWriter {
	return &responseWriter{ResponseWriter: w, status: http.StatusOK}
}

func (rw *responseWriter) WriteHeader(code int) {
	if rw.wroteHeader {
		return
	}
	rw.status = code
	rw.wroteHeader = true
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	if !rw.wroteHeader {
		rw.WriteHeader(http.StatusOK)
	}
	return rw.ResponseWriter.Write(b)
}

// Logging is a middleware that logs request details using slog.
// It adds a request_id to the context and logs method, path, status, and duration.
func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		requestID := uuid.New().String()

		// Add request ID to context
		ctx := context.WithValue(r.Context(), RequestIDKey, requestID)
		r = r.WithContext(ctx)

		// Wrap response writer to capture status
		rw := newResponseWriter(w)

		// Call next handler
		next.ServeHTTP(rw, r)

		// Log request details
		slog.Info("request",
			"request_id", requestID,
			"method", r.Method,
			"path", r.URL.Path,
			"status", rw.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}

// GetRequestID retrieves the request ID from the context.
func GetRequestID(ctx context.Context) string {
	if id, ok := ctx.Value(RequestIDKey).(string); ok {
		return id
	}
	return ""
}
